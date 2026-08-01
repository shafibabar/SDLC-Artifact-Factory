#!/usr/bin/env python3
"""
tests/arch/lint-duplication.test.py — contract test for scripts/lint-duplication.py
(P1.8, closes #789).

The linter's detection functions are PURE (they take a {skill_name: corpus} dict
plus a parsed-standards dict), so this test drives them with SYNTHETIC skills —
no dependence on the live tree for the behavioural assertions. It asserts:

  (a) find_duplicate_blocks flags a set of synthetic skills that share an
      identical multi-line block, names every sharing skill in the cluster, and
      does NOT drag in an unrelated control skill; the >= 3-skill production
      threshold holds (a 2-skill block is NOT flagged by default) while the
      min_skills param still lets a synthetic PAIR be detected; near-identical
      (one-word-different) blocks still cluster via shared shingles.

  (b) load_claude_standards parses the four standards out of a CLAUDE.md snippet
      (naming regex, exactly the five methodologies with NO stray "defect",
      frugality phrases, glossary terms), and find_restatements flags a
      synthetic skill line that restates a standard (the naming regex; the
      frugality phrase) while (i) never flagging the standard's legitimate home
      skill and (ii) leaving a clean skill alone.

  (a2) PRECISION — mandated artifact frontmatter is not duplication (#1192).
      strip_artifact_frontmatter_templates removes a `## Output Format`
      frontmatter template while leaving surrounding prose, a `---` horizontal
      rule, and a non-artifact `---` block byte-for-byte intact; three synthetic
      skills whose ONLY shared block is such a template are flagged on the RAW
      corpus but NOT after assemble_corpora — while a genuine repeated prose
      block is still reported (the detector must not go blind).

  (b2) PRECISION — citation + literal-regex rules (#1192).
      A restatement that cites `CLAUDE.md` on the same line, or within +/- 2
      lines, is NOT flagged; the same text without the citation IS; a skill that
      cites one occurrence but re-teaches the standard uncited elsewhere is
      still flagged. A Terraform-style `can(regex("^[a-z0-9]([a-z0-9-]{1,30}...`
      validation is NOT matched as the component-naming standard, while
      CLAUDE.md's literal `^[a-z0-9]+(-[a-z0-9]+)*$` IS.

  (b3) PRECISION — a DEFINITION is not a RESTATEMENT (#1202).
      CLAUDE.md § Non-Negotiable Methodology owns the MANDATE, not the subject
      matter, so the enforcement framing must sit in the same passage as the
      methodology it enforces. Glossary rows that merely DEFINE four
      methodologies — in a corpus whose only "mandatory" is an unrelated row 30+
      lines away — are NOT flagged, for any skill name including the glossary
      home; while a genuine re-teaching ("TDD is mandatory, tests before code,
      non-negotiable"), a verbatim copy of CLAUDE.md's own mandate table, and a
      genuine mandate sitting INSIDE the glossary home are all still flagged.
      Quorum, citation, and the untouched Ubiquitous Language detector are
      asserted alongside.

  (c) main() runs against the real repo, exits 0 (report-only), and writes the
      report to generated/duplication-report.md.

Prints PASS/FAIL lines; exits 0 iff every check passed. Standalone:
    python3 tests/arch/lint-duplication.test.py
"""

import importlib.util
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "lint-duplication.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("_lint_dup_under_test", MODULE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


passed, failed = 0, []


def check(name, condition):
    global passed
    if condition:
        print(f"PASS: lint-duplication ({name})")
        passed += 1
    else:
        print(f"FAIL: lint-duplication ({name})")
        failed.append(name)


check("module file exists", MODULE_PATH.is_file())
d = _load_module()

# ---------------------------------------------------------------------------
# (a) duplicate-block detection on synthetic skills
# ---------------------------------------------------------------------------

SHARED = (
    "The bounded context owns its data exclusively.\n"
    "Cross-context reads go through a published contract.\n"
    "Writes are validated at the aggregate root only.\n"
    "Events are emitted through the transactional outbox pattern.\n"
    "Downstream consumers subscribe idempotently to those events."
)

