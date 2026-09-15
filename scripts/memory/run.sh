#!/bin/bash
# run.sh — dispatches to the per-repo .sdlc-memory/.venv Python (where
# fastembed/sqlite-vec live, once bootstrap.sh has provisioned it) if one
# exists, otherwise falls back to system python3. All memory-engine hooks
# and commands should invoke scripts through this wrapper rather than
# calling python3 directly, so they transparently pick up real embeddings
# once bootstrapped without any caller needing to know the venv path.
set -uo pipefail

REPO_ROOT="${SDLC_MEMORY_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
VENV_PY="$REPO_ROOT/.sdlc-memory/.venv/bin/python3"

if [ -x "$VENV_PY" ]; then
  exec "$VENV_PY" "$@"
fi
exec python3 "$@"
