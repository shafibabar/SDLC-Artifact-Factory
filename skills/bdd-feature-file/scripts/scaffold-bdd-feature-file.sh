#!/bin/bash
# scaffold-bdd-feature-file.sh — skill-owned script for skills/bdd-feature-file.
# Purpose: start a story's feature file from its acceptance criteria: one Rule
#          per cited map rule, one scenario per criterion, tagged with its ID and
#          angle. Gherkin criteria are copied step for step; Rule/Verify/Example
#          criteria get placeholder steps. The header stays unfilled on purpose.
# Usage:   scaffold-bdd-feature-file.sh <product> <story-id> <story-title>
#            product     - directory name under artifacts/ (e.g. kerbside)
#            story-id    - US-4, or just 4
#            story-title - e.g. "Cancel a pre-order"
#          Run from the product repository root (the folder holding artifacts/).
# Output:  writes artifacts/<product>/implement/features/US-n.feature and prints
#          that path. Finish it with Edit so the write checks and the manifest
#          registration run.
# Contract: plain CLI args, agent-invoked. Exit 0 written; 1 refused (no criteria
#           file or no criterion in it, file exists); 2 usage or environment error.
#           It does not check that the product owner approved the criteria.
set -euo pipefail

usage() { echo "Usage: scaffold-bdd-feature-file.sh <product> <story-id> <story-title>" >&2; exit 2; }

[ $# -eq 3 ] || usage
PRODUCT="$1"; STORY="$2"; TITLE="$3"
[[ "$PRODUCT" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "error: product '$PRODUCT' is not a directory name under artifacts/" >&2; usage; }
[[ "$STORY" =~ ^(US-)?[0-9]+[a-z]?$ ]] || { echo "error: story-id '$STORY' is not US-n" >&2; usage; }
STORY="US-${STORY#US-}"
[ -n "$TITLE" ] || usage

CRITERIA="artifacts/$PRODUCT/ideate/acceptance-criteria/$STORY.md"
MAP="artifacts/$PRODUCT/ideate/example-maps/$STORY.md"
OUT="artifacts/$PRODUCT/implement/features/$STORY.feature"

if [ ! -f "$CRITERIA" ]; then
  echo "error: no acceptance criteria at $CRITERIA. Write and approve them first (acceptance-criteria); scenarios are never invented." >&2
  exit 1
fi
if [ -e "$OUT" ]; then
  echo "error: $OUT already exists" >&2
  exit 1
fi

python3 - "$CRITERIA" "$MAP" "$OUT" "$PRODUCT" "$STORY" "$TITLE" "$(date +%Y-%m-%d)" <<'PYEOF'
import os, re, sys

criteria, mapfile, out, product, story, title, today = sys.argv[1:]

def read(p):
    return re.sub(r"<!--.*?-->", "", open(p, encoding="utf-8", errors="replace").read().replace("\r\n", "\n"), flags=re.S)

text = read(criteria)
rule_titles = dict(re.findall(r"^### (R\d+):[ \t]*(.+?)[ \t]*$", read(mapfile), re.M)) if os.path.isfile(mapfile) else {}

ref = re.search(r"\bAs an? (.+?),?\s+I want (.+?),?\s+so that (.+?)\.?[ \t]*$", text, re.I | re.M)
who, what, why = ref.groups() if ref else ("<persona>", "<capability>", "<outcome>")

ANGLES = {"happy path": "happy", "error / negative scenarios": "negative", "boundary / edge cases": "edge"}
groups, order, count = {}, [], 0
parts = re.split(r"^## (.+?)[ \t]*$", text, flags=re.M)
for i in range(1, len(parts), 2):
    angle = ANGLES.get(parts[i].strip().lower())
    if not angle:
        continue
    crits = re.split(r"^### (.+?)[ \t]*$", parts[i + 1], flags=re.M)
    for j in range(1, len(crits), 2):
        m = re.match(r"(AC-US-\d+[a-z]?\.\d+):[ \t]*(.+)$", crits[j])
        if not m:
            continue
        cid, name = m.groups()
        block = crits[j + 1]
        src = re.search(r"^[-*] From:.*?\b(R\d+)\b", block, re.M)
        rule = src.group(1) if src else "R?"
        gherkin = re.search(r"^```gherkin[ \t]*\n(.*?)^```", block, re.M | re.S)
        lines = []
        if gherkin:
            for step in gherkin.group(1).splitlines():
                step = step.strip().rstrip(",.")
                if step:
                    lines.append("      " + step)
        else:
            for f in ("Rule", "Verify", "Example"):
                v = re.search(r"^\*\*%s:\*\*[ \t]*(.+)$" % f, block, re.M)
                if v:
                    lines.append("      # %s: %s" % (f, v.group(1).strip()))
            lines += ["      Given <state from the criterion's example>",
                      "      When <one action>",
                      "      Then <outcome the persona can observe>"]
        if rule not in groups:
            groups[rule] = []
            order.append(rule)
        groups[rule].append("    @%s @%s\n    Scenario: %s\n%s\n" % (cid, angle, name, "\n".join(lines)))
        count += 1

if not count:
    sys.exit("error: %s holds no '### AC-US-n.m: title' criterion under an angle heading" % criteria)

head = [("name", "feature-file"), ("product", product), ("story-id", story), ("version", "1.0.0"),
        ("phase", "implement"), ("owner", "test-strategist"), ("created", today),
        ("summary", "<one sentence, 200 characters at most: which story, which criteria these scenarios prove>"),
        ("run", "<agent-run or workshop>"),
        ("traces_to", "ideate/acceptance-criteria/%s.md; ideate/example-maps/%s.md" % (story, story))]
doc = ["# %s: %s" % kv for kv in head]
doc.append('# <agent-run: "Agent-run: one agent (test-strategist) wrote these from the approved criteria; '
           'no workshop was held." workshop: "Participants: names and roles">')
doc += ["", "Feature: %s" % title, "  As a %s" % who, "  I want %s" % what, "  So that %s" % why, ""]
for rule in order:
    doc.append("  Rule: %s" % rule_titles.get(rule, "<%s in business words>" % rule))
    doc.append("")
    doc.append("\n".join(groups[rule]))
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, "x", encoding="utf-8").write("\n".join(doc).rstrip() + "\n")
PYEOF
echo "$OUT"