corpus = {
    "skill-alpha": "Intro paragraph unique to alpha.\n\n" + SHARED + "\n\nAlpha tail.",
    "skill-beta": "Beta preamble that differs entirely.\n\n" + SHARED + "\n\nBeta tail here.",
    # near-identical: one word changed ("exclusively" -> "completely").
    "skill-gamma": SHARED.replace("exclusively", "completely") + "\n\nGamma unique closing line.",
    # control skill: NO shared block at all.
    "skill-control": (
        "This skill is about picking a colour palette for dashboards.\n"
        "It discusses contrast ratios and accessible legends at length.\n"
        "Nothing here overlaps with domain modelling guidance whatsoever.\n"
        "Sequential and diverging scales are chosen by data type."
    ),
}

clusters = d.find_duplicate_blocks(corpus)  # default min_skills = 3
check("a duplicated block is found across >= 3 synthetic skills", len(clusters) >= 1)

top = clusters[0] if clusters else {"skills": [], "text": ""}
check(
    "cluster names all three skills that share the block",
    set(top["skills"]) >= {"skill-alpha", "skill-beta", "skill-gamma"},
)
check(
    "control skill (no shared block) is NOT in the cluster",
    "skill-control" not in top["skills"],
)
check(
    "cluster block text carries the shared lines (multi-line)",
    "transactional outbox pattern" in top["text"].lower() and top["num_lines"] >= 3,
)

# The >= 3 production threshold: a block in only TWO skills is not flagged...
pair_only = {
    "skill-one": SHARED + "\n\none unique.",
    "skill-two": SHARED + "\n\ntwo unique.",
    "skill-lonely": "Totally unrelated content about kubernetes probes and readiness.",
}
check(
    "a block shared by only 2 skills is NOT flagged at the default threshold",
    d.find_duplicate_blocks(pair_only) == [],
)
# ...but the min_skills param lets a synthetic PAIR be detected explicitly.
pair_clusters = d.find_duplicate_blocks(pair_only, min_skills=2)
check(
    "min_skills=2 detects the synthetic pair sharing an identical block",
    any(set(c["skills"]) == {"skill-one", "skill-two"} for c in pair_clusters),
)

# ---------------------------------------------------------------------------
# (a2) PRECISION: mandated artifact frontmatter is compliance, not duplication
#      (#1192, P4). CLAUDE.md § Artifact Standards REQUIRES every skill's
#      `## Output Format` template to carry name/version/phase/owner/created, so
#      its recurrence must not be reported as a duplicated block.
# ---------------------------------------------------------------------------

TEMPLATE = (
    "---\n"
    "name: threat-model\n"
    "product: [product name]\n"
    "version: 1.0.0\n"
    "phase: design\n"
    "owner: security-architect\n"
    "created: [date]\n"
    "---"
)

templated = (
    "## Output Format\n\n"
    "```markdown\n" + TEMPLATE + "\n\n# Threat Model: [Product Name]\n```\n"
)

stripped = d.strip_artifact_frontmatter_templates(templated)
check(
    "artifact-frontmatter template block is removed from the corpus",
    "version: 1.0.0" not in stripped and "owner: security-architect" not in stripped,
)
check(
    "surrounding prose survives the template strip",
    "## Output Format" in stripped and "# Threat Model: [Product Name]" in stripped,
)

# A `---` horizontal rule is NOT a frontmatter template — nothing may be eaten.
hrule = "Some prose above.\n\n---\n\nSome prose below, entirely unrelated.\n"
check(
    "a bare `---` horizontal rule is left intact",
    d.strip_artifact_frontmatter_templates(hrule) == hrule.rstrip("\n"),
)

# A `---` block that is NOT artifact frontmatter (no leading `name:`) is kept.
not_artifact = "---\nkind: Deployment\nreplicas: 3\nimage: nginx\n---"
check(
    "a non-artifact `---` block (no leading name:) is left intact",
    d.strip_artifact_frontmatter_templates(not_artifact) == not_artifact,
)

# A `name:`-led block missing most mandated keys is not the compliance template.
thin_block = "---\nname: something\nnote: only one other key here\n---"
check(
    "a `name:`-led block without the mandated keys is left intact",
    d.strip_artifact_frontmatter_templates(thin_block) == thin_block,
)

# End-to-end: three skills whose ONLY shared block is the mandated template.
template_only = {
    "skill-t1": "Unique opening prose for t1 that shares nothing.\n\n" + TEMPLATE,
    "skill-t2": "Completely different opening prose for t2 here.\n\n" + TEMPLATE,
    "skill-t3": "A third and unrelated opening paragraph for t3.\n\n" + TEMPLATE,
}
check(
    "control: the template WOULD be flagged on the raw, unassembled corpus",
    len(d.find_duplicate_blocks(template_only)) >= 1,
)
check(
    "artifact-frontmatter template is NOT reported as duplication after assembly",
    d.find_duplicate_blocks(d.assemble_corpora(template_only)) == [],
)

