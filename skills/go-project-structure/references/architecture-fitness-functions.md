# Architecture Fitness Functions: Enforcing the Dependency Rule Mechanically

Self-contained reference for how this plugin verifies the Dependency Rule (`SKILL.md`'s "The Four Layers" table) is actually held, not just documented. Robert C. Martin's term, from Clean Architecture, is a **fitness function**: an automated, executable check that guards an architectural invariant, run on every build, rather than trusting reviewer vigilance to catch a violation before it merges.

**Provenance note, read before treating anything below as already shipped:** `go-makefile/SKILL.md`'s "The Architecture Lint" section already names an `arch` Makefile target and shows a single-check "sketch" — one `go list -deps` call against `internal/domain` only, checking for `pgx`/`chi`/`opentelemetry`. As of this writing, `scripts/check-imports.sh` does **not** exist as a file anywhere in this plugin's own `scripts/` directory (`scripts/github-project`, `naming-convention-enforcer.sh`, `post-artifact-created.sh`, `pre-phase-advance.sh`, `tdd-gate.sh`, `terminology-drift-detector.sh`, `validate-artifact-structure.sh` — no `check-imports.sh` among them) — and that is expected, not a gap in this plugin's own governance: `check-imports.sh` is generated *product* code, written into a generated Go service's own `scripts/` directory by `go-makefile`, the same way `Makefile` itself is. What follows is the complete, per-layer version of that script — an extension of `go-makefile`'s existing single-layer sketch to cover all four rows of the Dependency Rule table, not just the domain-vs-framework row. Treat it as this skill's authoritative statement of what the mechanism should do; `go-makefile` remains the skill that actually emits the file into a generated service.

---

## The Full Multi-Layer Check

```bash
#!/usr/bin/env bash
# scripts/check-imports.sh — architecture fitness function for the Dependency Rule.
# Invoked by `make arch` (go-makefile), which is part of `make ci`.
# Exits 1 and prints every violation found, not just the first, then fails the build.
set -euo pipefail

fail=0

check_layer() {
  local layer_dir="$1"; shift
  local -a forbidden=("$@")
  [ -d "$layer_dir" ] || return 0
  local deps
  deps="$(go list -deps "./${layer_dir}/..." 2>/dev/null || true)"
  for pattern in "${forbidden[@]}"; do
    local hits
    hits="$(echo "$deps" | grep -E "$pattern" || true)"
    if [ -n "$hits" ]; then
      echo "ERROR: ${layer_dir} imports forbidden dependency matching '${pattern}':"
      echo "$hits" | sed 's/^/  /'
      fail=1
    fi
  done
}

# internal/domain: stdlib + uuid + time only.
check_layer "internal/domain" \
  'jackc/pgx' 'go-chi/chi' 'go\.opentelemetry\.io' 'twmb/franz-go' \
  '/internal/application' '/internal/infrastructure' '/internal/handlers'

# internal/application: domain only — no handlers, no concrete infrastructure.
check_layer "internal/application" \
  'jackc/pgx' 'go-chi/chi' 'twmb/franz-go' \
  '/internal/handlers' '/internal/infrastructure'

# internal/infrastructure: implements domain ports — never calls upward into handlers.
check_layer "internal/infrastructure" \
  '/internal/handlers'

exit $fail
```

Each `check_layer` call encodes one row of `SKILL.md`'s "The Four Layers" table directly — the script *is* that table, made executable. `handlers` gets no `check_layer` call because it is the outermost of the four and has no inward-facing import restriction of its own (it may import `application` and `domain` freely; it just must never be imported *by* them, which the other three calls already enforce from the other direction).

---

## What It Catches

- **Transitive violations, not just direct ones.** `go list -deps` walks the full dependency graph, so `domain` importing a small in-house helper package that itself imports `pgx` fails the check two hops in — a violation hiding behind an intermediate package doesn't slip through.
- **All three checked layers in one pass**, each against its own forbidden set — not only the domain-vs-framework check `go-makefile`'s current sketch shows.
- **Every violation found, not just the first.** The loop continues checking every pattern against every layer and reports all hits before exiting — the same "report every problem in one round trip" discipline `go-error-handling` requires of validation-error aggregation, applied here to architecture violations instead of request fields.

## What It Does NOT Catch — Honest Limitations

- **Import-graph-only, not behavior-only.** The check sees which *packages* get imported, never what a function does with what it imports. `domain` code that reaches directly for `os`, `net`, or `database/sql` — all standard library, none on any forbidden-pattern list — passes cleanly while still violating the spirit of a pure domain layer (no I/O of any kind). Closing this would mean inverting the list from a deny-list (forbidden packages) to an allow-list (the exact stdlib subset permitted), which is stricter but far more maintenance-heavy — not done here, and worth stating as a conscious trade-off, not an oversight.
- **Does not verify interface ownership.** The check confirms import *direction*; it says nothing about which package *declares* a given interface. A producer-defined interface sitting in the wrong package, importing nothing forbidden, passes silently — "interfaces are defined by the consumer" (`SKILL.md`'s Minimalist Interfaces section) is a structural-review criterion, not an import-graph one, and no script in this plugin currently checks it mechanically.
- **Depends on a green build.** `go list -deps` requires the module to compile. If the code doesn't build, the check can't even run — architecture enforcement is strictly downstream of a successful build, never a substitute for one.
- **The pattern lists are a hand-maintained deny-list, and deny-lists rot.** Adding a new infrastructure dependency — a different message-broker client, a new secrets SDK — into `internal/infrastructure` without adding a matching forbidden-pattern entry to the `domain`/`application` calls above lets that same import slip into `domain` undetected. This is the single largest maintenance liability in the mechanism: every new external dependency this plugin's tech-stack defaults ever add needs a corresponding pattern-list update here, and nothing currently forces that update to happen alongside it.
- **Does not catch lateral coupling within a layer.** `internal/infrastructure/postgres` importing `internal/infrastructure/messaging` for no architectural reason is not a Dependency Rule violation (both are the same ring) and this script correctly stays silent on it — Go's compiler already forbids true import cycles, and same-layer sibling coupling is an ordinary code-review concern, not a fitness-function one.

## Invocation and Defence in Depth

Run via `make arch` (`go-makefile`), which `make ci` always includes — never invoked ad hoc as a developer's primary signal; it is a merge gate. It pairs with the `pre-phase-advance`/`methodology-review` governance hook at artifact-review time: the hook can catch an architectural intent problem before code exists at all, while this script catches an actual import-graph violation once code does exist. Neither is sufficient alone — the hook cannot see an import statement, and this script cannot see a design decision that hasn't been coded yet — which is why both exist rather than either being treated as a superset of the other.
