#!/usr/bin/env python3
"""
scripts/arch/manifest.py — the shared, dependency-light frontmatter-parsing
foundation for the Architecture Review campaign (P1.1, closes #781).

This module is the single source of truth that the P1 consistency linters and
the P3 derived catalog import. It reads the plugin's own component files
(skills, agents, commands, hooks) and returns plain, deterministic Python
records built from their authored frontmatter PLUS filesystem-derived facts
(does the skill own a non-empty references/ dir? does a contract test exist?).

Design constraints (per ARCHITECTURE-REVIEW-CAMPAIGN.md §3 — Descriptors are
data, read never run):
  * PURE READ. Nothing here writes, mutates, or shells out. Import it freely.
  * DETERMINISTIC. Every list is sorted; repeated calls give identical output.
  * DEPENDENCY-LIGHT. stdlib only. PyYAML is used *if importable*; otherwise a
    minimal, self-contained frontmatter parser handles the subset of YAML the
    plugin's frontmatter actually uses:
        - `key: value`               (scalars, optionally quoted)
        - `key: >` / `key: |`        (block scalars — folded/joined to one line)
        - `key: [a, b, c]`           (inline flow lists)
        - `key:` then `  - item`     (block lists)
    Set the env var MANIFEST_FORCE_MINIMAL=1 to force the fallback parser even
    when PyYAML is installed (the test exercises both paths this way).

Stable public API (imported by linters + catalog — do not break):
    load_skills()          -> list[dict]   (sorted by name)
    load_agents()          -> list[dict]   (sorted by name)
    load_commands()        -> list[dict]   (sorted by name)
    load_hooks()           -> list[dict]   (flattened handler records)
    all_component_names()  -> list[str]    (skills + agents + commands, sorted)
    resolve(name)          -> dict | None  ({"kind", "name", "record"})

Record shapes are documented at each loader below.
"""

from __future__ import annotations

import datetime as _dt
import json
import os
import re
from pathlib import Path

# scripts/arch/manifest.py -> parents[2] is the repo root.
REPO_ROOT = Path(__file__).resolve().parents[2]

SKILLS_DIR = REPO_ROOT / "skills"
AGENTS_DIR = REPO_ROOT / "agents"
COMMANDS_DIR = REPO_ROOT / "commands"
HOOKS_FILE = REPO_ROOT / "hooks" / "hooks.json"

TESTS_SKILLS_DIR = REPO_ROOT / "tests" / "skills"
TESTS_AGENTS_DIR = REPO_ROOT / "tests" / "agents"
TESTS_COMMANDS_DIR = REPO_ROOT / "tests" / "commands"


# ---------------------------------------------------------------------------
# Frontmatter parsing
# ---------------------------------------------------------------------------

_FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", re.DOTALL)


def _force_minimal() -> bool:
    return os.environ.get("MANIFEST_FORCE_MINIMAL", "") not in ("", "0", "false", "False")


try:  # PyYAML is preferred when present and not force-disabled.
    import yaml as _yaml  # type: ignore
except Exception:  # pragma: no cover - environment dependent
    _yaml = None


def extract_frontmatter_block(text: str) -> str | None:
    """Return the raw text between the first two '---' fences, or None."""
    m = _FM_RE.match(text.lstrip("﻿"))
    if not m:
        return None
    return m.group(1)


def _coerce_scalar(value: str):
    """Turn a raw scalar string into bool/None where obvious, else stripped str."""
    v = value.strip()
    if (len(v) >= 2) and ((v[0] == v[-1] == '"') or (v[0] == v[-1] == "'")):
        return v[1:-1]
    low = v.lower()
    if low in ("true", "yes"):
        return True
    if low in ("false", "no"):
        return False
    if low in ("null", "~", ""):
        return None
    return v


