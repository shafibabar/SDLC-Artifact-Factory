#!/bin/bash
source "$(dirname "$0")/../lib/harness.sh"
# Probes a fact that lives ONLY in references/layering-and-dependency-rules.md
# (and the worked example), never in the SKILL.md body: the named fitness
# function that enforces the domain layer's stdlib-only import rule.
smoke_test_skill "component-diagram" \
  "What automated fitness function enforces that the domain/ layer imports only the Go standard library, and which script does the go-makefile arch target run to check it?" \
  "check-imports.sh"
smoke_test_summary
