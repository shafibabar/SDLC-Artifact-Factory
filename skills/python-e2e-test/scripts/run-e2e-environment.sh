#!/bin/bash
# run-e2e-environment.sh [--config <file>]
#
# The one end-to-end script. It creates a throwaway kind cluster for this run,
# loads the images, installs every release the configuration lists, waits for
# real readiness, runs the suites, collects evidence when anything failed, and
# always deletes the cluster. It never uses the caller's kubeconfig or current
# context: every kind, helm and kubectl call names a kubeconfig file created
# for this run. It creates and deletes nothing outside the local container
# runtime.
#
# Configuration: a shell file (default tests/e2e/e2e.conf) that sets
#   E2E_NODE_IMAGE       kind node image, pinned by digest
#   E2E_NAMESPACE        namespace every release is installed into
#   E2E_BUILD            command that builds this commit's images (may be empty)
#   E2E_IMAGES           images built from this commit, loaded into the cluster
#                        (space separated); third-party images are pulled by
#                        the node from their pinned reference instead
#   E2E_RELEASES         one "<release>|<chart dir>|<values file>" per line,
#                        dependencies first
#   E2E_ENDPOINTS        one "<name>|<nodePort>" per line; each NodePort is
#                        published on a free port of 127.0.0.1
#   E2E_SUITES           one command per line, run in order once all is ready
#   E2E_SMOKE_ENDPOINT   endpoint name the read-only smoke run addresses (optional)
#   E2E_INSTALL_TIMEOUT  per Helm operation and per rollout (default 180s)
#   E2E_HELM_MAJOR       Helm major version this script was proven on (default 4)
# Environment: E2E_RUN_ID (default gh-<run id>-<attempt> on GitHub Actions,
# else local-<time>-<pid>), E2E_EVIDENCE_DIR (default e2e-evidence).
# Each suite gets E2E_RUN_ID, E2E_KUBECONFIG, E2E_RESULTS_DIR, E2E_ADDR_<NAME>
# for every endpoint and, when E2E_SMOKE_ENDPOINT is set, E2E_SMOKE_URL.
#
# Exit 0 = every suite passed and the cluster is gone; 1 = a step or a suite
# failed, or the cluster could not be deleted; 2 = usage, configuration, a
# missing tool or a cluster of this name that this run did not create;
# 130 = interrupted (the cluster is still deleted).
#
# This is python-e2e-test's copy of the script go-e2e-test owns. Everything from
# `set -uo pipefail` down is the same program in both skills, and a test fails
# when the two differ: change them together.
set -uo pipefail

CONFIG="tests/e2e/e2e.conf"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config) [ "$#" -ge 2 ] || { echo "usage: run-e2e-environment.sh [--config <file>]" >&2; exit 2; }
              CONFIG="$2"; shift 2 ;;
    *) echo "usage: run-e2e-environment.sh [--config <file>]" >&2; exit 2 ;;
  esac
done
[ -f "$CONFIG" ] || { echo "ERROR: no configuration file: $CONFIG" >&2; exit 2; }

E2E_NODE_IMAGE="" E2E_NAMESPACE="" E2E_BUILD="" E2E_IMAGES="" E2E_RELEASES=""
E2E_ENDPOINTS="" E2E_SUITES="" E2E_SMOKE_ENDPOINT=""
E2E_INSTALL_TIMEOUT="180s" E2E_HELM_MAJOR="4"
# shellcheck disable=SC1090
. "$CONFIG"
for required in E2E_NODE_IMAGE E2E_NAMESPACE E2E_RELEASES E2E_ENDPOINTS E2E_SUITES; do
  eval "value=\${$required}"
  [ -n "$value" ] || { echo "ERROR: $CONFIG does not set $required" >&2; exit 2; }
done
case "$E2E_NODE_IMAGE" in
  *@sha256:*) ;;
  *) echo "ERROR: E2E_NODE_IMAGE must be pinned by digest (name:tag@sha256:...)" >&2; exit 2 ;;
