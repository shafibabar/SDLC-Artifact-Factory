#!/usr/bin/env python3
"""Ingest one or more files into the SDLC memory context tree.

Mirrors OpenViking's write-time vectorization
(openviking/core/directories.py's `_ensure_directory_l0_l1_vectors`): every
node in the tree gets an L0 abstract, L1 overview, L2 detail, each embedded
and indexed. Called automatically from scripts/post-artifact-created.sh on
every artifact write, and can be run with --all for a full (re)index.
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

import store
from common import ensure_config, find_repo_root, first_paragraph, parse_frontmatter, tree_root
from models import Embedder

ARTIFACT_RE = re.compile(r"^(?:.*/)?artifacts/([a-z0-9-]+)/([a-z0-9-]+)/(.+)$")
RESEARCH_RE = re.compile(r"^(?:.*/)?research/([^/]+)/(.+)$")
SKILL_RE = re.compile(r"^(?:.*/)?skills/([a-z0-9-]+)/SKILL\.md$")

DIR_ABSTRACT_DEFAULTS = {
    "product": "Artifacts and decisions for product {name}.",
    "product-phase": "{phase} phase artifacts for product {product}.",
    "research": "Research notes on {name}.",
    "skills-root": "Reusable agent skills.",
    "research-root": "Research corpus, organized by topic.",
    "product-root": "All in-flight and delivered products.",
}


def classify(repo_root: Path, abs_path: Path) -> Optional[dict[str, Any]]:
    rel = abs_path.relative_to(repo_root).as_posix()
    if (m := ARTIFACT_RE.match(rel)):
        product, phase, tail = m.groups()
        stem = tail[:-3] if tail.endswith(".md") else tail
        uri = f"sdlc://product/{product}/{phase}/{stem}"
        parents = [
            ("sdlc://product", "product-root", {}),
            (f"sdlc://product/{product}", "product", {"name": product}),
            (f"sdlc://product/{product}/{phase}", "product-phase", {"product": product, "phase": phase}),
        ]
        return {"uri": uri, "context_type": "memory", "parents": parents}
    if (m := RESEARCH_RE.match(rel)):
        topic, tail = m.groups()
        stem = tail[:-3] if tail.endswith(".md") else tail
        uri = f"sdlc://research/{topic}/{stem}"
        parents = [
            ("sdlc://research", "research-root", {}),
            (f"sdlc://research/{topic}", "research", {"name": topic}),
        ]
        return {"uri": uri, "context_type": "resource", "parents": parents}
    if (m := SKILL_RE.match(rel)):
        name = m.group(1)
        uri = f"sdlc://skills/{name}"
        parents = [("sdlc://skills", "skills-root", {})]
        return {"uri": uri, "context_type": "skill", "parents": parents}
    return None


def _default_abstract(kind: str, **kwargs) -> str:
    return DIR_ABSTRACT_DEFAULTS.get(kind, "{name}").format(**kwargs)


def sidecar_dir(repo_root: Path, uri: str) -> Path:
    scheme, _, rest = uri.partition("://")
    return tree_root(repo_root) / rest


def ensure_directory_node(conn, embedder: Embedder, repo_root: Path, uri: str, parent_uri: Optional[str], kind: str, kwargs: dict, now_iso: str) -> None:
    existing = store.get_by_uri(conn, uri, level=0)
    if existing:
        return
    sidecar = sidecar_dir(repo_root, uri)
    sidecar.mkdir(parents=True, exist_ok=True)
    abstract_path = sidecar / ".abstract.md"
    overview_path = sidecar / ".overview.md"
    abstract = abstract_path.read_text().strip() if abstract_path.exists() else _default_abstract(kind, **kwargs)
    overview = overview_path.read_text().strip() if overview_path.exists() else abstract
    if not abstract_path.exists():
        abstract_path.write_text(abstract + "\n")
    if not overview_path.exists():
        overview_path.write_text(overview + "\n")

    for level, text in ((0, abstract), (1, overview)):
        store.upsert(
            conn, uri=uri, parent_uri=parent_uri, level=level, context_type="directory",
            abstract=abstract, overview=overview, content="", content_path=str(sidecar),
            is_leaf=False, created_at=now_iso, updated_at=now_iso,
            embedding=embedder.embed(text),
        )


def ensure_ancestors(conn, embedder: Embedder, repo_root: Path, parents: list[tuple[str, str, dict]], now_iso: str) -> str:
    prev_uri: Optional[str] = None
    for uri, kind, kwargs in parents:
        ensure_directory_node(conn, embedder, repo_root, uri, prev_uri, kind, kwargs, now_iso)
        prev_uri = uri
    return prev_uri  # type: ignore[return-value]


def build_texts(rel_path: str, raw_text: str) -> tuple[str, str, str]:
    """Returns (abstract, overview, content) for a leaf file."""
    if rel_path.endswith("SKILL.md"):
        fields, body = parse_frontmatter(raw_text)
        description = fields.get("description", "").strip()
        overview = description or first_paragraph(body)
        abstract = (description.split(". ")[0] if description else first_paragraph(body, 120))[:200]
        return abstract, overview, body

    fields, body = parse_frontmatter(raw_text)
    if fields:
        abstract = fields.get("summary", "").strip()
        overview = fields.get("overview", "").strip() or first_paragraph(body)
        if not abstract:
            abstract = first_paragraph(body, 140)
        return abstract, overview, body

    # Plain markdown (research/) -- no frontmatter.
    lines = raw_text.strip().splitlines()
    heading = next((l.lstrip("#").strip() for l in lines if l.strip().startswith("#")), "")
    abstract = heading or first_paragraph(raw_text, 140)
    overview = first_paragraph(raw_text)
    return abstract, overview, raw_text


def ingest_file(conn, embedder: Embedder, repo_root: Path, path: Path) -> Optional[str]:
    info = classify(repo_root, path)
    if info is None:
        return None
    now_iso = datetime.now(timezone.utc).isoformat()
    parent_uri = ensure_ancestors(conn, embedder, repo_root, info["parents"], now_iso)

    raw_text = path.read_text(errors="replace")
    rel_path = path.relative_to(repo_root).as_posix()
    abstract, overview, content = build_texts(rel_path, raw_text)
    content_for_embedding = content[:3000]

    uri = info["uri"]
    for level, text in ((0, abstract), (1, overview), (2, content_for_embedding)):
        store.upsert(
            conn, uri=uri, parent_uri=parent_uri, level=level, context_type=info["context_type"],
            abstract=abstract, overview=overview, content=content, content_path=rel_path,
            is_leaf=True, created_at=now_iso, updated_at=now_iso,
            embedding=embedder.embed(text or abstract),
        )
    return uri


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Ingest files into the SDLC memory tree")
    parser.add_argument("paths", nargs="*", help="File paths to ingest")
    parser.add_argument("--all", action="store_true", help="Reindex artifacts/, research/, skills/")
    args = parser.parse_args(argv)

    repo_root = find_repo_root()
    ensure_config(repo_root)
    conn = store.connect(repo_root)
    embedder = Embedder(repo_root)

    targets: list[Path] = []
    if args.all:
        for pattern in ("artifacts/**/*.md", "research/**/*.md", "skills/*/SKILL.md"):
            targets.extend(repo_root.glob(pattern))
    for p in args.paths:
        pp = Path(p)
        targets.append(pp if pp.is_absolute() else repo_root / pp)

    ingested = 0
    for path in targets:
        if not path.exists() or not path.is_file():
            continue
        uri = ingest_file(conn, embedder, repo_root, path)
        if uri:
            ingested += 1
            print(f"ingested {path} -> {uri}")
    print(f"done: {ingested} file(s) indexed (embedder backend: {embedder.backend})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
