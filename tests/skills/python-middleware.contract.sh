#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/harness.sh"

# Probes the multi-worker rate-limit caveat from references/auth-ratelimit-cors.md.
# The SKILL.md body names "per-subject token-bucket rate limiting" only as a pointer;
# the *reason* an in-memory limiter under-counts across uvicorn workers — that the
# effective limit is "multiplied by the worker count" — exists ONLY in the reference
# file. The body never explains it (grep-verified absent). A passing test proves the
# progressive-disclosure split is functional: the reference is loaded when the question
# demands the mechanism, not just the name.
smoke_test_skill \
  "python-middleware" \
  "According to this skill, why does the in-memory per-subject token-bucket rate limiter under-count requests when a FastAPI service is deployed with multiple uvicorn workers, and what is the effect on the effective limit?" \
  "multiplied by the worker count"

smoke_test_summary
