#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes references/mutmut-setup-and-score.md: the cosmic-ray-specific native rate gate.
# The SKILL.md body names cosmic-ray only as "the metrics command" and never states the
# actual command or flag — that detail lives solely in references/. A correct answer proves
# the progressive-disclosure split is functional and the reference is being consulted.
smoke_test_skill "python-mutation-test" \
  "When using cosmic-ray instead of mutmut, what exact command and flag gate the CI build on the mutation survival rate?" \
  "cr-rate --fail-over"

smoke_test_summary
