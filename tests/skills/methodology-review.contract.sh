#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a fact that lives ONLY in references/review-report-template.md:
# the review-report frontmatter carries a `reviewed_artifact:` field naming
# the path/name of the artifact under review. The SKILL.md body names the
# template's existence but never specifies this frontmatter field — proving
# the progressive-disclosure split is functional.
smoke_test_skill "methodology-review" \
  "In a methodology review report, which frontmatter field records the path or name of the artifact that was reviewed?" \
  "reviewed_artifact"

smoke_test_summary