# ...and the detector is not blinded: a genuine repeated prose block, in skills
# that ALSO carry the template, is still reported — and the reported block is
# the prose, not the template.
genuine_plus_template = {
    "skill-g1": "G1 intro.\n\n" + SHARED + "\n\n" + TEMPLATE,
    "skill-g2": "G2 intro differs.\n\n" + SHARED + "\n\n" + TEMPLATE,
    "skill-g3": "G3 intro differs again.\n\n" + SHARED + "\n\n" + TEMPLATE,
}
gc = d.find_duplicate_blocks(d.assemble_corpora(genuine_plus_template))
check(
    "a genuine repeated prose block is STILL reported after assembly",
    len(gc) == 1 and set(gc[0]["skills"]) == {"skill-g1", "skill-g2", "skill-g3"},
)
check(
    "the surviving cluster is the prose block, not the frontmatter template",
    bool(gc)
    and "transactional outbox pattern" in gc[0]["text"].lower()
    and "owner: security-architect" not in gc[0]["text"],
)


# ---------------------------------------------------------------------------
# (b) CLAUDE.md-standard parsing + restatement detection
# ---------------------------------------------------------------------------

CLAUDE_SNIPPET = """
# CLAUDE.md

## Non-Negotiable Methodology

These five methodologies are mandatory. Their absence is a **defect**.

| Methodology | Where It Applies |
|---|---|
| **Domain-Driven Design** | Design, Implement |
| **Event Storming** | Design |
| **Test-Driven Development** | Implement |
| **Behavior-Driven Development** | Implement, Quality |
| **SOLID** | Implement |

## Naming Conventions

All component names must match: `^[a-z0-9]+(-[a-z0-9]+)*$`

## Ubiquitous Language

`Bounded Context` · `Ubiquitous Language` · `Domain Event` · `Aggregate`

## Budget and Frugality

- Open-source over paid tooling at every decision point.
"""

std = d.load_claude_standards(CLAUDE_SNIPPET)
check("naming regex parsed out of CLAUDE.md", std["naming_regex"] == r"^[a-z0-9]+(-[a-z0-9]+)*$")
check(
    "exactly the five methodologies parsed (no stray 'defect')",
    std["methodologies"] == [
        "domain-driven design", "event storming", "test-driven development",
        "behavior-driven development", "solid",
    ],
)
check("'defect' is not miscounted as a methodology", "defect" not in std["methodologies"])
check("frugality phrases present", "open-source over paid" in std["frugality_phrases"])
check("glossary terms parsed", "bounded context" in std["ubiquitous_terms"])

# A synthetic skill LINE that restates the naming-convention regex is flagged.
restate_corpus = {
    "some-random-skill": (
        "This skill validates identifiers.\n"
        "Every name must match `^[a-z0-9]+(-[a-z0-9]+)*$` exactly.\n"
        "Reject anything else."
    ),
}
r1 = d.find_restatements(restate_corpus, std)
check("naming-regex restatement in a synthetic skill line is flagged", len(r1) == 1)
check(
    "flagged finding identifies the naming-convention standard + repoint home",
    bool(r1) and r1[0]["skill"] == "some-random-skill"
    and "naming" in r1[0]["standard"].lower()
    and "CLAUDE.md" in r1[0]["repoint_to"],
)

# A synthetic skill line that restates the frugality rule is flagged.
frug_corpus = {"my-skill": "We always choose open-source over paid tooling here."}
rf = d.find_restatements(frug_corpus, std)
check(
    "frugality restatement in a synthetic skill line is flagged",
    len(rf) == 1 and "frugal" in rf[0]["standard"].lower(),
)

# The legitimate HOME skill for a standard is never flagged for restating it.
home_corpus = {"skill-authoring-standards": restate_corpus["some-random-skill"]}
check(
    "the naming standard's home skill is NOT flagged",
    d.find_restatements(home_corpus, std) == [],
)

# A clean skill (uses no standard) produces no restatement finding.
clean_corpus = {"clean-skill": "This skill explains how to write a helpful tooltip label."}
check("a clean skill yields no restatement finding", d.find_restatements(clean_corpus, std) == [])

