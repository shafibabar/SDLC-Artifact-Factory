#!/bin/bash
# terminology-drift-detector.sh — PostToolUse hook, matcher: Write|Edit
# Purpose: warn (never block) when a written or edited artifact uses a drifted form of
#          a canonical glossary term, per the Drift Quick Reference table in
#          skills/glossary-management/SKILL.md, or a synonym banned in the
#          product's own per-Bounded-Context ubiquitous-language.md (D047-9).
# Contract: JSON on stdin (PostToolUse schema). Exit 0 = clean. Exit 1 =
#           non-blocking warning (message on stderr) — work is never stopped
#           for terminology; it's reported for a human/agent to fix.
# Scope: only artifacts/ paths — this repo's own skill content is not
#        re-checked here (the content-improvement campaign already covers it).
set -euo pipefail

INPUT="$(cat)"

python3 - "$INPUT" <<'PYEOF'
import json, re, sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    # Malformed/unexpected stdin — fail open, never crash a hook.
    print(json.dumps({"continue": True}))
    sys.exit(0)
tool_input = payload.get("tool_input", {})
file_path = tool_input.get("file_path", "")
content = tool_input.get("content", "")

if "/artifacts/" not in file_path.replace("\\", "/"):
    sys.exit(0)

if payload.get("tool_name") == "Edit" or not content:
    # An Edit carries only the changed snippet; the hook runs after the edit,
    # so check the whole file as it now is on disk (#1288).
    try:
        with open(file_path, encoding="utf-8", errors="replace") as fh:
            content = fh.read()
    except OSError:
        sys.exit(0)

DRIFT_PATTERNS = [
    # Whole-phrase drift: wrong regardless of case (the phrase itself is wrong).
    (re.compile(r"\boutbox pattern\b", re.I), "Transactional Outbox"),
    (re.compile(r"\boutbox table pattern\b", re.I), "Transactional Outbox"),
    (re.compile(r"\bgiven-when-then\b", re.I), "Given/When/Then"),
    # Casing-only drift: only the lowercase form is wrong (adjectival lowercase
    # use is legitimate prose, e.g. "a least-privilege policy" — see the Drift
    # Quick Reference in glossary-management). Coarse and warning-only: this
    # script cannot reliably distinguish "naming the pattern" from adjectival
    # use, so it over-flags a little on purpose. The agent-type
    # methodology-compliance-check hook makes the authoritative, nuanced call.
    (re.compile(r"\bcircuit breaker\b"), "Circuit Breaker"),
    (re.compile(r"\bleast privilege\b(?! \()"), "Principle of Least Privilege"),
]

hits = []
for pattern, canonical in DRIFT_PATTERNS:
    for m in pattern.finditer(content):
        hits.append(f"'{m.group(0)}' found — canonical form is '{canonical}'")

# --- The product's own banned synonyms (D047-9) ---
# Each Bounded Context's artifacts/<product>/design/<context>/ubiquitous-language.md
# carries a "## Banned Synonyms" table: banned word(s), comma-separated, then the
# term to use instead. A file inside design/<context>/ is checked against that
# context's bans; any other file in the product against every context's bans,
# except a word that is canonical in some context (a homonym, legitimate there).
import glob, os

def table_rows(text, heading):
    rows, inside = [], False
    for line in text.splitlines():
        if line.startswith("## "):
            inside = line[3:].strip().lower().startswith(heading)
            continue
        if inside and line.strip().startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if cells and not set(cells[0]) <= set("-: "):
                rows.append(cells)
    return rows[1:]  # drop the header row

def clean(word):
    return word.strip().strip("*`'\"").strip()

norm = file_path.replace("\\", "/")
m = re.match(r"(.*/artifacts/[^/]+)/(.*)$", norm)
if m and not norm.endswith("/ubiquitous-language.md"):
    product_dir, rel = m.groups()
    bans, canonical_terms = {}, set()
    for doc in sorted(glob.glob(os.path.join(product_dir, "design", "*", "ubiquitous-language.md"))):
        context = os.path.basename(os.path.dirname(doc))
        try:
            text = open(doc, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for cells in table_rows(text, "terms"):
            canonical_terms.add(clean(cells[0]).lower())
        for cells in table_rows(text, "banned synonyms"):
            if len(cells) < 2:
                continue
            use = clean(cells[1])
            canonical_terms.add(use.lower())
            for word in re.split(r"[,;]", cells[0]):
                if clean(word):
                    bans.setdefault(context, []).append((clean(word), use))
    in_context = re.match(r"design/([^/]+)/", rel)
    if in_context and in_context.group(1) in bans:
        applicable = [(w, u, in_context.group(1)) for w, u in bans[in_context.group(1)]]
    else:
        applicable = [(w, u, c) for c, pairs in bans.items() for w, u in pairs
                      if w.lower() not in canonical_terms]
    for word, use, context in applicable:
        pattern = re.compile(r"(?<![\w-])" + re.escape(word) + r"(?:s|es)?(?![\w-])", re.I)
        for hit in pattern.finditer(content):
            hits.append(f"'{hit.group(0)}' is banned in the {context} Ubiquitous Language — use '{use}'")

if not hits:
    sys.exit(0)

sys.stderr.write(
    f"Terminology drift in {file_path}:\n" + "\n".join(f"  - {h}" for h in hits) +
    "\nThis does not block the write — fix before the artifact is reviewed.\n"
)
sys.exit(1)
PYEOF