def _minimal_parse(fm_text: str) -> dict:
    """A small, dependency-free parser for the frontmatter subset used here."""
    data: dict = {}
    lines = fm_text.splitlines()
    i, n = 0, len(lines)
    key_re = re.compile(r"^([A-Za-z0-9_-]+):(.*)$")

    while i < n:
        line = lines[i]
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        # Only top-level (unindented) keys start a field.
        if line[:1] in (" ", "\t"):
            i += 1
            continue
        m = key_re.match(line)
        if not m:
            i += 1
            continue
        key = m.group(1)
        rest = m.group(2).strip()

        # Block scalar (folded '>' or literal '|', with optional chomp indicator).
        if rest and rest[0] in (">", "|") and rest.rstrip() in (
            ">", "|", ">-", "|-", ">+", "|+",
        ):
            i += 1
            chunk = []
            while i < n and (lines[i].strip() == "" or lines[i][:1] in (" ", "\t")):
                chunk.append(lines[i].strip())
                i += 1
            data[key] = " ".join(c for c in chunk if c)
            continue

        # Inline flow list: [a, b, c] (elements may be quoted).
        if rest.startswith("[") and rest.endswith("]"):
            inner = rest[1:-1].strip()
            data[key] = [_coerce_scalar(x) for x in inner.split(",") if x.strip()] if inner else []
            i += 1
            continue

        # Empty value: either a block list (following '  - item') or an empty field.
        if rest == "":
            i += 1
            items = []
            while i < n and lines[i][:1] in (" ", "\t") and lines[i].lstrip().startswith("- "):
                items.append(_coerce_scalar(lines[i].lstrip()[2:]))
                i += 1
            data[key] = items if items else None
            continue

        # Plain scalar.
        data[key] = _coerce_scalar(rest)
        i += 1

    return data


def parse_frontmatter(text: str) -> dict:
    """Parse a component file's leading frontmatter into a dict.

    Uses PyYAML when available (and not force-disabled), else the minimal parser.
    Always returns a dict (empty if there is no frontmatter block).
    """
    fm = extract_frontmatter_block(text)
    if fm is None:
        return {}
    if _yaml is not None and not _force_minimal():
        try:
            loaded = _yaml.safe_load(fm)
            if isinstance(loaded, dict):
                return {k: _normalize_yaml_value(v) for k, v in loaded.items()}
        except Exception:
            pass  # fall through to the minimal parser on any YAML error
    return _minimal_parse(fm)


def _normalize_yaml_value(v):
    """Coerce PyYAML's rich types down to the JSON-friendly scalars the minimal
    parser produces, so both parser paths yield byte-identical records.

    * folded/multiline strings -> single space-joined line
    * date / datetime (PyYAML auto-parses `created: 2026-06-25`) -> ISO string
    * lists -> element-wise normalized
    """
    if isinstance(v, (_dt.date, _dt.datetime)):
        return v.isoformat()
    if isinstance(v, str):
        return " ".join(v.split())
    if isinstance(v, list):
        return [_normalize_yaml_value(x) for x in v]
    return v


# ---------------------------------------------------------------------------
# Filesystem-derived helpers
# ---------------------------------------------------------------------------

def _dir_nonempty(path: Path) -> bool:
    return path.is_dir() and any(path.iterdir())


def _as_list(value) -> list:
    if value is None:
        return []
    if isinstance(value, list):
        return list(value)
    return [value]


def _opt_list(value):
    """Optional list field: None when absent, else a list."""
    if value is None:
        return None
    return _as_list(value)


# Every frontmatter key each loader below projects onto a named record field.
# Anything a component authors OUTSIDE these sets is preserved verbatim in the
# record's `extra` dict rather than silently discarded — that is what lets
# lint-manifests.py actually enforce `additionalProperties: false`. Before this
# existed, a typo'd key (`domainn:`) never reached the record, so it never
# reached the validator and the gate reported PASS.
_SKILL_FM_KEYS = frozenset({
    "name", "description", "version", "phase", "owner", "created", "tags",
    "related", "produces", "domain", "status",
})
_AGENT_FM_KEYS = frozenset({
    "name", "description", "role", "version", "phase", "owner", "created",
    "inputs", "outputs", "skills", "tools", "tags",
    "produces", "domain", "status",
})
# NOTE: `capability` is deliberately absent above. Charter decision #2 makes it a
# DERIVED view, never hand-authored, so no loader projects it; if an agent ever
# authors it, it surfaces through `extra` (and the schema, which permits it)
# instead of being silently swallowed.
_COMMAND_FM_KEYS = frozenset({
    "description", "argument-hint", "allowed-tools", "model",
    "disable-model-invocation",
})