# ---------------------------------------------------------------------------
# (b2) PRECISION: citing the CLAUDE.md home is the REQUIRED behaviour, and the
#      naming check matches CLAUDE.md's LITERAL pattern only (#1192, P4).
# ---------------------------------------------------------------------------

# Citation on the SAME line as the restated standard -> not a restatement.
cited_same_line = {
    "cited-skill": (
        "Pact Broker vs file pinning — how to choose.\n"
        '3. **Frugality (`CLAUDE.md`).** "Open-source over paid tooling..."\n'
        "A self-hosted Broker is open source but is still a service to run.\n"
    ),
}
check(
    "a restatement citing CLAUDE.md on the same line is NOT flagged",
    d.find_restatements(cited_same_line, std) == [],
)

# Citation within the +/- 2-line context window -> not a restatement.
cited_nearby = {
    "nearby-skill": (
        "Per CLAUDE.md, section Budget and Frugality:\n"
        "\n"
        "we choose open-source over paid tooling for visual regression.\n"
    ),
}
check(
    "a restatement citing CLAUDE.md within +/- 2 lines is NOT flagged",
    d.find_restatements(cited_nearby, std) == [],
)

# The SAME text without the citation IS flagged.
uncited = {
    "uncited-skill": (
        "Pact Broker vs file pinning — how to choose.\n"
        '3. **Frugality.** "Open-source over paid tooling..."\n'
        "A self-hosted Broker is open source but is still a service to run.\n"
    ),
}
ru = d.find_restatements(uncited, std)
check(
    "the same restatement WITHOUT a CLAUDE.md citation IS flagged",
    len(ru) == 1 and "frugal" in ru[0]["standard"].lower(),
)

# Cited once but re-taught uncited elsewhere -> still flagged (every-occurrence,
# not any-occurrence: one citation does not license restating it again).
mixed = {
    "mixed-skill": (
        "Per CLAUDE.md: open-source over paid tooling.\n"
        + "Filler line of unrelated guidance.\n" * 6
        + "Reminder: open-source over paid tooling, always.\n"
    ),
}
check(
    "citing one occurrence does not excuse a second, uncited restatement",
    len(d.find_restatements(mixed, std)) == 1,
)

# A Terraform-style validation regex is a DIFFERENT rule — never flagged as the
# component-naming standard.
terraform_corpus = {
    "opentofu-ish-skill": (
        'variable "tenant_id" {\n'
        "  type = string\n"
        "  validation {\n"
        '    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,30}[a-z0-9])$", var.tenant_id))\n'
        '    error_message = "tenant_id must be lowercase alphanumeric-with-dashes."\n'
        "  }\n"
        "}\n"
    ),
}
check(
    "a Terraform tenant-id regex is NOT matched as the component-naming standard",
    d.find_restatements(terraform_corpus, std) == [],
)

# ...while CLAUDE.md's literal pattern still is.
literal_corpus = {"literal-skill": 'The identifier pattern is `^[a-z0-9]+(-[a-z0-9]+)*$` exactly.'}
rl = d.find_restatements(literal_corpus, std)
check(
    "CLAUDE.md's LITERAL naming pattern IS still matched",
    len(rl) == 1 and "naming" in rl[0]["standard"].lower(),
)

# A naming-regex mention that cites its CLAUDE.md home is not a restatement.
cited_regex = {
    "cited-regex-skill": (
        "`product_slug` is constrained to the component-naming pattern\n"
        "`^[a-z0-9]+(-[a-z0-9]+)*$` — the pattern defined in CLAUDE.md §\n"
        "Naming Conventions — because it prefixes every artifact ID.\n"
    ),
}
check(
    "a naming-regex mention that cites CLAUDE.md is NOT flagged",
    d.find_restatements(cited_regex, std) == [],
)

# ---------------------------------------------------------------------------
# (b3) PRECISION: a DEFINITION is not a RESTATEMENT (#1202, P4).
#      CLAUDE.md § Non-Negotiable Methodology owns the MANDATE, not the subject
#      matter. The enforcement framing must therefore sit in the same passage as
#      the methodology it enforces (METHODOLOGY_ENFORCEMENT_WINDOW lines), not
#      merely somewhere in the same corpus. This is a rule about text shape, so
#      it applies identically to every skill — the glossary home is neither
#      blanket-exempted nor blinded.
# ---------------------------------------------------------------------------

