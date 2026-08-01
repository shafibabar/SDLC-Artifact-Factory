#!/usr/bin/env python3
"""
scripts/lint-duplication.py — the P1.8 duplication / restatement linter
(closes #789, part of P1 Governance Foundation #780).

WHAT IT DOES (report-only — always exits 0):
  Enumerates every skill via scripts/arch/manifest.py (never raw yaml) and reads
  each skill's PROSE CORPUS (SKILL.md body below the frontmatter + every
  references/*.md it owns), then finds two kinds of duplication that the P4
  "De-duplication & Repointing" parent will act on:

    (a) NEAR-IDENTICAL TEXT BLOCKS recurring across >= 3 skill corpora.
        Whitespace is normalized and a sliding WINDOW-line shingle/hash pass
        finds blocks that repeat (verbatim OR near-verbatim — a block that
        differs by a word still shares most of its internal shingles). Adjacent
        duplicated shingles are merged back into one readable multi-line block
        so the report shows the block once with the full set of skills carrying
        it.

        NOT duplication: the mandated ARTIFACT FRONTMATTER inside a skill's
        `## Output Format` template. CLAUDE.md § Artifact Standards REQUIRES
        every emitted artifact — and every Output Format template — to carry a
        `name/version/phase/owner/created` block, so its recurrence across
        skills is COMPLIANCE, not duplication. Those blocks are therefore
        excluded at CORPUS-ASSEMBLY time (assemble_corpora ->
        strip_artifact_frontmatter_templates) rather than post-filtered out of
        the findings, which keeps the detectors themselves pure and unaware of
        the exception.

    (b) RESTATEMENTS OF A CLAUDE.md STANDARD. CLAUDE.md is the always-on home
        for four standards a skill must POINT TO, never re-teach:
          * the naming-convention regex  ^[a-z0-9]+(-[a-z0-9]+)*$
          * the frugality rules          ("open-source over paid", ...)
          * the five non-negotiable methodologies (DDD / Event Storming / TDD /
            BDD / SOLID) framed as mandatory
          * the Ubiquitous Language glossary terms
        The standards' signatures are parsed OUT OF CLAUDE.md at runtime (not
        hard-coded), so the linter stays honest as CLAUDE.md evolves. The
        legitimate home skill for each standard is allow-listed and never flagged.

        NOT a restatement: a block that CITES its CLAUDE.md home. Pointing at
        the home and quoting briefly with attribution is exactly the required
        behaviour, so a finding is suppressed when every occurrence of the
        standard's signature has `CLAUDE.md` within +/- CITATION_CONTEXT_LINES
        lines. "Every", not "any": a skill that cites once but re-teaches the
        standard again elsewhere uncited is still restating it.

        The naming-convention check matches CLAUDE.md's LITERAL pattern only —
        an unrelated regex that merely looks like a naming regex (e.g. a
        Terraform `can(regex("^[a-z0-9]([a-z0-9-]{1,30}[a-z0-9])$", ...))`
        tenant-id validation) is a different rule for a different purpose and
        is not a restatement of this one.

  Both findings are written, ranked, to generated/duplication-report.md — this
  snapshot IS the P4 de-duplication backlog. The linter NEVER fails the build:
  duplication is a backlog signal, not a gate.

DESIGN (per ARCHITECTURE-REVIEW-CAMPAIGN.md §3): imports the shared normalized
manifest (scripts/arch/manifest.py); its detection functions are PURE (operate
on a {skill_name: corpus_text} dict + a parsed-standards dict) so the bundled
test can drive them with synthetic skills. Only main() touches the filesystem.

Standalone:  python3 scripts/lint-duplication.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE / "arch"))

import manifest  # noqa: E402  (scripts/arch/manifest.py — the shared parser)

REPO_ROOT = manifest.REPO_ROOT
CLAUDE_MD = REPO_ROOT / "CLAUDE.md"
REPORT_PATH = REPO_ROOT / "generated" / "duplication-report.md"

# --- tuning knobs ------------------------------------------------------------
SHINGLE_WINDOW = 4          # consecutive normalized lines per shingle
MIN_SKILLS_FOR_DUP = 3      # a block must recur in >= this many skills
MIN_LINE_CHARS = 12         # ignore lines shorter than this when shingling
MIN_SHINGLE_CHARS = 48      # ignore shingles whose joined text is trivially short

# Skills that are the LEGITIMATE home of a given standard — never flagged as
# restating it. (These are the cross-cutting homes CLAUDE.md points to.)
STANDARD_HOME_SKILLS = {
    "naming_regex": {"skill-authoring-standards", "naming-conventions"},
    "frugality": {"frugality", "budget-management", "cost-optimization"},
    "methodologies": {"methodology-review", "methodology-selection"},
    "ubiquitous_language": {"glossary-management", "ubiquitous-language"},
}


# ---------------------------------------------------------------------------
# Corpus assembly
#
# read_skill_corpus() is the only filesystem step (called from main()).
# strip_artifact_frontmatter_templates() / assemble_corpora() are PURE text
# transforms so the bundled test can drive the whole pipeline synthetically.
# ---------------------------------------------------------------------------

_FM_RE = re.compile(r"^﻿?---\s*\n.*?\n---\s*(?:\n|$)", re.DOTALL)

# --- artifact-frontmatter template exclusion (CLAUDE.md § Artifact Standards) -
# A `---` ... `---` block whose FIRST key is `name:` and which carries most of
# the mandated artifact-frontmatter keys is the compliance template every skill
# is REQUIRED to show; it is not cross-skill duplication.
_FM_DELIM_RE = re.compile(r"^\s*---\s*$")
# `key:` at (near) the left margin — the shape of a YAML mapping entry.
_FM_KEY_RE = re.compile(r"^ {0,3}([A-Za-z_][A-Za-z0-9_-]*)\s*:(?:\s|$)")
# The keys CLAUDE.md § Artifact Standards mandates alongside `name`.
ARTIFACT_FM_MANDATED_KEYS = ("version", "phase", "owner", "created")
# How many of those must be present for the block to read as the mandated
# template rather than as an arbitrary `---`-delimited chunk of prose.
ARTIFACT_FM_MIN_MANDATED_KEYS = 3
# A template longer than this is not a frontmatter block; stop looking.
ARTIFACT_FM_MAX_LINES = 40


def strip_frontmatter(text: str) -> str:
    """Return the markdown body with a leading YAML frontmatter block removed."""
    return _FM_RE.sub("", text, count=1)


def _scan_frontmatter_block(lines: list[str], start: int):
    """If lines[start] opens an artifact-frontmatter template, return its end index.

    `start` is the index of the opening `---`. Returns the index of the closing
    `---`, or None if the block is not an artifact-frontmatter template. Pure.
    """
    keys: list[str] = []
    i = start + 1
    limit = min(len(lines), start + 1 + ARTIFACT_FM_MAX_LINES)
    while i < limit:
        line = lines[i]
        if _FM_DELIM_RE.match(line):
            if not keys or keys[0] != "name":
                return None
            mandated = sum(1 for k in ARTIFACT_FM_MANDATED_KEYS if k in keys)
            return i if mandated >= ARTIFACT_FM_MIN_MANDATED_KEYS else None
        m = _FM_KEY_RE.match(line)
        if m:
            keys.append(m.group(1).lower())
        elif line.strip() and line[:1].isspace():
            pass  # an indented continuation (list item / nested value) — allowed
        else:
            return None  # blank line or prose: not a frontmatter block
        i += 1
    return None


def strip_artifact_frontmatter_templates(text: str) -> str:
    """Remove mandated artifact-frontmatter template blocks from a corpus. Pure.

    CLAUDE.md § Artifact Standards requires every artifact — and therefore every
    skill's `## Output Format` template — to carry a
    `name/version/phase/owner/created` frontmatter block. Its recurrence across
    skills is compliance, not duplication, so it is excluded from the corpus
    before any detector sees it. Everything else is left byte-for-byte intact.
    """
    lines = text.splitlines()
    kept: list[str] = []
    i = 0
    while i < len(lines):
        if _FM_DELIM_RE.match(lines[i]):
            end = _scan_frontmatter_block(lines, i)
            if end is not None:
                i = end + 1
                continue
        kept.append(lines[i])
        i += 1
    return "\n".join(kept)


def assemble_corpora(raw_corpus_by_skill: dict) -> dict:
    """Apply every corpus-assembly exclusion to each skill's raw prose. Pure.

    Excluding here (rather than post-filtering findings) keeps the detectors
    themselves free of exception handling: they simply never see the mandated
    boilerplate.
    """
    return {
        name: strip_artifact_frontmatter_templates(text)
        for name, text in raw_corpus_by_skill.items()
    }


def read_skill_corpus(record: dict) -> str:
    """Concatenate a skill's SKILL.md body + all its references/*.md prose.

    `record` is a manifest.load_skills() record; its 'dir' is repo-relative.
    Returns the RAW corpus — run it through assemble_corpora() before detection.
    """
    skill_dir = REPO_ROOT / record["dir"]
    parts: list[str] = []
    skill_md = skill_dir / "SKILL.md"
    if skill_md.is_file():
        parts.append(strip_frontmatter(skill_md.read_text(encoding="utf-8")))
    refs = skill_dir / "references"
    if refs.is_dir():
        for ref in sorted(refs.glob("*.md")):
            parts.append(strip_frontmatter(ref.read_text(encoding="utf-8")))
    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# (a) Near-identical recurring blocks — pure, shingle/hash based
# ---------------------------------------------------------------------------

def _normalize_line(line: str) -> str:
    return " ".join(line.strip().lower().split())


def _line_sequence(text: str) -> list[tuple[str, str]]:
    """(normalized, original) for each substantive line, blanks/short dropped."""
    seq = []
    for raw in text.splitlines():
        norm = _normalize_line(raw)
        if len(norm) >= MIN_LINE_CHARS:
            seq.append((norm, raw.strip()))
    return seq


def _shingles(seq: list[tuple[str, str]]):
    """Yield (start_index, key, original_lines) for each WINDOW-line shingle."""
    n = len(seq)
    w = SHINGLE_WINDOW
    for i in range(0, n - w + 1):
        window = seq[i:i + w]
        key = "\n".join(norm for norm, _ in window)
        if len(key) < MIN_SHINGLE_CHARS:
            continue
        yield i, key, [orig for _, orig in window]


def find_duplicate_blocks(corpus_by_skill: dict, min_skills: int = MIN_SKILLS_FOR_DUP) -> list[dict]:
    """Find near-identical multi-line blocks recurring across >= min_skills skills.

    Returns a list of clusters, ranked most-shared first. Each cluster:
      { "skills": [names sorted], "num_skills": int, "num_lines": int,
        "text": "<representative block, original casing>" }
    Pure: `corpus_by_skill` is {skill_name: full_corpus_text}.
    """
    # 1. shingle key -> set of skills containing it.
    key_skills: dict[str, set] = {}
    per_skill_seq: dict[str, list] = {}
    for name in sorted(corpus_by_skill):
        seq = _line_sequence(corpus_by_skill[name])
        per_skill_seq[name] = seq
        seen_here = set()
        for _, key, _orig in _shingles(seq):
            if key in seen_here:
                continue
            seen_here.add(key)
            key_skills.setdefault(key, set()).add(name)

    dup_keys = {k for k, s in key_skills.items() if len(s) >= min_skills}
    if not dup_keys:
        return []

    # 2. Walk each skill's shingles; merge adjacent duplicated shingles (with the
    #    same skill-set) into one readable block. Consume each key once globally
    #    so the same block isn't re-emitted from every skill that carries it.
    consumed: set[str] = set()
    clusters: list[dict] = []
    for name in sorted(per_skill_seq):
        seq = per_skill_seq[name]
        shs = list(_shingles(seq))
        j = 0
        while j < len(shs):
            start_i, key, orig = shs[j]
            if key not in dup_keys or key in consumed:
                j += 1
                continue
            skillset = frozenset(key_skills[key])
            block_lines = list(orig)
            consumed.add(key)
            k = j + 1
            # Extend while the next shingle is contiguous, duplicated with the
            # SAME skill-set, and unconsumed — appending only its newest line.
            while k < len(shs):
                nxt_i, nxt_key, nxt_orig = shs[k]
                if (
                    nxt_i == start_i + (k - j)
                    and nxt_key in dup_keys
                    and nxt_key not in consumed
                    and frozenset(key_skills[nxt_key]) == skillset
                ):
                    block_lines.append(nxt_orig[-1])
                    consumed.add(nxt_key)
                    k += 1
                else:
                    break
            clusters.append({
                "skills": sorted(skillset),
                "num_skills": len(skillset),
                "num_lines": len(block_lines),
                "text": "\n".join(block_lines),
            })
            j = k

    clusters.sort(key=lambda c: (-c["num_skills"], -c["num_lines"], c["text"]))
    return clusters


# ---------------------------------------------------------------------------
# (b) Restatement of a CLAUDE.md standard — parse standards, then match
# ---------------------------------------------------------------------------

def _section(md: str, heading: str) -> str:
    """Return the body of a '## <heading>' section of a markdown file."""
    m = re.search(
        rf"^##\s+{re.escape(heading)}\s*\n(.*?)(?=^##\s|\Z)",
        md, re.DOTALL | re.MULTILINE,
    )
    return m.group(1) if m else ""


def load_claude_standards(claude_md_text: str) -> dict:
    """Parse the four flagged standards' signatures OUT of CLAUDE.md.

    Returns:
      { "naming_regex": "<literal regex or None>",
        "frugality_phrases": [distinctive lowercase phrases],
        "methodologies": [five lowercase names],
        "methodology_markers": [enforcement words],
        "ubiquitous_terms": [lowercase canonical terms] }
    """
    md = claude_md_text

    naming_sec = _section(md, "Naming Conventions")
    nm = re.search(r"`(\^\[a-z0-9\][^`]*\$)`", naming_sec)
    naming_regex = nm.group(1) if nm else r"^[a-z0-9]+(-[a-z0-9]+)*$"

    methods_sec = _section(md, "Non-Negotiable Methodology")
    # The five methodologies are the bold cell in each markdown TABLE ROW; the
    # section intro also bolds "defect", so only mine rows that start with '|'.
    methodologies = [
        m.group(1).strip().lower()
        for line in methods_sec.splitlines()
        if line.lstrip().startswith("|")
        for m in [re.search(r"\*\*([^*]+?)\*\*", line)]
        if m and m.group(1).strip()
    ]
    if not methodologies:  # defensive fallback to the known five
        methodologies = [
            "domain-driven design", "event storming", "test-driven development",
            "behavior-driven development", "solid",
        ]

    ul_sec = _section(md, "Ubiquitous Language")
    ubiquitous_terms = sorted({
        t.strip().lower()
        for t in re.findall(r"`([^`]+)`", ul_sec)
        if len(t.strip()) >= 4 and " " in t.strip() or t.strip().lower() == "idempotency"
    })

    return {
        "naming_regex": naming_regex,
        "frugality_phrases": [
            "open-source over paid", "open source over paid",
            "prefer simpler solutions over sophisticated",
            "no external paid apis",
        ],
        "methodologies": methodologies,
        "methodology_markers": [
            "non-negotiable", "non negotiable", "mandatory", "is a defect", "are a defect",
        ],
        "ubiquitous_terms": ubiquitous_terms,
    }


# how many distinct glossary terms in a skill body suggest it is RESTATING the
# glossary rather than merely using a few terms in passing.
UBIQUITOUS_DUMP_THRESHOLD = 10
# how many of the five methodologies must co-occur (with an enforcement marker)
# to count as restating the non-negotiable-methodology standard.
METHODOLOGY_QUORUM = 4
# how many lines either side of a signature line count as "immediate context"
# when looking for a citation of the standard's CLAUDE.md home.
CITATION_CONTEXT_LINES = 2

_CITATION_RE = re.compile(r"claude\.md", re.IGNORECASE)


def _signature_line_indices(lines: list[str], needles, fold_case: bool) -> list[int]:
    """Indices of the lines carrying any of `needles`. Pure.

    `fold_case=False` keeps the match literal — used for the naming-convention
    regex, which must match CLAUDE.md's exact pattern and nothing regex-shaped.
    """
    haystack = [ln.lower() for ln in lines] if fold_case else lines
    probes = [n.lower() for n in needles] if fold_case else list(needles)
    return [i for i, ln in enumerate(haystack) if any(p and p in ln for p in probes)]


def cites_claude_md(lines: list[str], indices: list[int]) -> bool:
    """True iff EVERY signature occurrence points at its CLAUDE.md home. Pure.

    Quoting a standard with attribution to CLAUDE.md is the behaviour the
    campaign asks for, so such an occurrence is not a restatement. The check is
    "every occurrence", not "any": a skill that cites once and then re-teaches
    the standard uncited elsewhere is still restating it.
    """
    if not indices:
        return False
    for i in indices:
        lo = max(0, i - CITATION_CONTEXT_LINES)
        hi = min(len(lines), i + CITATION_CONTEXT_LINES + 1)
        if not any(_CITATION_RE.search(ln) for ln in lines[lo:hi]):
            return False
    return True


def find_restatements(corpus_by_skill: dict, standards: dict) -> list[dict]:
    """Flag skills whose prose restates a CLAUDE.md standard.

    Returns findings ranked high-severity first. Each finding:
      { "skill", "standard", "severity", "evidence", "repoint_to" }
    Pure: operates on {skill_name: corpus_text} + a parsed-standards dict. The
    legitimate home skill of each standard is never flagged.
    """
    findings: list[dict] = []
    naming_regex = standards.get("naming_regex")
    frug = standards.get("frugality_phrases", [])
    methods = standards.get("methodologies", [])
    markers = standards.get("methodology_markers", [])
    ul_terms = standards.get("ubiquitous_terms", [])

    for name in sorted(corpus_by_skill):
        text = corpus_by_skill[name]
        low = text.lower()
        lines = text.splitlines()

        # 1. Naming-convention regex restated verbatim.
        #    LITERAL match against CLAUDE.md's own pattern — a regex that merely
        #    looks like a naming regex (a Terraform tenant-id validation, say) is
        #    a different rule and must not be flagged as restating this one.
        if naming_regex and name not in STANDARD_HOME_SKILLS["naming_regex"]:
            idx = _signature_line_indices(lines, [naming_regex], fold_case=False)
            if idx and not cites_claude_md(lines, idx):
                findings.append({
                    "skill": name,
                    "standard": "naming-convention regex",
                    "severity": "high",
                    "evidence": f"contains the literal regex `{naming_regex}`",
                    "repoint_to": "CLAUDE.md § Naming Conventions",
                })

        # 2. Frugality rules restated.
        if name not in STANDARD_HOME_SKILLS["frugality"]:
            hits = [p for p in frug if p in low]
            idx = _signature_line_indices(lines, hits, fold_case=True)
            if hits and not cites_claude_md(lines, idx):
                findings.append({
                    "skill": name,
                    "standard": "frugality / budget rules",
                    "severity": "high",
                    "evidence": "restates budget language: " + "; ".join(f'"{h}"' for h in hits),
                    "repoint_to": "CLAUDE.md § Budget and Frugality",
                })

        # 3. The five non-negotiable methodologies framed as mandatory.
        if name not in STANDARD_HOME_SKILLS["methodologies"]:
            present = [mth for mth in methods if mth and mth in low]
            marker_hit = any(mk in low for mk in markers)
            idx = _signature_line_indices(lines, present, fold_case=True)
            if len(present) >= METHODOLOGY_QUORUM and marker_hit and not cites_claude_md(lines, idx):
                findings.append({
                    "skill": name,
                    "standard": "non-negotiable methodologies",
                    "severity": "high",
                    "evidence": (
                        f"lists {len(present)}/5 mandatory methodologies "
                        f"({', '.join(present)}) with enforcement framing"
                    ),
                    "repoint_to": "CLAUDE.md § Non-Negotiable Methodology",
                })

        # 4. Ubiquitous Language glossary dumped into the skill.
        if name not in STANDARD_HOME_SKILLS["ubiquitous_language"]:
            present_terms = [t for t in ul_terms if t and t in low]
            idx = _signature_line_indices(lines, present_terms, fold_case=True)
            if len(present_terms) >= UBIQUITOUS_DUMP_THRESHOLD and not cites_claude_md(lines, idx):
                findings.append({
                    "skill": name,
                    "standard": "Ubiquitous Language glossary",
                    "severity": "medium",
                    "evidence": (
                        f"restates {len(present_terms)} canonical glossary terms "
                        f"(e.g. {', '.join(present_terms[:6])}...)"
                    ),
                    "repoint_to": "CLAUDE.md § Ubiquitous Language / skills/glossary-management",
                })

    sev_rank = {"high": 0, "medium": 1, "low": 2}
    findings.sort(key=lambda f: (sev_rank.get(f["severity"], 9), f["standard"], f["skill"]))
    return findings


# ---------------------------------------------------------------------------
# Report rendering
# ---------------------------------------------------------------------------

def _fence(text: str) -> str:
    fence = "```"
    while fence in text:
        fence += "`"
    return f"{fence}\n{text}\n{fence}"


def build_report(dup_clusters: list[dict], restatements: list[dict], skill_count: int) -> str:
    lines: list[str] = []
    lines.append("# Duplication & Restatement Report")
    lines.append("")
    lines.append(
        "Generated by `scripts/lint-duplication.py` (P1.8, #789). Report-only — the "
        "linter never fails the build. This snapshot is the **P4 de-duplication & "
        "repointing backlog**: each cluster below is a candidate for deletion + "
        "repointing to its canonical home (CLAUDE.md always-on standards, a "
        "cross-cutting skill, or `shared-references/`)."
    )
    lines.append("")
    lines.append(f"- Skills scanned: **{skill_count}**")
    lines.append(f"- Recurring near-identical blocks (>= {MIN_SKILLS_FOR_DUP} skills): **{len(dup_clusters)}**")
    lines.append(f"- CLAUDE.md-standard restatements: **{len(restatements)}**")
    lines.append("")

    lines.append("## 1. Recurring near-identical text blocks")
    lines.append("")
    lines.append(
        f"Blocks (window = {SHINGLE_WINDOW} normalized lines, merged) whose text "
        f"recurs across at least {MIN_SKILLS_FOR_DUP} skill corpora, ranked by how "
        "many skills carry them. Consolidate each into one home and repoint. "
        "The mandated artifact-frontmatter template "
        "(`name`/`version`/`phase`/`owner`/`created`, CLAUDE.md § Artifact "
        "Standards) is excluded during corpus assembly — its recurrence is "
        "compliance, not duplication."
    )
    lines.append("")
    if not dup_clusters:
        lines.append("_No cross-skill duplicated blocks found at the current thresholds._")
    else:
        for i, c in enumerate(dup_clusters, 1):
            lines.append(f"### D{i}. Shared by {c['num_skills']} skills ({c['num_lines']} lines)")
            lines.append("")
            lines.append("**Skills:** " + ", ".join(f"`{s}`" for s in c["skills"]))
            lines.append("")
            lines.append(_fence(c["text"]))
            lines.append("")
    lines.append("")

    lines.append("## 2. Restatements of a CLAUDE.md standard")
    lines.append("")
    lines.append(
        "Skills whose prose re-teaches a standard whose canonical home is "
        "CLAUDE.md. Per campaign decision #4, skills must **point to** these "
        "homes, never restate them — delete the restatement and repoint. A "
        "block that already cites `CLAUDE.md` within two lines of every "
        "occurrence is doing exactly that, and is not reported."
    )
    lines.append("")
    if not restatements:
        lines.append("_No CLAUDE.md-standard restatements found._")
    else:
        lines.append("| # | Skill | Standard restated | Severity | Evidence | Repoint to |")
        lines.append("|---|---|---|---|---|---|")
        for i, r in enumerate(restatements, 1):
            ev = r["evidence"].replace("|", "\\|")
            lines.append(
                f"| R{i} | `{r['skill']}` | {r['standard']} | {r['severity']} | "
                f"{ev} | {r['repoint_to']} |"
            )
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# main — the only filesystem-touching entry point. Always exits 0.
# ---------------------------------------------------------------------------

def main() -> int:
    skills = manifest.load_skills()
    # Read raw, then apply the corpus-assembly exclusions (mandated artifact
    # frontmatter) before any detector sees the text.
    corpus_by_skill = assemble_corpora({r["name"]: read_skill_corpus(r) for r in skills})

    dup_clusters = find_duplicate_blocks(corpus_by_skill)

    standards = load_claude_standards(CLAUDE_MD.read_text(encoding="utf-8")) if CLAUDE_MD.is_file() else {}
    restatements = find_restatements(corpus_by_skill, standards) if standards else []

    report = build_report(dup_clusters, restatements, len(skills))
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(report + "\n", encoding="utf-8")

    print(f"lint-duplication: scanned {len(skills)} skills")
    print(f"  recurring near-identical blocks (>= {MIN_SKILLS_FOR_DUP} skills): {len(dup_clusters)}")
    print(f"  CLAUDE.md-standard restatements: {len(restatements)}")
    print(f"  report written -> {REPORT_PATH.relative_to(REPO_ROOT)}")
    if dup_clusters:
        top = dup_clusters[0]
        print(f"  top block shared by {top['num_skills']} skills: {top['skills']}")
    return 0  # report-only: never fails the build.


if __name__ == "__main__":
    sys.exit(main())
