#!/bin/bash
# Behaviour test for python-load-test's copy of validate-python-load-tests.sh, the validator (with this skill's templates and examples). Needs no k6, Docker or
# cluster. The cases are the ones go-load-test's copy is held to
# (tests/scripts/validate-go-load-tests.test.sh), run here against the Python copy;
# tests/scripts/python-load-copies.test.sh checks the two programs are the same.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOAD_TEST_SKILL=python-load-test exec bash "$SCRIPT_DIR/validate-go-load-tests.test.sh"
