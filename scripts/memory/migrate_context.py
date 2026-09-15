#!/usr/bin/env python3
"""One-time migration: decompose sdlc-context.json's fast-growing log
sections (decisions[], open_questions[], build_checklist[], anti_patterns)
into individually addressable context nodes under sdlc://self/..., each
with an L0 abstract / L1 overview / L2 detail -- the same per-URI
decomposition OpenViking's own context model uses, applied to this
plugin's own project memory instead of one monolithic JSON blob every
command had to read in full.

Idempotent: safe to re-run after sdlc-context.json gains new entries --
existing self:// nodes are updated in place, not duplicated.

Leaves sdlc-context.json's relatively static sections (_meta, project,
working_agreements, methodology, tech_stack, first_product,
plugin_architecture, agents, skill_domains, commands, hooks, scripts)
untouched, and replaces the migrated sections with a short pointer note.
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import store
from common import ensure_config, find_repo_root, tree_root
from models import Embedder

MIGRATED_KEYS = ("decisions", "open_questions", "build_checklist", "anti_patterns")


def _write_sidecar(repo_root: Path, uri: str, content: str) -> str:
    scheme, _, rest = uri.partition("://")
    path = tree_root(repo_root) / rest
    path = path.with_suffix(".md") if not path.suffix else path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n")
    return str(path.relative_to(repo_root))


def _upsert_node(conn, embedder, repo_root, uri, parent_uri, abstract, overview, content, is_leaf, now_iso, context_type="memory"):
    content_path = _write_sidecar(repo_root, uri, content) if content else ""
    for level, text in ((0, abstract), (1, overview), (2, content[:3000])):
        store.upsert(
            conn, uri=uri, parent_uri=parent_uri, level=level, context_type=context_type,
            abstract=abstract, overview=overview, content=content, content_path=content_path,
            is_leaf=is_leaf, created_at=now_iso, updated_at=now_iso,
            embedding=embedder.embed(text or abstract),
        )


def migrate(repo_root: Path) -> dict[str, int]:
    ctx_path = repo_root / "sdlc-context.json"
    data = json.loads(ctx_path.read_text())
    conn = store.connect(repo_root)
    embedder = Embedder(repo_root)
    now_iso = datetime.now(timezone.utc).isoformat()
    counts = {k: 0 for k in MIGRATED_KEYS}

    _upsert_node(conn, embedder, repo_root, "sdlc://self", None,
                 "SDLC-Artifact-Factory's own project memory (decisions, open questions, build checklist).",
                 "This plugin's own engineering history, migrated out of sdlc-context.json into individually retrievable nodes.",
                 "", is_leaf=False, now_iso=now_iso, context_type="directory")

    # decisions[]
    _upsert_node(conn, embedder, repo_root, "sdlc://self/decisions", "sdlc://self",
                 "Architectural and process decisions made while building this plugin.",
                 "One node per decision (D-number), each with rationale and rejected alternatives.",
                 "", is_leaf=False, now_iso=now_iso, context_type="directory")
    for d in data.get("decisions", []):
        uri = f"sdlc://self/decisions/{d['id']}"
        abstract = d.get("decision", "")[:200]
        overview = f"{d.get('decision', '')} ({d.get('date', '')})"
        alts = "\n".join(f"- {a}" for a in d.get("alternatives_rejected", []))
        content = (
            f"# {d['id']}: {d.get('decision', '')}\n\n"
            f"**Date:** {d.get('date', '')}\n\n"
            f"**Rationale:** {d.get('rationale', '')}\n\n"
            + (f"**Alternatives rejected:**\n{alts}\n" if alts else "")
        )
        _upsert_node(conn, embedder, repo_root, uri, "sdlc://self/decisions", abstract, overview, content, True, now_iso)
        counts["decisions"] += 1

    # open_questions[]
    _upsert_node(conn, embedder, repo_root, "sdlc://self/open_questions", "sdlc://self",
                 "Open and resolved questions raised during development of this plugin.",
                 "One node per question (Q-number), with status and the context it was raised in.",
                 "", is_leaf=False, now_iso=now_iso, context_type="directory")
    for q in data.get("open_questions", []):
        uri = f"sdlc://self/open_questions/{q['id']}"
        abstract = q.get("question", "")[:200]
        overview = f"Status: {q.get('status', 'open')}"
        content = (
            f"# {q['id']}\n\n**Date:** {q.get('date', '')}\n\n**Question:** {q.get('question', '')}\n\n"
            f"**Status:** {q.get('status', '')}\n\n**Raised during:** {q.get('raised_during', '')}\n"
        )
        _upsert_node(conn, embedder, repo_root, uri, "sdlc://self/open_questions", abstract, overview, content, True, now_iso)
        counts["open_questions"] += 1

    # build_checklist[]
    _upsert_node(conn, embedder, repo_root, "sdlc://self/build_checklist", "sdlc://self",
                 "Chunk-by-chunk build checklist for this plugin.",
                 "One node per chunk, with status, completion date, and deliverables.",
                 "", is_leaf=False, now_iso=now_iso, context_type="directory")
    for c in data.get("build_checklist", []):
        uri = f"sdlc://self/build_checklist/chunk-{c['chunk']:03d}" if isinstance(c.get("chunk"), int) else f"sdlc://self/build_checklist/{c.get('chunk')}"
        abstract = f"Chunk {c.get('chunk')}: {c.get('title', '')}"[:200]
        overview = f"{abstract} -- {c.get('status', '')}"
        deliverables = "\n".join(f"- {x}" for x in c.get("deliverables", []))
        content = (
            f"# Chunk {c.get('chunk')}: {c.get('title', '')}\n\n**Status:** {c.get('status', '')}\n\n"
            f"**Completed:** {c.get('date_completed', '')}\n\n**Deliverables:**\n{deliverables}\n"
        )
        _upsert_node(conn, embedder, repo_root, uri, "sdlc://self/build_checklist", abstract, overview, content, True, now_iso)
        counts["build_checklist"] += 1

    # anti_patterns -- short flat list, kept as one aggregated node.
    patterns = data.get("anti_patterns", [])
    if patterns:
        content = "\n".join(f"- {p}" for p in patterns)
        _upsert_node(
            conn, embedder, repo_root, "sdlc://self/anti_patterns", "sdlc://self",
            "Known anti-patterns to avoid in this plugin's own components.",
            f"{len(patterns)} anti-patterns catalogued.", content, True, now_iso,
        )
        counts["anti_patterns"] = len(patterns)

    remaining = {k: v for k, v in data.items() if k not in MIGRATED_KEYS}
    remaining["_migrated_to_memory_tree"] = {
        "migrated_at": now_iso,
        "note": (
            "decisions, open_questions, build_checklist, and anti_patterns now live under "
            "sdlc://self/... in .sdlc-memory/ -- query them with "
            "scripts/memory/retrieve.py rather than reading this file in full. "
            "Re-run scripts/memory/migrate_context.py after adding entries here to re-sync."
        ),
        "counts": counts,
    }
    ctx_path.write_text(json.dumps(remaining, indent=2) + "\n")
    return counts


def main(argv: list[str]) -> int:
    repo_root = find_repo_root()
    ensure_config(repo_root)
    if not (repo_root / "sdlc-context.json").exists():
        print("no sdlc-context.json found at repo root -- nothing to migrate", file=sys.stderr)
        return 1
    counts = migrate(repo_root)
    print(json.dumps(counts, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
