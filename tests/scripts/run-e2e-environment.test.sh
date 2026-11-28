#!/bin/bash
# Test for go-e2e-test's environment script, with fake kind, helm, kubectl and
# docker on the PATH: no Docker, cluster, Go or Helm is needed. The fakes record
# every call; the fake `kind create cluster` opens the loopback ports the script
# asked for, so the script's own endpoint wait can succeed.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/skills/go-e2e-test/scripts/run-e2e-environment.sh"
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
    [ -f "$FAKE/create-fails" ] && exit 1
    echo "$name" >> "$FAKE/clusters"
    cp "$config" "$FAKE/kind-config.yaml"
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
    [ -f "$FAKE/delete-fails" ] && exit 1
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
if [ "$1" = "version" ]; then cat "$FAKE/helm-version" 2>/dev/null || echo "v4.3.2"; exit 0; fi
echo "helm $*" >> "$FAKE/calls"
case " $* " in
  *" upgrade "*) [ -f "$FAKE/helm-fails" ] && { echo "Error: resource not ready" >&2; exit 1; } ;;
esac
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
cat > "$TMP/bin/docker" <<'FAKE'
#!/bin/bash
echo "29.0.0"
FAKE
chmod +x "$TMP/bin/kind" "$TMP/bin/helm" "$TMP/bin/kubectl" "$TMP/bin/docker"

# scenario <name> <suites>: a fresh product folder with a configuration. Write
# $FAKE in <suites> inside single quotes: it is expanded when the script reads
# the configuration, not here.
scenario() {
  export FAKE="$TMP/$1"
  mkdir -p "$FAKE/product/tests/e2e" "$FAKE/home"
  : > "$FAKE/clusters"
  cat > "$FAKE/product/tests/e2e/e2e.conf" <<CONF
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:0000000000000000000000000000000000000000000000000000000000000000"
E2E_NAMESPACE="shop"
E2E_BUILD="echo built > \$FAKE/built"
E2E_IMAGES="orders:e2e web-shell:e2e"
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
orders|charts/orders|tests/e2e/values/orders.yaml
"
E2E_ENDPOINTS="
api|30080
web-shell|30081
"
E2E_SMOKE_ENDPOINT="api"
E2E_SUITES="
$2
"
CONF
}

# run_script <expected exit> <label> [args...]: runs in the product folder
run_script() {
  local want="$1" label="$2"; shift 2
  local rc
  OUT="$(cd "$FAKE/product" && HOME="$FAKE/home" PATH="$TMP/bin:$PATH" E2E_RUN_ID="${RUN_ID:-t1}" \
    E2E_EVIDENCE_DIR="$FAKE/evidence" bash "$SCRIPT" "$@" 2>&1)"; rc=$?
  if [[ $rc -eq $want ]]; then echo "PASS: $label (exit $rc)"; else
    echo "FAIL: $label (exit $rc, wanted $want)"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
}

# expect <label> <pattern> <file> / refuse <label> <pattern> <file>
expect() {
  if grep -qE -- "$2" "$3" 2>/dev/null; then echo "PASS: $1"; else
    echo "FAIL: $1 (no '$2' in $3)"; cat "$3" 2>/dev/null; FAILURES=$((FAILURES + 1)); fi
}
refuse() {
  if grep -qE -- "$2" "$3" 2>/dev/null; then
    echo "FAIL: $1 ('$2' found in $3)"; grep -E -- "$2" "$3"; FAILURES=$((FAILURES + 1)); else echo "PASS: $1"; fi
}
said() {
  if grep -qE -- "$2" <<<"$OUT"; then echo "PASS: $1"; else echo "FAIL: $1 (output lacks '$2')"; echo "$OUT"; FAILURES=$((FAILURES + 1)); fi
}

# ------------------------------------------------------------ configuration
scenario config "true"
run_script 2 "a missing configuration file" --config "$FAKE/none.conf"
said "names the file" "no configuration file"
run_script 2 "an unknown argument" --keep
echo 'E2E_NODE_IMAGE="kindest/node:v1.37.0"' >> "$FAKE/product/tests/e2e/e2e.conf"
run_script 2 "a node image without a digest"
said "asks for a digest" "pinned by digest"
scenario helm3 "true"
echo "v3.22.1" > "$FAKE/helm-version"
run_script 2 "Helm 3 on the machine"
said "names the Helm version" "Helm v3.22.1 found; this script needs Helm 4"
refuse "nothing was created under Helm 3" "create cluster" "$FAKE/calls"
scenario badid "true"
RUN_ID="Bad_ID" run_script 2 "a run id that is not a valid cluster name"

