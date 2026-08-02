#!/bin/bash
# Proves platform-engineer can actually invoke kubernetes-manifest and render a
# real, conforming workload — not just answer a question about the skill's
# content (that's the .contract.sh tier).
#
# The three facts probed are the ones a model working from general Kubernetes
# knowledge gets WRONG, and are exactly what the skill exists to prevent:
#
#   1. Probe semantics. /healthz (dependency-free) -> livenessProbe, /readyz
#      (deps + draining) -> readinessProbe, and /readyz NEVER on liveness.
#      Generic k8s examples routinely point both probes at the same endpoint;
#      kubernetes-manifest calls that out as an anti-pattern because wiring
#      /readyz to liveness turns one database blip into a fleet restart storm.
#   2. The non-negotiable securityContext block, rendered unconditionally --
#      runAsNonRoot + seccompProfile RuntimeDefault at pod level, and
#      allowPrivilegeEscalation:false + readOnlyRootFilesystem:true +
#      capabilities.drop:[ALL] at container level. Default k8s manifests carry
#      none of these.
#   3. A default-deny NetworkPolicy (empty podSelector, BOTH policyTypes)
#      alongside the explicit per-service allow. The skill's anti-pattern list
#      is explicit: allows without the deny are fiction.
#
# Live `claude` CLI dispatch -- slow. Run with SMOKE_TEST_TIMEOUT=300.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"
source "$SCRIPT_DIR/../lib/assertions.sh"
smoke_test_scratch_init

MANIFEST_DIR_REL="deploy/base/compliance-engine"
DEPLOYMENT="$SCRATCH_DIR/$MANIFEST_DIR_REL/deployment.yaml"
NETPOL_REL="$MANIFEST_DIR_REL/networkpolicy.yaml"

validate_kubernetes_manifest() {
  local scratch="$1"
  local dir="$scratch/$MANIFEST_DIR_REL"

  [[ -f "$dir/deployment.yaml" ]]    || { echo "missing $MANIFEST_DIR_REL/deployment.yaml"; return 1; }
  [[ -f "$dir/networkpolicy.yaml" ]] || { echo "missing $NETPOL_REL"; return 1; }

  python3 - "$dir/deployment.yaml" "$dir/networkpolicy.yaml" <<'PY'
import sys, yaml

dep_path, np_path = sys.argv[1], sys.argv[2]

def docs(path):
    with open(path) as f:
        return [d for d in yaml.safe_load_all(f) if d]

fail = []

# ---- 1 + 2: the Deployment ------------------------------------------------
deps = [d for d in docs(dep_path) if d.get("kind") == "Deployment"]
if not deps:
    print("deployment.yaml contains no Deployment document")
    sys.exit(1)
spec = deps[0]["spec"]["template"]["spec"]
containers = spec.get("containers") or []
if not containers:
    print("Deployment pod spec has no containers")
    sys.exit(1)

def probe_path(c, kind):
    p = (c.get(kind) or {}).get("httpGet") or {}
    return p.get("path")

app = containers[0]
live, ready = probe_path(app, "livenessProbe"), probe_path(app, "readinessProbe")

if live is None:
    fail.append("no livenessProbe httpGet path on the app container")
elif "readyz" in live:
    fail.append(
        "livenessProbe points at %r -- wiring /readyz to liveness is the "
        "restart-storm anti-pattern kubernetes-manifest forbids" % live)
elif "healthz" not in live:
    fail.append("livenessProbe path %r is not the dependency-free /healthz" % live)

if ready is None:
    fail.append("no readinessProbe httpGet path on the app container")
elif "readyz" not in ready:
    fail.append("readinessProbe path %r is not /readyz" % ready)

pod_sc = spec.get("securityContext") or {}
if pod_sc.get("runAsNonRoot") is not True:
    fail.append("pod securityContext.runAsNonRoot is not true")
if ((pod_sc.get("seccompProfile") or {}).get("type")) != "RuntimeDefault":
    fail.append("pod securityContext.seccompProfile.type is not RuntimeDefault")

c_sc = app.get("securityContext") or {}
if c_sc.get("allowPrivilegeEscalation") is not False:
    fail.append("container securityContext.allowPrivilegeEscalation is not false")
if c_sc.get("readOnlyRootFilesystem") is not True:
    fail.append("container securityContext.readOnlyRootFilesystem is not true")
drops = ((c_sc.get("capabilities") or {}).get("drop")) or []
if not any(str(d).upper() == "ALL" for d in drops):
    fail.append("container securityContext.capabilities.drop does not include ALL")

# ---- 3: default-deny NetworkPolicy ----------------------------------------
nps = [d for d in docs(np_path) if d.get("kind") == "NetworkPolicy"]
if not nps:
    fail.append("networkpolicy.yaml contains no NetworkPolicy document")
else:
    def is_default_deny(np):
        s = np.get("spec") or {}
        sel = s.get("podSelector")
        types = set(s.get("policyTypes") or [])
        empty_sel = sel == {} or sel is None
        no_rules = not s.get("ingress") and not s.get("egress")
        return empty_sel and no_rules and {"Ingress", "Egress"} <= types
    if not any(is_default_deny(np) for np in nps):
        fail.append(
            "no default-deny NetworkPolicy (empty podSelector, no ingress/egress "
            "rules, policyTypes [Ingress, Egress]) -- explicit allows without the "
            "deny are fiction")
    if len(nps) < 2:
        fail.append("only %d NetworkPolicy found -- the default-deny plus an "
                    "explicit per-service allow were both required" % len(nps))

if fail:
    for f in fail:
        print(f)
    sys.exit(1)
sys.exit(0)
PY
}

smoke_test_acceptance \
  "agents/platform-engineer (acceptance)" \
  "Use the Agent tool to dispatch the 'platform-engineer' subagent with exactly this task: using the kubernetes-manifest skill from this plugin, render the raw Kubernetes manifests for a stateless Go service called 'compliance-engine' that serves HTTP on container port 8080, talks to PostgreSQL on 5432 and Redpanda on 9092, and is reached only from the ingress-gateway. The service already exposes the three standard health endpoints /healthz, /readyz and /startupz — wire each to its correct probe per the skill. Write exactly two files under $SCRATCH_DIR/$MANIFEST_DIR_REL/ (both are required): (1) deployment.yaml — a single Deployment with the full workload standard applied; (2) networkpolicy.yaml — a multi-document YAML file containing every NetworkPolicy resource the skill's workload standard requires for this service in its namespace. Use valid, parseable Kubernetes YAML with no placeholder comments in place of real fields, and no Helm templating syntax — these are rendered manifests, not templates. Do not run kubectl, kubeval, or any validation yourself after writing the files — validation happens separately. Do not produce anything else, do not ask for approval, just write the two files and stop." \
  "$DEPLOYMENT" \
  validate_kubernetes_manifest

smoke_test_summary
