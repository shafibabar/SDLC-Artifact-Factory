#!/bin/bash
# Contract test for the python-domain-model skill.
# Probes a references/-only fact: the exact mangled attribute name a determined
# caller assigns to in order to bypass Python __double_underscore name-mangling
# and corrupt an Aggregate's version — the concrete demonstration of the honest
# weak-encapsulation gap vs Go. This lives in references/invariants-and-events.md,
# NOT in the SKILL.md body (verified: `grep _DataAsset__version SKILL.md` is empty),
# so a passing answer proves the progressive-disclosure split is functional.
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "python-domain-model" \
  "In Python, a DataAsset Aggregate stores its version under a double-underscore (__version) name-mangled attribute. What is the exact attribute name a determined external caller would assign to in order to reach around the mangling and corrupt the version invariant?" \
  "_DataAsset__version"

smoke_test_summary