# ------------------------------------------------------------------ success
scenario ok 'env | grep -e "^E2E_" -e "^KUBECACHEDIR=" > $FAKE/suite-env
echo second-suite >> $FAKE/suites-run'
run_script 0 "the whole flow"
said "reports the pass" "end-to-end run t1 passed; cluster deleted"
expect "images were built first" "built" "$FAKE/built"
python3 -I - "$FAKE/calls" <<'PY' && echo "PASS: order: create, load, install, marker, delete" || { echo "FAIL: call order"; cat "$FAKE/calls"; FAILURES=$((FAILURES + 1)); }
import sys
calls = open(sys.argv[1]).read().splitlines()
def first(text):
    return next(i for i, c in enumerate(calls) if text in c)
order = [first("kind create cluster"), first("kind load docker-image orders:e2e web-shell:e2e"),
         first("upgrade --install postgres"), first("upgrade --install orders"),
         first("create configmap e2e-run-marker"), first("kind delete cluster")]
sys.exit(0 if order == sorted(order) else 1)
PY
refuse "every kubectl call names the run's kubeconfig and context" "." <(grep '^kubectl' "$FAKE/calls" | grep -v -e '--kubeconfig [^ ]*/kubeconfig --context kind-e2e-t1 ' -e '^kubectl version')
refuse "every helm call names the run's kubeconfig and context" "." <(grep '^helm' "$FAKE/calls" | grep -v -e '--kubeconfig [^ ]*/kubeconfig --kube-context kind-e2e-t1 ')
expect "kind create names cluster and kubeconfig" "^kind create cluster --name e2e-t1 --kubeconfig [^ ]*/kubeconfig --config " "$FAKE/calls"
expect "kind delete names cluster and kubeconfig" "^kind delete cluster --name e2e-t1 --kubeconfig [^ ]*/kubeconfig$" "$FAKE/calls"
refuse "the kubeconfig is not under the home folder" "--kubeconfig $FAKE/home" "$FAKE/calls"
refuse "nothing switches a context" "use-context|set-context" "$FAKE/calls"
expect "Helm waits explicitly" "upgrade --install orders charts/orders -n shop --create-namespace -f tests/e2e/values/orders.yaml --wait=watcher --wait-for-jobs --timeout 180s" "$FAKE/calls"
refuse "no rollback that would remove the evidence" "rollback-on-failure|atomic" "$FAKE/calls"
expect "each workload's rollout is awaited" "rollout status deployment.apps/app -n shop --timeout 180s" "$FAKE/calls"
expect "ports are published on loopback only" 'listenAddress: "127.0.0.1"' "$FAKE/kind-config.yaml"
expect "the API server listens on loopback only" 'apiServerAddress: "127.0.0.1"' "$FAKE/kind-config.yaml"
expect "the node image is the pinned one" "image: kindest/node:v1.37.0@sha256:0000" "$FAKE/kind-config.yaml"
expect "the marker carries the run id and loopback endpoints" "create configmap e2e-run-marker -n default --from-literal=run-id=t1 --from-literal=endpoint.api=127.0.0.1:[0-9]+ --from-literal=endpoint.web-shell=127.0.0.1:[0-9]+" "$FAKE/calls"
expect "suites get the run id" "^E2E_RUN_ID=t1$" "$FAKE/suite-env"
expect "suites get the run's kubeconfig" "^E2E_KUBECONFIG=.*/kubeconfig$" "$FAKE/suite-env"
expect "suites get each endpoint address" "^E2E_ADDR_WEB_SHELL=127.0.0.1:[0-9]+$" "$FAKE/suite-env"
expect "suites get the smoke address" "^E2E_SMOKE_URL=http://127.0.0.1:[0-9]+$" "$FAKE/suite-env"
expect "the discovery cache is kept out of the home folder" "^KUBECACHEDIR=.*/kube-cache$" "$FAKE/suite-env"
expect "every suite ran" "second-suite" "$FAKE/suites-run"
expect "the run record lists the suites" "suite passed" "$FAKE/evidence/run.txt"
refuse "the cluster is gone" "e2e-t1" "$FAKE/clusters"
refuse "no evidence is collected on success" "logs " "$FAKE/calls"
if [[ ! -e "$FAKE/home/.kube" ]]; then echo "PASS: nothing written under the home folder"; else echo "FAIL: ~/.kube was created"; FAILURES=$((FAILURES + 1)); fi

# ----------------------------------------------------------- failing suite
scenario suite-fails 'exit 1
echo after-failure >> $FAKE/suites-run'
run_script 1 "a failing suite"
said "reports the failure" "end-to-end run t1 FAILED; evidence in"
expect "later suites still run" "after-failure" "$FAKE/suites-run"
expect "full logs of each pod are collected" "logs -n shop pod/app-1 --all-containers --prefix --timestamps --tail=-1$" "$FAKE/calls"
expect "events are collected" "get events -A" "$FAKE/calls"
expect "node logs are exported" "^kind export logs .* --name e2e-t1$" "$FAKE/calls"
expect "the cluster is deleted after a failed suite" "^kind delete cluster --name e2e-t1 " "$FAKE/calls"
refuse "the cluster is gone after a failed suite" "e2e-t1" "$FAKE/clusters"
python3 -I - "$FAKE/calls" <<'PY' && echo "PASS: evidence is collected before the cluster is deleted" || { echo "FAIL: evidence order"; FAILURES=$((FAILURES + 1)); }
import sys
calls = open(sys.argv[1]).read().splitlines()
logs = max(i for i, c in enumerate(calls) if " logs " in c)
delete = next(i for i, c in enumerate(calls) if c.startswith("kind delete cluster"))
sys.exit(0 if logs < delete else 1)
PY

