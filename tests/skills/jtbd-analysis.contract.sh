#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a fact that lives ONLY in references/jtbd-interviewing.md: The Mom Test's
# taxonomy of the three types of bad data. The SKILL.md body names the Mom Test and
# its three rules but never enumerates the bad-data taxonomy — that is reference-only
# content, so a correct answer proves the references/ split loaded.
smoke_test_skill "jtbd-analysis" \
  "In The Mom Test interviewing discipline this skill uses, what are the three types of bad data an interviewer must discard? Name all three." \
  "fluff"

smoke_test_summary
