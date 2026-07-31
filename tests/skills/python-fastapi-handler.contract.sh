#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the domain-error -> HTTP-status mapping table
# in references/error-envelope-and-di.md maps PreconditionFailedError to 412 with
# code PRECONDITION_FAILED. This category/code lives ONLY in the reference file, not
# in SKILL.md's body — so a correct answer proves the progressive-disclosure split
# loads references/ on demand.
smoke_test_skill "python-fastapi-handler" \
  "In the single DomainError exception handler's status-code mapping table, what SCREAMING_SNAKE_CASE error code does a PreconditionFailedError map to?" \
  "PRECONDITION_FAILED"

smoke_test_summary