# A glossary reference file: rows that DEFINE four of the five methodologies as
# canonical vocabulary, plus — far away — an unrelated row using the word
# "mandatory" about something else entirely. This is the real shape of
# skills/glossary-management/references/ubiquitous-language.md.
GLOSSARY_ROWS = (
    "| **SOLID** | Five object-oriented design principles: Single Responsibility,\n"
    "Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion. |\n"
    "| **Event Storming** | A collaborative, workshop-based technique for rapidly\n"
    "exploring complex business domains by mapping Domain Events on a timeline. |\n"
    + "| **Filler Term** | An unrelated glossary row. |\n" * 30
    + "| **Postmortem Trigger Criteria** | The written thresholds that make writing\n"
      "a postmortem mandatory rather than discretionary. |\n"
    + "| **Filler Term** | An unrelated glossary row. |\n" * 30
    + "| **Behavior-Driven Development (BDD)** | A methodology that defines system\n"
      "behavior using Given/When/Then scenarios before implementation. |\n"
    "| **Test-Driven Development (TDD)** | A methodology where tests are written\n"
    "before implementation code: write a failing test, pass it, refactor. |\n"
)

check(
    "control: the glossary fixture does carry the marker + a methodology quorum",
    sum(1 for m in std["methodologies"] if m in GLOSSARY_ROWS.lower()) >= d.METHODOLOGY_QUORUM
    and any(mk in GLOSSARY_ROWS.lower() for mk in std["methodology_markers"]),
)
check(
    "glossary rows DEFINING methodologies are NOT flagged as restating the mandate",
    d.find_restatements({"some-glossary-ish-skill": GLOSSARY_ROWS}, std) == [],
)
check(
    "the same rows under the real glossary-home name are also not flagged",
    d.find_restatements({"glossary-management": GLOSSARY_ROWS}, std) == [],
)

# The mandate itself — enforcement framing co-located with the methodologies —
# is STILL flagged. Detection must not be weakened.
GENUINE_MANDATE = (
    "Testing discipline for this service.\n"
    "\n"
    "Test-Driven Development is mandatory here: tests before implementation code,\n"
    "non-negotiable. Behavior-Driven Development is equally mandatory — every\n"
    "acceptance criterion gets a Gherkin feature file. Event Storming must precede\n"
    "any architecture decision, and SOLID applies to every class you write.\n"
    "Skipping any of these is a defect, not a warning.\n"
)
rm = d.find_restatements({"some-service-skill": GENUINE_MANDATE}, std)
check(
    "a genuine re-teaching of the mandate IS still flagged",
    len(rm) == 1 and "methodolog" in rm[0]["standard"].lower(),
)
check(
    "the genuine-mandate finding names the CLAUDE.md methodology home",
    bool(rm) and "Non-Negotiable Methodology" in rm[0]["repoint_to"],
)
check(
    "the glossary home is NOT blinded — a genuine mandate inside it is still flagged",
    len(d.find_restatements({"glossary-management": GENUINE_MANDATE}, std)) == 1,
)
check(
    "a genuine mandate is still caught when the SAME skill also defines the terms",
    len(d.find_restatements({"glossary-management": GLOSSARY_ROWS + "\n" + GENUINE_MANDATE}, std)) == 1,
)

# CLAUDE.md's OWN passage shape (mandate sentence, blank line, then the table)
# must be caught — that is what the enforcement window is calibrated to span.
CLAUDE_SHAPED = (
    "## Non-Negotiable Methodology\n"
    "\n"
    "These five methodologies are mandatory. Their absence in any artifact where\n"
    "they apply is a defect — not a warning, not advisory.\n"
    "\n"
    "| Methodology | Where It Applies |\n"
    "|---|---|\n"
    "| **Domain-Driven Design** | Design, Implement |\n"
    "| **Event Storming** | Design |\n"
    "| **Test-Driven Development** | Implement |\n"
    "| **Behavior-Driven Development** | Implement, Quality |\n"
    "| **SOLID** | Implement |\n"
)
rc_shape = d.find_restatements({"copycat-skill": CLAUDE_SHAPED}, std)
check(
    "a verbatim copy of CLAUDE.md's own mandate table IS flagged",
    len(rc_shape) == 1 and "methodolog" in rc_shape[0]["standard"].lower(),
)
check(
    "the copied-table finding counts all five methodologies",
    bool(rc_shape) and "5/5" in rc_shape[0]["evidence"],
)
# The citation rule still governs the mandate sites: a compact mandate that
# attributes itself to CLAUDE.md at every occurrence is compliant, not a
# restatement. (The +/- 2-line citation window is unchanged by this fix, so a
# skill that reproduces the whole 12-line table under a single citation line is
# still flagged — reproducing it is exactly what decision #4 forbids.)
CITED_MANDATE = (
    "Per CLAUDE.md § Non-Negotiable Methodology, this service applies:\n"
    "Domain-Driven Design, Event Storming, Test-Driven Development,\n"
    "Behavior-Driven Development and SOLID — all mandatory; see CLAUDE.md.\n"
)
check(
    "a compact mandate attributing itself to CLAUDE.md is NOT flagged",
    d.find_restatements({"citing-skill": CITED_MANDATE}, std) == [],
)
check(
    "the same compact mandate without the attribution IS flagged",
    len(d.find_restatements(
        {"uncited-mandate-skill": CITED_MANDATE.replace("CLAUDE.md § ", "").replace("; see CLAUDE.md", "")},
        std,
    )) == 1,
)

