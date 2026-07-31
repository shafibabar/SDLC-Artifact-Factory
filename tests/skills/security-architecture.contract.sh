#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
# Probes references/zero-trust-and-mesh.md: the control plane decomposes into a
# policy engine (the rule) and a TRUST ENGINE (continuously scores actor
# trustworthiness from dynamic signals, feeding the policy decision). This
# decomposition lives only in references/ — the SKILL.md body states the
# mesh-vs-app placement rule but never names the trust-engine component.
smoke_test_skill "security-architecture" \
  "Inside the zero-trust control plane, what component continuously scores an actor's trustworthiness from dynamic signals like device posture and authentication freshness, feeding its result into the policy decision — and to what ABAC construct does it map in this repo?" \
  "trust engine"
smoke_test_summary