def _extra(fm: dict, known: frozenset) -> dict:
    """Authored frontmatter keys the record does not project, key-sorted.

    Deterministic (sorted) and pure. Empty dict when the component authors
    nothing unexpected.
    """
    return {k: fm[k] for k in sorted(fm) if k not in known}


# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

def load_skills() -> list[dict]:
    """One record per skills/<name>/SKILL.md, sorted by name.

    Record:
      name, description, version, phase, owner, created, tags,
      related (list|None), produces (list|None), domain (str|None),
      status (str|None),
      extra (dict — any authored frontmatter key not named above),
      has_references, has_assets, has_scripts, has_contract_test  (bool, derived)
    """
    records = []
    if not SKILLS_DIR.is_dir():
        return records
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        skill_md = skill_dir / "SKILL.md"
        if not (skill_dir.is_dir() and skill_md.is_file()):
            continue
        fm = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
        name = fm.get("name") or skill_dir.name
        records.append({
            "name": name,
            "description": fm.get("description"),
            "version": fm.get("version"),
            "phase": fm.get("phase"),
            "owner": fm.get("owner"),
            "created": fm.get("created"),
            "tags": _as_list(fm.get("tags")),
            "related": _opt_list(fm.get("related")),
            "produces": _opt_list(fm.get("produces")),
            "domain": fm.get("domain"),
            "status": fm.get("status"),
            "extra": _extra(fm, _SKILL_FM_KEYS),
            "has_references": _dir_nonempty(skill_dir / "references"),
            "has_assets": _dir_nonempty(skill_dir / "assets"),
            "has_scripts": _dir_nonempty(skill_dir / "scripts"),
            "has_contract_test": (TESTS_SKILLS_DIR / f"{name}.contract.sh").is_file(),
            "dir": str(skill_dir.relative_to(REPO_ROOT)),
        })
    records.sort(key=lambda r: r["name"])
    return records


# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------

def load_agents() -> list[dict]:
    """One record per agents/<name>.md, sorted by name.

    Record:
      name, description, role, version, phase, owner, created,
      inputs, outputs, skills, tools, tags  (lists),
      produces (list|None), domain (str|None), status (str|None),
      extra (dict — any authored frontmatter key not named above),
      has_acceptance_test, has_contract_test  (bool, derived)

    produces/domain/status mirror the skill record exactly: the keys are ALWAYS
    present (None when the agent has not authored them yet), and `produces` is
    normalized scalar-or-list -> list, so downstream tooling never has to branch
    on which loader a record came from.
    """
    records = []
    if not AGENTS_DIR.is_dir():
        return records
    for agent_md in sorted(AGENTS_DIR.glob("*.md")):
        fm = parse_frontmatter(agent_md.read_text(encoding="utf-8"))
        name = fm.get("name") or agent_md.stem
        records.append({
            "name": name,
            "description": fm.get("description"),
            "role": fm.get("role"),
            "version": fm.get("version"),
            "phase": fm.get("phase"),
            "owner": fm.get("owner"),
            "created": fm.get("created"),
            "inputs": _as_list(fm.get("inputs")),
            "outputs": _as_list(fm.get("outputs")),
            "skills": _as_list(fm.get("skills")),
            "tools": _as_list(fm.get("tools")),
            "tags": _as_list(fm.get("tags")),
            "produces": _opt_list(fm.get("produces")),
            "domain": fm.get("domain"),
            "status": fm.get("status"),
            "extra": _extra(fm, _AGENT_FM_KEYS),
            "has_acceptance_test": (TESTS_AGENTS_DIR / f"{name}.acceptance.sh").is_file(),
            "has_contract_test": (TESTS_AGENTS_DIR / f"{name}.contract.sh").is_file(),
            "file": str(agent_md.relative_to(REPO_ROOT)),
        })
    records.sort(key=lambda r: r["name"])
    return records


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def load_commands() -> list[dict]:
    """One record per commands/<name>.md, sorted by name.

    Command frontmatter uses the platform's own (hyphenated) keys; they are
    normalized to snake_case here.

    Record:
      name, description,
      argument_hint (str|None), allowed_tools (list|None), model (str|None),
      disable_model_invocation (bool|None),
      extra (dict — any authored frontmatter key not named above, raw keys),
      has_test  (bool, derived — tests/commands/<name>.test.sh)
    """
    records = []
    if not COMMANDS_DIR.is_dir():
        return records
    for cmd_md in sorted(COMMANDS_DIR.glob("*.md")):
        fm = parse_frontmatter(cmd_md.read_text(encoding="utf-8"))
        name = cmd_md.stem
        allowed = fm.get("allowed-tools")
        records.append({
            "name": name,
            "description": fm.get("description"),
            "argument_hint": fm.get("argument-hint"),
            "allowed_tools": _opt_list(allowed),
            "model": fm.get("model"),
            "disable_model_invocation": fm.get("disable-model-invocation"),
            "extra": _extra(fm, _COMMAND_FM_KEYS),
            "has_test": (TESTS_COMMANDS_DIR / f"{name}.test.sh").is_file(),
            "file": str(cmd_md.relative_to(REPO_ROOT)),
        })
    records.sort(key=lambda r: r["name"])
    return records


# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------

def load_hooks() -> list[dict]:
    """Flatten hooks/hooks.json into one record per bound handler.

    hooks.json nests: event -> [ {matcher, hooks:[handler,...]}, ... ].
    Each returned record:
      event, matcher, type ('command'|'prompt'|'agent'),
      command (str|None), script (str|None — basename of a command handler),
      timeout (int|None)
    Records are returned in a deterministic order (event, matcher, index).
    """
    records = []
    if not HOOKS_FILE.is_file():
        return records
    data = json.loads(HOOKS_FILE.read_text(encoding="utf-8"))
    hooks = data.get("hooks", {})
    for event in sorted(hooks.keys()):
        groups = hooks[event]
        if not isinstance(groups, list):
            continue
        for group in groups:
            matcher = group.get("matcher")
            for idx, handler in enumerate(group.get("hooks", [])):
                command = handler.get("command")
                script = command.rsplit("/", 1)[-1] if command else None
                records.append({
                    "event": event,
                    "matcher": matcher,
                    "type": handler.get("type"),
                    "command": command,
                    "script": script,
                    "timeout": handler.get("timeout"),
                    "order": idx,
                })
    return records


# ---------------------------------------------------------------------------
# Cross-cutting lookups
# ---------------------------------------------------------------------------

def all_component_names() -> list[str]:
    """Sorted, de-duplicated names across skills, agents and commands."""
    names = set()
    names.update(r["name"] for r in load_skills())
    names.update(r["name"] for r in load_agents())
    names.update(r["name"] for r in load_commands())
    return sorted(names)


def resolve(name: str):
    """Return {'kind', 'name', 'record'} for a component name, or None.

    'kind' is one of 'skill', 'agent', 'command'. Skills are searched first,
    then agents, then commands (names are unique across the plugin in practice).
    """
    for kind, loader in (("skill", load_skills), ("agent", load_agents), ("command", load_commands)):
        for rec in loader():
            if rec["name"] == name:
                return {"kind": kind, "name": name, "record": rec}
    return None


# ---------------------------------------------------------------------------
# CLI: a quick, human-readable inventory (read-only).
# ---------------------------------------------------------------------------

def _summary() -> dict:
    return {
        "skills": len(load_skills()),
        "agents": len(load_agents()),
        "commands": len(load_commands()),
        "hook_handlers": len(load_hooks()),
        "component_names": len(all_component_names()),
    }


if __name__ == "__main__":
    print(json.dumps(_summary(), indent=2))
