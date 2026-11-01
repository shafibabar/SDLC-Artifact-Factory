#!/usr/bin/env python3
"""check-user-personas.py — mechanical checks on a user-personas artifact.

Owned by the user-persona skill. Deterministic checks only; it makes no
judgement about whether a persona is a real pattern or the right primary.
The agent applying the skill fixes what it reports.

Usage:
    check-user-personas.py <user-personas.md>

Checks:
  1. Frontmatter has name, version, phase, owner, created, summary, profile,
     grounding and review-by; phase is "ideate".
  2. A persona block is any level-2 section with a "**Type:**" line. Each has
     exactly one type from the six (Primary, Secondary, Supplemental,
     Customer, Served, Negative), judged by the first type word on the line.
  3. At least one Primary; each Primary names an Interface; no two Primaries
     share one.
  4. Each persona block has a Grounding line starting PROTO, MIXED or
     RESEARCH. A PROTO line names its author ("written by"), its inputs
     ("from") and says "no user research".
  5. RESEARCH (persona or frontmatter) is an error when frontmatter says
     "evidence: none".
  6. Primary, Secondary and Customer personas labelled PROTO or MIXED have a
     "Validation questions" heading with at least one question mark under it.
  7. No field labelled Age, Gender, Hometown, Hobbies, Photo or Marital status.
  8. Outside the lean profile, a persona holding a job story ("When …, I want
     …") gets a warning: job stories live in jtbd-analysis.

Output: one line per finding, "ERROR: ..." or "WARNING: ...", then a summary.
Exit codes: 0 no errors (warnings allowed), 1 errors found, 2 unreadable input.
"""
import re
import sys

TYPES = ["primary", "secondary", "supplemental", "customer", "served", "negative"]
REQUIRED_FM = ["name", "version", "phase", "owner", "created", "summary",
               "profile", "grounding", "review-by"]
BANNED = re.compile(
    r"^\s*[-*]?\s*\*\*(age|gender|hometown|hobbies|hobby|photo|marital status)\s*:?\*\*",
    re.I | re.M)
JOB_STORY = re.compile(r"\bwhen\b[^.\n]{3,}?,\s*i want\b", re.I)
NEEDS_QUESTIONS = {"primary", "secondary", "customer"}


def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, text
    fm = {}
    for ln in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_-]+):\s*(.*)$", ln)
        if km:
            fm[km.group(1).lower()] = km.group(2).strip()
    return fm, text[m.end():]


def sections(body):
    out, head, buf = [], None, []
    for ln in body.splitlines():
        if ln.startswith("## "):
            if head is not None:
                out.append((head, "\n".join(buf)))
            head, buf = ln[3:].strip(), []
        else:
            buf.append(ln)
    if head is not None:
        out.append((head, "\n".join(buf)))
    return out


def field(block, name):
    m = re.search(r"\*\*" + name + r":\*\*\s*(.*)", block, re.I)
    return m.group(1).strip() if m else None


def persona_type(type_line):
    words = re.findall(r"[a-z]+", type_line.lower())
    for w in words:
        if w in TYPES:
            return w
    return None


def interface(type_line, block):
    m = re.search(r"\*\*Interface:\*\*\s*([^·\n]+)", type_line + "\n" + block, re.I)
    return m.group(1).strip().strip("`*").lower() if m else None


def check(text):
    errors, warnings = [], []
    fm, body = frontmatter(text)
    if fm is None:
        errors.append("no frontmatter block")
        fm = {}
    else:
        for k in REQUIRED_FM:
            if not fm.get(k):
                errors.append(f"frontmatter: missing '{k}'")
        if fm.get("phase") and fm["phase"].lower() != "ideate":
            errors.append(f"frontmatter: phase is '{fm['phase']}', personas are written in Ideate (phase: ideate)")
    profile = (fm.get("profile") or "").lower()
    no_evidence = (fm.get("evidence") or "").lower().startswith("none")
    if no_evidence and "research" in (fm.get("grounding") or "").lower():
        errors.append("frontmatter: grounding 'research' with 'evidence: none' — only interviews the user held can ground a persona")

    personas = [(h, b) for h, b in sections(body) if re.search(r"\*\*Type:\*\*", b)]
    if not personas:
        errors.append("no persona blocks (a level-2 section with a '**Type:**' line)")
    primaries = {}
    for head, block in personas:
        tline = field(block, "Type") or ""
        ptype = persona_type(tline)
        if ptype is None:
            errors.append(f"persona '{head}': Type '{tline}' is not one of {', '.join(t.title() for t in TYPES)}")
        if ptype == "primary":
            iface = interface(tline, block)
            if not iface:
                errors.append(f"persona '{head}': Primary with no Interface named")
            elif iface in primaries:
                errors.append(f"persona '{head}': shares the Primary interface '{iface}' with '{primaries[iface]}' — one primary per interface")
            else:
                primaries[iface] = head

        grounding = field(block, "Grounding")
        label = None
        if not grounding:
            errors.append(f"persona '{head}': no Grounding line")
        else:
            g = grounding.strip("`").upper()
            label = next((x for x in ("PROTO", "MIXED", "RESEARCH") if g.startswith(x)), None)
            if label is None:
                errors.append(f"persona '{head}': Grounding must start PROTO, MIXED or RESEARCH")
            elif label == "PROTO":
                gl = grounding.lower()
                missing = [p for p, ok in (("written by", "written by" in gl),
                                           ("from <inputs>", re.search(r"\bfrom\b", gl)),
                                           ("no user research", "no user research" in gl)) if not ok]
                if missing:
                    errors.append(f"persona '{head}': PROTO label lacks provenance ({', '.join(missing)})")
            elif label == "RESEARCH" and no_evidence:
                errors.append(f"persona '{head}': RESEARCH label with 'evidence: none' — the agent may never apply RESEARCH on its own authority")

        if label in ("PROTO", "MIXED") and ptype in NEEDS_QUESTIONS:
            m = re.search(r"^#+\s*Validation questions\s*$(.*?)(?=^#{1,3}\s|\Z)", block, re.I | re.M | re.S)
            if not m or "?" not in m.group(1):
                errors.append(f"persona '{head}': {label} persona has no validation questions")

        for bm in BANNED.finditer(block):
            errors.append(f"persona '{head}': decorative field '{bm.group(1)}' — leave it out")

        if profile and profile != "lean" and JOB_STORY.search(block):
            warnings.append(f"persona '{head}': holds a job story at the {profile} profile — keep one job statement; job stories live in jtbd-analysis")

    if personas and not any(persona_type(field(b, "Type") or "") == "primary" for _, b in personas):
        errors.append("no Primary persona — designate one primary per interface")
    return errors, warnings


def main():
    if len(sys.argv) != 2:
        print("usage: check-user-personas.py <user-personas.md>", file=sys.stderr)
        return 2
    try:
        text = open(sys.argv[1], encoding="utf-8").read()
    except OSError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    errors, warnings = check(text)
    for e in errors:
        print(f"ERROR: {e}")
    for w in warnings:
        print(f"WARNING: {w}")
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