esac
for tool in docker kind helm kubectl python3; do
  command -v "$tool" > /dev/null 2>&1 || { echo "ERROR: $tool is not installed" >&2; exit 2; }
done
HELM_VERSION="$(helm version --template '{{.Version}}' 2> /dev/null)"
case "$HELM_VERSION" in
  "v$E2E_HELM_MAJOR".*) ;;
  *) echo "ERROR: Helm $HELM_VERSION found; this script needs Helm $E2E_HELM_MAJOR (flags and waiting differ between major versions)" >&2; exit 2 ;;
esac

if [ -n "${E2E_RUN_ID:-}" ]; then
  RUN_ID="$E2E_RUN_ID"
elif [ -n "${GITHUB_RUN_ID:-}" ]; then
  RUN_ID="gh-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT:-1}"
else
  RUN_ID="local-$(date +%s)-$$"
fi
case "$RUN_ID" in
  *[!a-z0-9-]* | -* | "") echo "ERROR: run id '$RUN_ID' may hold only a-z, 0-9 and '-'" >&2; exit 2 ;;
esac
[ "${#RUN_ID}" -le 40 ] || { echo "ERROR: run id '$RUN_ID' is longer than 40 characters" >&2; exit 2; }
CLUSTER="e2e-$RUN_ID"
CONTEXT="kind-$CLUSTER"

EVIDENCE="${E2E_EVIDENCE_DIR:-e2e-evidence}"
mkdir -p "$EVIDENCE/results" || { echo "ERROR: cannot create $EVIDENCE" >&2; exit 2; }
EVIDENCE="$(cd "$EVIDENCE" && pwd -P)"
WORK="$(mktemp -d)"
KCFG="$WORK/kubeconfig"
# kubectl and Helm otherwise write a discovery cache under ~/.kube/cache.
export KUBECACHEDIR="$WORK/kube-cache"

CREATED=0 TORN=0 TEARDOWN_FAILED=0 STATUS=0 CHILD=""

k() { kubectl --kubeconfig "$KCFG" --context "$CONTEXT" "$@"; }
# For evidence only: a dead API server must not hang the collection.
ke() { k --request-timeout=30s "$@"; }
h() { helm --kubeconfig "$KCFG" --kube-context "$CONTEXT" "$@"; }
say() { echo "== $*"; }

cluster_exists() {
  local names
  names="$(kind get clusters 2> /dev/null)"
  case "
$names
" in
    *"
$CLUSTER
"*) return 0 ;;
  esac
  return 1
}

# Runs a command in its own process group and waits for it. Two reasons: the
# shell handles a signal only between commands or while it sits in `wait`, and
# an interrupt must stop the command together with everything it started.
grouped() {
  python3 -I -c 'import os, sys; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])' "$@" &
  CHILD=$!
  wait "$CHILD"
  local rc=$?
  CHILD=""
  return "$rc"
}
run_k() { grouped kubectl --kubeconfig "$KCFG" --context "$CONTEXT" "$@"; }
run_h() { grouped helm --kubeconfig "$KCFG" --kube-context "$CONTEXT" "$@"; }

teardown() {
  [ "$TORN" -eq 1 ] && return 0
  TORN=1
  if [ "$CREATED" -eq 1 ]; then
    say "deleting cluster $CLUSTER"
    kind delete cluster --name "$CLUSTER" --kubeconfig "$KCFG" || TEARDOWN_FAILED=1
    if cluster_exists; then
      TEARDOWN_FAILED=1
      echo "ERROR: cluster $CLUSTER still exists. Delete it: kind delete cluster --name $CLUSTER" >&2
    fi
  fi
  rm -rf "$WORK"
}

on_signal() {
  trap '' INT TERM HUP
  echo "interrupted: stopping and deleting cluster $CLUSTER" >&2
  [ -z "$CHILD" ] || kill -TERM -- "-$CHILD" 2> /dev/null
  teardown
  trap - EXIT
  exit 130
}
trap on_signal INT TERM HUP
# Backstop only: the normal path below calls teardown itself, after the suites.
trap teardown EXIT

