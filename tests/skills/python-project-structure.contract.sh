#!/bin/bash
# Contract test for the python-project-structure skill.
# Probes a references/-only fact: import-linter's Layers contract is static
# import-graph analysis and therefore cannot see a runtime dynamic import
# (importlib.import_module) that crosses a layer boundary. This detail lives
# only in references/layout-and-import-linter.md, never in the SKILL.md body,
# so a correct answer proves progressive disclosure loaded the reference.
source "$(dirname "$0")/../lib/harness.sh"

smoke_test_skill "python-project-structure" \
  "The import-linter Layers contract enforces the four-layer dependency rule statically. Name the specific kind of runtime import a domain module could use to reach an adapter that would slip past the contract undetected." \
  "importlib.import_module"

smoke_test_summary
