#!/bin/bash
# Behaviour test for python-load-test's copy of write-load-report.sh, the report writer. Needs no k6, Docker or
# cluster. The cases are the ones go-load-test's copy is held to
# (tests/scripts/write-load-report.test.sh), run here against the Python copy;
# tests/scripts/python-load-copies.test.sh checks the two programs are the same.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOAD_TEST_SKILL=python-load-test exec bash "$SCRIPT_DIR/write-load-report.test.sh"
