#!/bin/bash
# bootstrap.sh — provisions the SDLC memory engine in whichever repo this
# plugin is enabled in. Idempotent: a repo that already has a working
# .sdlc-memory/.venv is a fast no-op.
#
# Installs fastembed + sqlite-vec into an isolated per-repo venv (no global
# pip pollution, no shared daemon, nothing that depends on the OpenViking
# repo/service). If pip/network isn't available, this still succeeds --
# the engine falls back to dependency-free hash/lexical matching
# (see models.py) rather than failing hard.
set -uo pipefail

# Accept an explicit repo root as $1 (hook scripts pass the project cwd
# from the JSON payload here -- hook processes run with cwd set to the
# PLUGIN's own directory, not the project, per live-tested behavior noted
# in scripts/post-artifact-created.sh), else SDLC_MEMORY_REPO_ROOT, else
# fall back to git/pwd for direct/manual invocation.
REPO_ROOT="${1:-${SDLC_MEMORY_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
MEM_DIR="$REPO_ROOT/.sdlc-memory"
VENV_DIR="$MEM_DIR/.venv"
MARKER="$VENV_DIR/.bootstrap-ok"
FAILED_MARKER="$MEM_DIR/.bootstrap-failed"
RETRY_COOLDOWN_SECONDS=3600

mkdir -p "$MEM_DIR"

# Every repo this plugin is enabled in gets its own .sdlc-memory/ --
# the durable, git-committed part is .sdlc-memory/tree/**/*.md (that IS
# the memory, meant to be shared with the team); the regeneratable/local
# part (the venv, the derived SQLite index) should not be committed.
GITIGNORE="$REPO_ROOT/.gitignore"
MARKER_LINE="# sdlc-memory (added by SDLC-Artifact-Factory's memory engine)"
if [ -f "$GITIGNORE" ] && ! grep -qF "$MARKER_LINE" "$GITIGNORE" 2>/dev/null; then
  {
    echo ""
    echo "$MARKER_LINE"
    echo ".sdlc-memory/.venv/"
    echo ".sdlc-memory/index.db"
  } >> "$GITIGNORE"
elif [ ! -f "$GITIGNORE" ]; then
  {
    echo "$MARKER_LINE"
    echo ".sdlc-memory/.venv/"
    echo ".sdlc-memory/index.db"
  } > "$GITIGNORE"
fi

if [ -f "$MARKER" ]; then
  exit 0
fi

# This hook runs before every Agent invocation (see scripts/memory-bootstrap.sh)
# -- if install failed (offline, no pip, etc.) don't eat the full install
# latency again on every single agent call. Retry at most once per hour.
if [ -f "$FAILED_MARKER" ]; then
  last_attempt="$(cat "$FAILED_MARKER" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  if [ $((now - last_attempt)) -lt "$RETRY_COOLDOWN_SECONDS" ]; then
    exit 0
  fi
fi

PYTHON_BIN="$(command -v python3 || true)"
if [ -z "$PYTHON_BIN" ]; then
  echo "sdlc-memory: python3 not found; falling back to dependency-free matching" >&2
  exit 0
fi

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR" 2>/dev/null || {
    echo "sdlc-memory: could not create venv; falling back to dependency-free matching" >&2
    date +%s > "$FAILED_MARKER"
    exit 0
  }
fi

"$VENV_DIR/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1
if "$VENV_DIR/bin/pip" install --quiet fastembed sqlite-vec >/dev/null 2>&1; then
  touch "$MARKER"
  rm -f "$FAILED_MARKER"
  echo "sdlc-memory: fastembed + sqlite-vec installed in $VENV_DIR"
else
  echo "sdlc-memory: dependency install failed (offline?); falling back to dependency-free matching" >&2
  date +%s > "$FAILED_MARKER"
fi

exit 0
