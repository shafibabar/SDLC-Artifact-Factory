#!/bin/bash
# assertions.sh — small, composable validation primitives for acceptance-tier
# tests (tests/skills/*.acceptance.sh, tests/agents/*.acceptance.sh).
# Source this from a test's validator function; do not execute directly.
# Each assert_* prints a one-line reason to stdout on failure and returns
# non-zero; returns 0 silently on success. A toolchain-dependent assertion
# (assert_go_valid, assert_ts_valid) prints a visible "SKIP:" line and
# returns 0 when its toolchain is absent — it never fakes a pass by staying
# silent, and it never fails a test purely for lacking a toolchain.

assert_frontmatter_field() {
  local file="$1" field="$2"
  if ! awk '/^---$/{n++; next} n==1' "$file" | grep -q "^${field}:"; then
    echo "missing frontmatter field '${field}:' in $file"
    return 1
  fi
  return 0
}

assert_word_count_at_most() {
  local text="$1" max="$2"
  local count
  count="$(wc -w <<<"$text")"
  if (( count > max )); then
    echo "word count $count exceeds max $max"
    return 1
  fi
  return 0
}

assert_contains() {
  local file="$1" pattern="$2"
  if ! grep -qF -- "$pattern" "$file"; then
    echo "expected pattern not found in $file: $pattern"
    return 1
  fi
  return 0
}

assert_not_contains() {
  local file="$1" pattern="$2"
  if grep -qF -- "$pattern" "$file"; then
    echo "forbidden pattern found in $file: $pattern"
    return 1
  fi
  return 0
}

# assert_go_valid <module-root-dir>
# Runs gofmt -l (formatting) and go vet ./... (real static analysis) over a
# self-contained Go module rooted at <dir>. Initializes a throwaway go.mod
# and fetches dependencies via `go mod tidy` if one isn't already present —
# this is a scratch acceptance-test module, not part of this repo's own
# build (this repo has no Go implementation code of its own).
assert_go_valid() {
  local dir="$1"
  if ! command -v go >/dev/null 2>&1; then
    echo "SKIP: go toolchain not found on PATH — assert_go_valid not enforced"
    return 0
  fi
  local fmt_out
  fmt_out="$(gofmt -l "$dir" 2>&1)"
  if [[ -n "$fmt_out" ]]; then
    echo "gofmt found unformatted files: $fmt_out"
    return 1
  fi
  (
    cd "$dir" || exit 1
    if [[ ! -f go.mod ]]; then
      go mod init acceptancetest >/tmp/go-mod-init.$$.log 2>&1 || { cat /tmp/go-mod-init.$$.log; rm -f /tmp/go-mod-init.$$.log; exit 1; }
      rm -f /tmp/go-mod-init.$$.log
    fi
    # Always tidy, even if go.mod already exists: a dispatched agent may have
    # created a go.mod without fully resolving it (found by live testing — a
    # generated router.go importing chi failed `go vet` with "no required
    # module provides package .../chi/v5" because go.mod existed but was
    # never tidied). Tidying an already-resolved module is a fast no-op.
    go mod tidy >/tmp/go-mod-tidy.$$.log 2>&1 || { cat /tmp/go-mod-tidy.$$.log; rm -f /tmp/go-mod-tidy.$$.log; exit 1; }
    rm -f /tmp/go-mod-tidy.$$.log
    go vet ./...
  )
}

# assert_ts_valid <file> [root-dir]
# Real `tsc --noEmit` compile check for a single .ts/.tsx file. <root-dir>
# (default: the file's own directory) gets a node_modules with
# typescript/react/@types/react/@types/node installed if it doesn't already
# have one, so tsc's ordinary Node-style module resolution — walking up from
# the file to find node_modules — resolves 'react' the same way it would in
# a real project. npx's ad-hoc `-p react` install does NOT achieve this: it
# installs into npx's own temp cache, which isn't an ancestor of the file
# being checked, so tsc still reports "Cannot find module 'react'" — found by
# live testing against a real generated component.
assert_ts_valid() {
  local file="$1" root="${2:-$(dirname "$file")}"
  if ! command -v npm >/dev/null 2>&1; then
    echo "SKIP: npm not found on PATH — assert_ts_valid not enforced"
    return 0
  fi
  if [[ ! -d "$root/node_modules/react" ]]; then
    local install_log="/tmp/ts-install.$$.log"
    if ! (cd "$root" && npm install --no-audit --no-fund --silent \
        typescript react @types/react @types/node) >"$install_log" 2>&1; then
      echo "npm install for TypeScript check failed: $(tail -c 500 "$install_log")"
      rm -f "$install_log"
      return 1
    fi
    rm -f "$install_log"
  fi
  local out
  if ! out="$(cd "$root" && npx --yes tsc --noEmit --jsx react-jsx \
      --esModuleInterop --skipLibCheck --strict "$file" 2>&1)"; then
    echo "tsc compile failed: ${out:0:800}"
    return 1
  fi
  return 0
}
