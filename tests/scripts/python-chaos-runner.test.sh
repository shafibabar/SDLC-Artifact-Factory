#!/bin/bash
# Behaviour test for python-chaos-test's copy of run-chaos-experiment.sh, the runner and target guard. Needs no
# Docker, Go, pytest, Toxiproxy or cluster. The cases are the ones go-chaos-test's copy is held to
# (tests/scripts/run-chaos-experiment.test.sh, the pytest tool's cases included), run here against the Python copy;
# tests/scripts/python-chaos-copies.test.sh checks the two programs are the same.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAOS_TEST_SKILL=python-chaos-test exec bash "$SCRIPT_DIR/run-chaos-experiment.test.sh"