# ------------------------------------------------- release never gets ready
scenario not-ready 'echo ran >> $FAKE/suites-run'
touch "$FAKE/helm-fails"
run_script 1 "a release that does not become ready"
said "names the release" "release postgres did not become ready"
if [[ ! -f "$FAKE/suites-run" ]]; then echo "PASS: no suite runs on a broken environment"; else echo "FAIL: a suite ran"; FAILURES=$((FAILURES + 1)); fi
expect "evidence is collected" " logs " "$FAKE/calls"
refuse "the cluster is gone after a failed install" "e2e-t1" "$FAKE/clusters"

# ------------------------------------------------ somebody else's cluster
scenario exists "true"
echo "e2e-t1" > "$FAKE/clusters"
run_script 2 "a cluster of this name that this run did not create"
said "leaves it alone" "already exists and this run did not create it"
refuse "it is not deleted" "delete cluster" "$FAKE/calls"
expect "it still exists" "^e2e-t1$" "$FAKE/clusters"
scenario leftover "true"
echo "e2e-older" > "$FAKE/clusters"
run_script 0 "another run's cluster is present"
said "it is reported, with the command" "WARN: cluster e2e-older is left over"
expect "and never deleted by this run" "^e2e-older$" "$FAKE/clusters"

# ------------------------------------------------------- teardown failure
scenario delete-fails "true"
touch "$FAKE/delete-fails"
run_script 1 "a cluster that cannot be deleted"
said "says the cluster is still there" "cluster e2e-t1 still exists"

# ------------------------------------------------------------ interruption
# The script is started by Python: a script started with `&` from a
# non-interactive shell has SIGINT ignored, and an ignored signal cannot be trapped.
interrupt() {
  local signal="$1" name="$2"
  scenario "$name" 'bash $FAKE/slow.sh'
  cat > "$FAKE/slow.sh" <<'SLOW'
echo $$ > "$FAKE/suite.pid"
python3 -I -c 'import time; time.sleep(60)'
echo never >> "$FAKE/suites-run"
SLOW
  python3 -I - "$signal" "$SCRIPT" "$FAKE" "$TMP/bin" <<'PY'
import os, signal, subprocess, sys, time
name, script, fake, fakebin = sys.argv[1:5]
env = dict(os.environ, PATH=fakebin + os.pathsep + os.environ["PATH"], HOME=fake + "/home",
           E2E_RUN_ID="t1", E2E_EVIDENCE_DIR=fake + "/evidence", FAKE=fake)
with open(fake + "/output", "w") as out:
    # SIGINT is set back to its default: if this test itself was started in the
    # background, the signal would be inherited as ignored and could not be trapped.
    proc = subprocess.Popen(["bash", script], cwd=fake + "/product", env=env, stdout=out, stderr=subprocess.STDOUT,
                            preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline and not os.path.exists(fake + "/suite.pid"):
        time.sleep(0.1)
    time.sleep(0.5)
    started = time.monotonic()
    proc.send_signal(getattr(signal, name))
    try:
        code = proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        proc.kill()
        code = -1
open(fake + "/exit", "w").write(f"{code}\n")
open(fake + "/seconds", "w").write(f"{time.monotonic() - started:.1f}\n")
time.sleep(0.5)
try:
    os.kill(int(open(fake + "/suite.pid").read()), 0)
    open(fake + "/suite-alive", "w").write("still running\n")
except (OSError, ValueError):
    pass
PY
  expect "$signal: exit 130" "^130$" "$FAKE/exit"
  expect "$signal: the script says what it does" "interrupted: stopping and deleting cluster e2e-t1" "$FAKE/output"
  expect "$signal: the cluster is deleted" "^kind delete cluster --name e2e-t1 " "$FAKE/calls"
  refuse "$signal: the cluster is gone" "e2e-t1" "$FAKE/clusters"
  if [[ ! -f "$FAKE/suite-alive" ]]; then echo "PASS: $signal: the suite process was stopped"; else echo "FAIL: $signal: the suite is still running"; FAILURES=$((FAILURES + 1)); fi
  if [[ ! -f "$FAKE/suites-run" ]]; then echo "PASS: $signal: the suite did not carry on"; else echo "FAIL: $signal: the suite carried on"; FAILURES=$((FAILURES + 1)); fi
}
interrupt SIGINT sigint
interrupt SIGTERM sigterm

if [[ $FAILURES -eq 0 ]]; then echo "PASS: run-e2e-environment"; else echo "FAIL: $FAILURES case(s)"; exit 1; fi
