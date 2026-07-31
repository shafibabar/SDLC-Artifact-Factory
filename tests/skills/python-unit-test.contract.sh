#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"

# Probes a references/-only fact: the complete worked parametrized domain test
# (test_outranks) in references/fixtures-and-parametrize.md carries an explicit
# pytest.param id for the guard case proving the lowest sensitivity level never
# outranks the highest. That id string ("public-never-outranks-restricted")
# lives only in references/fixtures-and-parametrize.md — the SKILL.md body
# teaches parametrize + explicit id= but contains no worked case ids, so
# answering requires the reference file, proving the progressive-disclosure
# split is functional.
smoke_test_skill "python-unit-test" \
  "In this skill's complete worked parametrized domain test for Sensitivity.outranks, what is the explicit pytest.param id of the case proving the lowest sensitivity level never outranks the highest?" \
  "public-never-outranks-restricted"

smoke_test_summary
