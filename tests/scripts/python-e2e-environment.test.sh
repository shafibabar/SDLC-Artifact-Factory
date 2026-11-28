#!/bin/bash
# Test for python-e2e-test's own copy of the end-to-end environment script, with
# fake kind, helm, kubectl and docker on the PATH: no Docker, cluster, Helm or
# pytest is needed. It checks what a Python suite relies on (what each suite
# line receives, teardown after a failing suite and on a signal) and that the
# program is the same as the one go-e2e-test owns. The full behaviour of the
# script is tested in run-e2e-environment.test.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
SCRIPT="$REPO_ROOT/skills/python-e2e-test/scripts/run-e2e-environment.sh"
OWNER="$REPO_ROOT/skills/go-e2e-test/scripts/run-e2e-environment.sh"
TMP="$(cd "$(mktemp -d)" && pwd -P)"
cleanup() {
  local pidfile
  for pidfile in "$TMP"/*/listener.pid; do
    [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null
  done
  rm -rf "$TMP"
}
trap cleanup EXIT
FAILURES=0

mkdir -p "$TMP/bin"
# The fake `kind create cluster` opens the loopback ports the script asked for,
# so the script's own endpoint wait can succeed.
cat > "$TMP/bin/kind" <<'FAKE'
#!/bin/bash
echo "kind $*" >> "$FAKE/calls"
name="" config=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    --name) name="${args[$((i + 1))]}" ;;
    --config) config="${args[$((i + 1))]}" ;;
  esac
done
case "$1 ${2:-}" in
  "get clusters") cat "$FAKE/clusters" 2>/dev/null ;;
  "create cluster")
    echo "$name" >> "$FAKE/clusters"
    python3 -I - "$config" "$FAKE/listener.pid" > /dev/null 2>&1 <<'PY' &
import os, re, socket, sys, time
ports = [int(p) for p in re.findall(r"hostPort: (\d+)", open(sys.argv[1]).read())]
socks = []
for port in ports:
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", port)); s.listen(16); socks.append(s)
open(sys.argv[2], "w").write(str(os.getpid()))
time.sleep(120)
PY
    ;;
  "delete cluster")
    grep -v -x -e "$name" "$FAKE/clusters" > "$FAKE/clusters.new" 2>/dev/null
    mv "$FAKE/clusters.new" "$FAKE/clusters"
    [ -f "$FAKE/listener.pid" ] && kill "$(cat "$FAKE/listener.pid")" 2>/dev/null
    ;;
  "version ") echo "kind v0.33.0 fake" ;;
esac
exit 0
FAKE
cat > "$TMP/bin/helm" <<'FAKE'
#!/bin/bash
if [ "$1" = "version" ]; then echo "v4.3.2"; exit 0; fi
echo "helm $*" >> "$FAKE/calls"
exit 0
FAKE
cat > "$TMP/bin/kubectl" <<'FAKE'
#!/bin/bash
echo "kubectl $*" >> "$FAKE/calls"
case " $* " in
  *" get deployment "*" -o name "*) echo "deployment.apps/app" ;;
  *" get pods "*" -o name "*) echo "pod/app-1" ;;
  *" version "*) echo "Client Version: v1.37.0 fake" ;;
esac
exit 0
FAKE
printf '#!/bin/bash\necho "29.0.0"\n' > "$TMP/bin/docker"
chmod +x "$TMP/bin/kind" "$TMP/bin/helm" "$TMP/bin/kubectl" "$TMP/bin/docker"

# scenario <name> <suites>: a fresh product folder with a configuration. $FAKE in
# <suites> is written in single quotes: it is expanded when the script reads
# the configuration.
scenario() {
  export FAKE="$TMP/$1"
  mkdir -p "$FAKE/product/tests/e2e" "$FAKE/home"
  : > "$FAKE/clusters"
  cat > "$FAKE/product/tests/e2e/e2e.conf" <<CONF
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:0000000000000000000000000000000000000000000000000000000000000000"
E2E_NAMESPACE="museum"
E2E_BUILD=""
E2E_IMAGES="loans:e2e"
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
loans|charts/loans|tests/e2e/values/loans.yaml
"
E2E_ENDPOINTS="
api|30080
db|30432
"
E2E_SMOKE_ENDPOINT="api"
E2E_SUITES="
$2
"
CONF
}
run_script() {
  local want="$1" label="$2" rc
  OUT="$(cd "$FAKE/product" && HOME="$FAKE/home" PATH="$TMP/bin:$PATH" E2E_RUN_ID="py1" \
    E2E_EVIDENCE_DIR="$FAKE/evidence" bash "$SCRIPT" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]]; then echo "PASS: $label (exit $rc)"; else
    echo "FAIL: $label (exit $rc, wanted $want)"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
}
expect() {
  if grep -qE -- "$2" "$3" 2>/dev/null; then echo "PASS: $1"; else
    echo "FAIL: $1 (no '$2' in $3)"; cat "$3" 2>/dev/null; FAILURES=$((FAILURES + 1)); fi
}
refuse() {
  if grep -qE -- "$2" "$3" 2>/dev/null; then
    echo "FAIL: $1 ('$2' found in $3)"; grep -E -- "$2" "$3"; FAILURES=$((FAILURES + 1)); else echo "PASS: $1"; fi
}

# ------------------------------------------- what a Python suite line receives
scenario ok 'env | grep -e "^E2E_" > $FAKE/journeys-env
echo smoke-line >> $FAKE/suites-run'
run_script 0 "the whole flow with two suite lines"
expect "the suite gets the run id the guard checks" "^E2E_RUN_ID=py1$" "$FAKE/journeys-env"
expect "the suite gets the run's own kubeconfig, an absolute path" "^E2E_KUBECONFIG=/.*/kubeconfig$" "$FAKE/journeys-env"
refuse "that kubeconfig is not under the home folder" "^E2E_KUBECONFIG=$FAKE/home" "$FAKE/journeys-env"
expect "the suite gets the results folder" "^E2E_RESULTS_DIR=$FAKE/evidence/results$" "$FAKE/journeys-env"
expect "the suite gets the smoke address" "^E2E_SMOKE_URL=http://127.0.0.1:[0-9]+$" "$FAKE/journeys-env"
expect "the suite gets each endpoint address" "^E2E_ADDR_DB=127.0.0.1:[0-9]+$" "$FAKE/journeys-env"
expect "the marker the Python guard reads carries the run id and loopback endpoints" \
  "create configmap e2e-run-marker -n default --from-literal=run-id=py1 --from-literal=endpoint.api=127.0.0.1:[0-9]+ --from-literal=endpoint.db=127.0.0.1:[0-9]+" "$FAKE/calls"
expect "every suite line ran" "smoke-line" "$FAKE/suites-run"
refuse "every kubectl call names the run's kubeconfig and context" "." <(grep '^kubectl' "$FAKE/calls" | grep -v -e '--kubeconfig [^ ]*/kubeconfig --context kind-e2e-py1 ' -e '^kubectl version')
refuse "every helm call names the run's kubeconfig and context" "." <(grep '^helm' "$FAKE/calls" | grep -v -e '--kubeconfig [^ ]*/kubeconfig --kube-context kind-e2e-py1 ')
expect "kind create names cluster and kubeconfig" "^kind create cluster --name e2e-py1 --kubeconfig [^ ]*/kubeconfig --config " "$FAKE/calls"
refuse "nothing switches a context" "use-context|set-context" "$FAKE/calls"
refuse "the cluster is gone" "e2e-py1" "$FAKE/clusters"
if [[ ! -e "$FAKE/home/.kube" ]]; then echo "PASS: nothing written under the home folder"; else echo "FAIL: ~/.kube was created"; FAILURES=$((FAILURES + 1)); fi

# --------------------------------------------- a failing Python suite line
scenario suite-fails 'exit 1
echo after-failure >> $FAKE/suites-run'
run_script 1 "a failing suite line"
expect "later suite lines still run" "after-failure" "$FAKE/suites-run"
expect "the run record names the failed line" "suite FAILED: exit 1" "$FAKE/evidence/run.txt"
expect "full logs of each pod are collected" "logs -n museum pod/app-1 --all-containers --prefix --timestamps --tail=-1$" "$FAKE/calls"
python3 -I - "$FAKE/calls" <<'PY' && echo "PASS: evidence is collected before the cluster is deleted" || { echo "FAIL: evidence order"; FAILURES=$((FAILURES + 1)); }
import sys
calls = open(sys.argv[1]).read().splitlines()
logs = max(i for i, c in enumerate(calls) if " logs " in c)
delete = next(i for i, c in enumerate(calls) if c.startswith("kind delete cluster"))
sys.exit(0 if logs < delete else 1)
PY
refuse "the cluster is gone after a failed suite" "e2e-py1" "$FAKE/clusters"

# ------------------------------------------------- a signal during a suite
# The script is started by Python: a script started with `&` from a
# non-interactive shell has SIGINT ignored, and an ignored signal cannot be trapped.
scenario sigterm 'bash $FAKE/slow.sh'
cat > "$FAKE/slow.sh" <<'SLOW'
echo $$ > "$FAKE/suite.pid"
python3 -I -c 'import time; time.sleep(60)'
echo never >> "$FAKE/suites-run"
SLOW
python3 -I - "$SCRIPT" "$FAKE" "$TMP/bin" <<'PY'
import os, signal, subprocess, sys, time
script, fake, fakebin = sys.argv[1:4]
env = dict(os.environ, PATH=fakebin + os.pathsep + os.environ["PATH"], HOME=fake + "/home",
           E2E_RUN_ID="py1", E2E_EVIDENCE_DIR=fake + "/evidence", FAKE=fake)
with open(fake + "/output", "w") as out:
    proc = subprocess.Popen(["bash", script], cwd=fake + "/product", env=env, stdout=out, stderr=subprocess.STDOUT,
                            preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline and not os.path.exists(fake + "/suite.pid"):
        time.sleep(0.1)
    time.sleep(0.5)
    proc.send_signal(signal.SIGTERM)
    try:
        code = proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        proc.kill()
        code = -1
open(fake + "/exit", "w").write(f"{code}\n")
time.sleep(0.5)
try:
    os.kill(int(open(fake + "/suite.pid").read()), 0)
    open(fake + "/suite-alive", "w").write("still running\n")
except (OSError, ValueError):
    pass
PY
expect "SIGTERM: exit 130" "^130$" "$FAKE/exit"
expect "SIGTERM: the cluster is deleted" "^kind delete cluster --name e2e-py1 " "$FAKE/calls"
refuse "SIGTERM: the cluster is gone" "e2e-py1" "$FAKE/clusters"
if [[ ! -f "$FAKE/suite-alive" ]]; then echo "PASS: SIGTERM: the suite process was stopped"; else echo "FAIL: SIGTERM: the suite is still running"; FAILURES=$((FAILURES + 1)); fi
if [[ ! -f "$FAKE/suites-run" ]]; then echo "PASS: SIGTERM: the suite did not carry on"; else echo "FAIL: SIGTERM: the suite carried on"; FAILURES=$((FAILURES + 1)); fi

# The environment script is language-neutral and owned by go-e2e-test: each
# skill keeps its copy, and the program (everything from `set -uo pipefail`
# down) must stay the same. Change both together.
if python3 -I - "$SCRIPT" "$OWNER" <<'PY'
import sys
def program(path):
    text = open(path, encoding="utf-8").read()
    return text[text.index("\nset -uo pipefail\n"):]
sys.exit(0 if program(sys.argv[1]) == program(sys.argv[2]) else 1)
PY
then echo "PASS: the program is identical to go-e2e-test's copy"; else echo "FAIL: run-e2e-environment.sh differs from go-e2e-test's copy; change both together"; FAILURES=$((FAILURES + 1)); fi
if [[ "$(head -n 1 "$SCRIPT")" == '#!/bin/bash' ]] && grep -q "python-e2e-test's copy" "$SCRIPT"; then echo "PASS: the header says whose copy this is"; else echo "FAIL: header"; FAILURES=$((FAILURES + 1)); fi

if [[ $FAILURES -eq 0 ]]; then echo "PASS: python-e2e-environment"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