free_port() {
  python3 -I -c 'import socket
s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

# wait_tcp <port> <seconds>: polls until the loopback port accepts a connection.
wait_tcp() {
  python3 -I - "$1" "$2" << 'PY'
import socket, sys, time
port, limit = int(sys.argv[1]), float(sys.argv[2])
deadline = time.monotonic() + limit
last = None
while time.monotonic() < deadline:
    try:
        socket.create_connection(("127.0.0.1", port), timeout=2).close()
        sys.exit(0)
    except OSError as exc:
        last = exc
        time.sleep(0.5)  # poll interval inside a deadline, not a wait
print(f"127.0.0.1:{port} did not accept a connection within {limit:.0f}s: {last}")
sys.exit(1)
PY
}

collect_evidence() {
  say "collecting evidence into $EVIDENCE"
  mkdir -p "$EVIDENCE/logs"
  ke get all,configmaps,ingresses,networkpolicies,persistentvolumeclaims -A -o wide > "$EVIDENCE/cluster-state.txt" 2>&1
  ke get events -A --sort-by=.lastTimestamp > "$EVIDENCE/events.txt" 2>&1
  ke describe pods -n "$E2E_NAMESPACE" > "$EVIDENCE/describe-pods.txt" 2>&1
  h list -A > "$EVIDENCE/helm-releases.txt" 2>&1
  local pod name
  for pod in $(ke get pods -n "$E2E_NAMESPACE" -o name 2> /dev/null); do
    name="${pod#pod/}"
    # --tail=-1: with a selector kubectl prints only the last 10 lines by default.
    ke logs -n "$E2E_NAMESPACE" "$pod" --all-containers --prefix --timestamps --tail=-1 > "$EVIDENCE/logs/$name.log" 2>&1
    ke logs -n "$E2E_NAMESPACE" "$pod" --all-containers --prefix --timestamps --tail=-1 --previous > "$EVIDENCE/logs/$name.previous.log" 2> /dev/null \
      || rm -f "$EVIDENCE/logs/$name.previous.log"
  done
  kind export logs "$EVIDENCE/kind-nodes" --name "$CLUSTER" > /dev/null 2>&1
}

provision() {
  local names other rel chart values kind workload found name port addr upper mappings marker
  names="$(kind get clusters 2> /dev/null)"
  if cluster_exists; then
    echo "ERROR: a cluster named $CLUSTER already exists and this run did not create it; it is left alone" >&2
    return 2
  fi
  for other in $names; do
    case "$other" in
      e2e-*) echo "WARN: cluster $other is left over from another run (or is running now). If it is not in use: kind delete cluster --name $other" >&2 ;;
    esac
  done

  if [ -n "$E2E_BUILD" ]; then
    say "building images: $E2E_BUILD"
    grouped /bin/bash -c "$E2E_BUILD" || { echo "ERROR: image build failed" >&2; return 1; }
  fi

  mappings="" marker="--from-literal=run-id=$RUN_ID"
  while IFS='|' read -r name port; do
    [ -n "$name" ] || continue
    addr="127.0.0.1:$(free_port)"
    mappings="$mappings
      - containerPort: $port
        hostPort: ${addr#127.0.0.1:}
        listenAddress: \"127.0.0.1\"
        protocol: TCP"
    marker="$marker --from-literal=endpoint.$name=$addr"
    upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
    export "E2E_ADDR_$upper=$addr"
    [ "$name" = "$E2E_SMOKE_ENDPOINT" ] && export E2E_SMOKE_URL="http://$addr"
    echo "$name $addr" >> "$WORK/endpoints"
  done << EOF
$E2E_ENDPOINTS
EOF
  cat > "$WORK/kind-config.yaml" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "127.0.0.1"
nodes:
  - role: control-plane
    image: $E2E_NODE_IMAGE
    extraPortMappings:$mappings
EOF

  say "creating cluster $CLUSTER (kubeconfig $KCFG)"
  CREATED=1
  grouped kind create cluster --name "$CLUSTER" --kubeconfig "$KCFG" --config "$WORK/kind-config.yaml" --wait 180s \
    || { echo "ERROR: cluster creation failed" >&2; return 1; }

  if [ -n "$E2E_IMAGES" ]; then
    say "loading images: $E2E_IMAGES"
    # shellcheck disable=SC2086
    grouped kind load docker-image $E2E_IMAGES --name "$CLUSTER" || { echo "ERROR: image load failed" >&2; return 1; }
  fi

  while IFS='|' read -r rel chart values; do
    [ -n "$rel" ] || continue
    say "installing $rel from $chart"
    # --wait is written out: without it Helm $E2E_HELM_MAJOR waits only for hooks and reports
    # success while no Pod is ready. No --rollback-on-failure: it removes the
    # failed release, and its logs with it, before evidence is collected.
    run_h upgrade --install "$rel" "$chart" -n "$E2E_NAMESPACE" --create-namespace -f "$values" \
      --wait=watcher --wait-for-jobs --timeout "$E2E_INSTALL_TIMEOUT" \
      || { echo "ERROR: release $rel did not become ready" >&2; return 1; }
    found=0
    for kind in deployment statefulset daemonset; do
      for workload in $(k get "$kind" -n "$E2E_NAMESPACE" -l "app.kubernetes.io/instance=$rel" -o name); do
        found=1
        run_k rollout status "$workload" -n "$E2E_NAMESPACE" --timeout "$E2E_INSTALL_TIMEOUT" \
          || { echo "ERROR: $workload of release $rel did not finish rolling out" >&2; return 1; }
      done
    done
    [ "$found" -eq 1 ] || echo "NOTE: release $rel has no workload labelled app.kubernetes.io/instance=$rel; only Helm's own wait applied"
  done << EOF
$E2E_RELEASES
EOF

  while read -r name addr; do
    say "waiting for endpoint $name on $addr"
    wait_tcp "${addr#127.0.0.1:}" 60 || { echo "ERROR: endpoint $name is not reachable" >&2; return 1; }
  done < "$WORK/endpoints"

  # The marker the test process checks before it does anything: this cluster
  # belongs to this run, and these are its only addresses.
  # shellcheck disable=SC2086
  k create configmap e2e-run-marker -n default $marker > /dev/null \
    || { echo "ERROR: could not write the run marker" >&2; return 1; }
  return 0
}

{
  echo "run id: $RUN_ID"
  echo "commit: $(git rev-parse --verify -q HEAD 2> /dev/null || echo unknown)"
  echo "kind: $(kind version 2> /dev/null)"
  echo "helm: $HELM_VERSION"
  echo "kubectl: $(kubectl version --client 2> /dev/null | head -n 1)"
  echo "docker: $(docker version --format '{{.Server.Version}}' 2> /dev/null)"
  echo "node image: $E2E_NODE_IMAGE"
} > "$EVIDENCE/run.txt"

provision
case $? in
  0) ;;
  2) teardown; exit 2 ;;
  *) STATUS=1 ;;
esac

if [ "$STATUS" -eq 0 ]; then
  export E2E_RUN_ID="$RUN_ID" E2E_KUBECONFIG="$KCFG" E2E_RESULTS_DIR="$EVIDENCE/results"
  while IFS= read -r suite; do
    [ -n "$suite" ] || continue
    say "suite: $suite"
    if grouped /bin/bash -c "$suite"; then
      echo "suite passed: $suite" >> "$EVIDENCE/run.txt"
    else
      STATUS=1
      echo "suite FAILED: $suite" | tee -a "$EVIDENCE/run.txt" >&2
    fi
  done << EOF
$E2E_SUITES
EOF
fi

[ "$STATUS" -eq 0 ] || collect_evidence
teardown
if [ "$TEARDOWN_FAILED" -eq 1 ]; then STATUS=1; fi
if [ "$STATUS" -eq 0 ]; then say "end-to-end run $RUN_ID passed; cluster deleted"; else say "end-to-end run $RUN_ID FAILED; evidence in $EVIDENCE"; fi
exit "$STATUS"
