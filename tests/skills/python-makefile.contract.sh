#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the exact pinned GitHub Actions marketplace action that provisions uv
# in the CI workflow — a fact that lives ONLY in
# references/toolchain-and-ci.md. The SKILL.md body states the CI-Parity rule
# ("CI calls make ci, nothing else") and names uv as the toolchain, but NEVER
# names the setup action; only the reference file gives the concrete
# `astral-sh/setup-uv` step. A passing test proves the progressive-disclosure
# split is functional: the reference is loaded and consulted when the exact
# CI action name is needed.
smoke_test_skill \
  "python-makefile" \
  "In the GitHub Actions CI workflow this skill prescribes, what is the exact name of the pinned marketplace action that installs uv on the runner before make ci runs?" \
  "astral-sh/setup-uv"

smoke_test_summary