# Quorum still applies to the co-located mentions: three is not four.
SUB_QUORUM = (
    "Test-Driven Development is mandatory on this team. Behavior-Driven\n"
    "Development is likewise required, and SOLID is non-negotiable.\n"
)
check(
    "three co-located methodologies stay below the quorum",
    d.find_restatements({"three-only-skill": SUB_QUORUM}, std) == [],
)

# All five named, but with NO enforcement framing anywhere: not a mandate.
NO_MARKER = (
    "This skill touches Domain-Driven Design, Event Storming, Test-Driven\n"
    "Development, Behavior-Driven Development and SOLID in passing.\n"
)
check(
    "naming all five methodologies with no enforcement framing is not flagged",
    d.find_restatements({"passing-mention-skill": NO_MARKER}, std) == [],
)

# The pure helper itself, driven directly.
g_lines = GLOSSARY_ROWS.splitlines()
g_markers = d._signature_line_indices(g_lines, std["methodology_markers"], fold_case=True)
check(
    "mandated_methodologies() returns nothing for definition rows",
    g_markers != [] and d.mandated_methodologies(g_lines, std["methodologies"], g_markers) == ([], []),
)
m_lines = GENUINE_MANDATE.splitlines()
m_markers = d._signature_line_indices(m_lines, std["methodology_markers"], fold_case=True)
m_found, m_idx = d.mandated_methodologies(m_lines, std["methodologies"], m_markers)
check(
    "mandated_methodologies() returns the co-located methodologies + their lines",
    len(m_found) >= d.METHODOLOGY_QUORUM and m_idx and all(isinstance(i, int) for i in m_idx),
)
check(
    "mandated_methodologies() with no markers returns nothing",
    d.mandated_methodologies(m_lines, std["methodologies"], []) == ([], []),
)

# SCOPE NOTE (#1202 -> #1203): this fix targets the methodologies detector only.
# The Ubiquitous Language detector is a DIFFERENT rule — it fires on a skill
# carrying >= UBIQUITOUS_DUMP_THRESHOLD canonical terms — and is deliberately
# left untouched here, so `integration-design` is NOT cleared by this change.
std_ul = dict(std, ubiquitous_terms=[
    "anti-corruption layer", "bounded context", "change data capture",
    "circuit breaker", "consumer-driven contract", "context map",
    "dead letter queue", "domain event", "eventual consistency",
    "idempotency", "transactional outbox", "ubiquitous language",
])
term_user = {"integration-design-like": "\n".join(
    f"We apply the {t} pattern at this boundary." for t in std_ul["ubiquitous_terms"]
)}
ru_ul = d.find_restatements(term_user, std_ul)
check(
    "the Ubiquitous Language detector is unchanged (a term-heavy skill still fires)",
    len(ru_ul) == 1 and "ubiquitous" in ru_ul[0]["standard"].lower(),
)

# ---------------------------------------------------------------------------
# (c) main() runs against the real repo, report-only (exit 0), writes report
# ---------------------------------------------------------------------------

rc = d.main()
check("main() exits 0 (report-only, never fails the build)", rc == 0)
check(
    "main() wrote generated/duplication-report.md",
    (REPO_ROOT / "generated" / "duplication-report.md").is_file(),
)

# --- summary -----------------------------------------------------------------
print(f"\n--- Summary: {passed} passed, {len(failed)} failed ---")
if failed:
    print("Failed:")
    for f in failed:
        print(f"  - {f}")
    sys.exit(1)
sys.exit(0)
