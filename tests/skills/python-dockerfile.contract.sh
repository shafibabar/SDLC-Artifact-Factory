#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the pip-variant deterministic-install flag from
# references/multistage-dockerfile.md. The SKILL.md body says the pip fallback installs
# with "pip's hash-enforcing mode" but NEVER names the exact flag; only the reference file
# gives it as `pip install --require-hashes`. A passing test proves the progressive-disclosure
# split is functional: the reference is loaded and consulted when the concrete flag is needed.
smoke_test_skill \
  "python-dockerfile" \
  "In the pip fallback, when installing from a pip-tools compiled requirements.txt in the build stage, what exact pip flag enforces that every downloaded wheel matches a pinned hash (and fails the build otherwise)?" \
  "--require-hashes"

smoke_test_summary
