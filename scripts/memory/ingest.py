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
COMPLIANCE_RE = re.compile(r"^(?:.*/)?compliance/(?:([^/]+)/)?(.+)\.md$")
GLOSSARY_RE = re.compile(r"^(?:.*/)?glossary/(.+)\.md$")
ADR_RE = re.compile(r"^(?:.*/)?decisions/adr/(.+)\.md$")
CONTEXT_JSON_RE = re.compile(r"^sdlc-context\.json$")
# Project memory nodes: decisions, open questions, build checklist, written by
# /sdlc-start, agents, or migrate_context.py. Leaf names never start with "."
# (that is where directory nodes keep their .abstract.md/.overview.md sidecars).
SELF_RE = re.compile(r"^\.sdlc-memory/tree/self/([a-z_]+)/([^/.][^/]*)\.md$")

DIR_ABSTRACT_DEFAULTS = {
    "product": "Artifacts and decisions for product {name}.",
    "product-phase": "{phase} phase artifacts for product {product}.",
    "research": "Research notes on {name}.",
    "skills-root": "Reusable agent skills.",
    "research-root": "Research corpus, organized by topic.",
    "product-root": "All in-flight and delivered products.",
    "compliance-root": "Compliance source materials, indexed by framework.",
    "compliance-framework": "{name} compliance source materials and provenance notes.",
    "glossary-root": "Ubiquitous Language glossary.",
    "adr-root": "Architecture Decision Records.",
    "self-root": "Project memory for this repository: decisions, open questions and progress.",
    "self-collection": "Project {name} recorded for this repository.",
}


def classify(repo_root: Path, abs_path: Path) -> Optional[dict[str, Any]]:
    try:
        rel = abs_path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return None  # outside this repo -- not ours to index
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
    if (m := COMPLIANCE_RE.match(rel)):
        framework, stem = m.groups()
        if framework is None:
            # compliance/README.md itself -- the top-level index, no framework parent.
            uri = f"sdlc://compliance/{stem}"
            parents = [("sdlc://compliance", "compliance-root", {})]
        else:
            uri = f"sdlc://compliance/{framework}/{stem}"
            parents = [
                ("sdlc://compliance", "compliance-root", {}),
                (f"sdlc://compliance/{framework}", "compliance-framework", {"name": framework}),
            ]
        return {"uri": uri, "context_type": "resource", "parents": parents}
    if (m := GLOSSARY_RE.match(rel)):
        stem = m.group(1)
        uri = f"sdlc://glossary/{stem}"
        parents = [("sdlc://glossary", "glossary-root", {})]
        return {"uri": uri, "context_type": "resource", "parents": parents}
    if (m := ADR_RE.match(rel)):
        stem = m.group(1)
        uri = f"sdlc://adr/{stem}"
        parents = [("sdlc://adr", "adr-root", {})]
        return {"uri": uri, "context_type": "resource", "parents": parents}
    if (m := SELF_RE.match(rel)):
        collection, stem = m.groups()
        uri = f"sdlc://self/{collection}/{stem}"
        parents = [
            ("sdlc://self", "self-root", {}),
            (f"sdlc://self/{collection}", "self-collection", {"name": collection.replace("_", " ")}),
        ]
        return {"uri": uri, "context_type": "memory", "parents": parents, "self_collection": collection}
    if CONTEXT_JSON_RE.match(rel):
        return {"uri": "sdlc://context", "context_type": "memory", "parents": []}
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


_HEADING_ID_RE = re.compile(r"^[A-Za-z]+[-_ ]?\d+\s*[:\u2014\u2013-]?\s*")
_FIELD_RE = r"^\s*(?:\*\*)?{name}:(?:\*\*)?\s*(.+?)\s*$"


def _field(text: str, name: str) -> str:
    m = re.search(_FIELD_RE.format(name=name), text, re.M | re.I)
    return m.group(1).strip() if m else ""


def build_self_texts(collection: str, raw_text: str) -> tuple[str, str, str]:
    """(abstract, overview) for a sdlc://self/<collection>/<id> node, matching
    the overview conventions migrate_context.py writes and self_status.py reads:
    open_questions -> "Status: <status>" (open unless it says resolved),
    build_checklist -> "<title> -- <status>", decisions -> "<decision> (<date>)".
    Accepts plain markdown (the memory-recall rule) or frontmatter fields."""
    fields, body = parse_frontmatter(raw_text)
    text = body if fields else raw_text
    heading = next((l.lstrip("#").strip() for l in text.splitlines() if l.strip().startswith("#")), "")
    heading_rest = _HEADING_ID_RE.sub("", heading, count=1).strip()
    status = (fields.get("status", "") if fields else "") or _field(text, "Status")
    date = (str(fields.get("date", "")) if fields else "") or _field(text, "Date")

    if collection == "open_questions":
        abstract = (fields.get("summary", "") if fields else "") or _field(text, "Question") or heading_rest or first_paragraph(text, 200)
        overview = f"Status: {status or 'open'}"
    elif collection == "decisions":
        abstract = (fields.get("summary", "") if fields else "") or _field(text, "Decision") or heading_rest or first_paragraph(text, 200)
        overview = f"{abstract} ({date})" if date else abstract
    elif collection == "build_checklist":
        abstract = heading or first_paragraph(text, 200)
        overview = f"{abstract} -- {status}" if status else abstract
    else:
        abstract = (fields.get("summary", "") if fields else "") or heading_rest or first_paragraph(text, 200)
        overview = first_paragraph(text)
    return abstract[:200], overview, raw_text


def build_texts(rel_path: str, raw_text: str) -> tuple[str, str, str]:
    """Returns (abstract, overview, content) for a leaf file."""
    if rel_path.endswith(".json"):
        import json as _json
        try:
            data = _json.loads(raw_text)
        except (ValueError, TypeError):
            data = {}
        product = data.get("product", {}) if isinstance(data, dict) else {}
        phase = data.get("phase", {}) if isinstance(data, dict) else {}
        first = data.get("first_product", {}) if isinstance(data, dict) else {}
        meta = data.get("_meta", {}) if isinstance(data, dict) else {}
        if isinstance(first, dict) and first:
            # A product repo's context (written by /sdlc-start): name it, say where
            # it stands. #1258: the abstract used to be the file's raw first 150
            # characters ("{\n  \"_meta\": {...").
            name = first.get("name") or first.get("codename") or "This product"
            status = str(first.get("status", "")).strip()
            problem = str(first.get("problem_statement") or first.get("core_value") or first.get("summary") or "").strip()
            abstract = (f"{name} — {status}" if status else str(name))[:200]
            overview = " ".join(x for x in (abstract + ".", problem[:400]) if x).strip()
            return abstract, overview, raw_text
        if isinstance(meta, dict) and meta.get("purpose"):
            abstract = str(meta["purpose"]).strip()[:200]
            return abstract, abstract, raw_text
        if product:
            name = product.get("name") or product.get("codename") or rel_path
            core_value = product.get("core_value", "")
            abstract = (f"{name}: {core_value}" if core_value else str(name))[:200]
            overview = f"Phase: {phase.get('current', 'unknown')}. {core_value}".strip()
        else:
            abstract = first_paragraph(raw_text, 140)
            overview = first_paragraph(raw_text)
        return abstract, overview, raw_text

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


_SECTION_RE = re.compile(r"^## +(.+)$", re.M)
_BOLD_LEAD_RE = re.compile(r"^\*\*(.+?)\*\*")


def chunk_research_bullets(body: str) -> list[dict[str, str]]:
    """Split a research file's body into (section, bullet) chunks.

    research/ files are dense distillations, not short notes (median 19KB,
    up to 34 top-level bullets per file) -- each `- ` bullet is a
    self-contained concept + citation + gap-analysis unit. The embedding
    model's ~512-token window means one vector for the whole file only
    "sees" its first section; chunking each bullet into its own leaf makes
    the rest of the file reachable by semantic search too, not just BM25.
    Nested/indented bullets are left as part of their parent bullet's text
    (supporting detail, not separate concepts).
    """
    sections = _SECTION_RE.split(body)
    # re.split with a capturing group interleaves: [preamble, heading1, text1, heading2, text2, ...]
    chunks: list[dict[str, str]] = []
    pairs = list(zip(sections[1::2], sections[2::2])) if len(sections) > 1 else []
    for section_idx, (heading, text) in enumerate(pairs, start=1):
        bullet_idx = 0
        current: list[str] = []

        def flush():
            nonlocal bullet_idx, current
            if not current:
                return
            bullet_idx += 1
            raw = "\n".join(current).strip()
            if not raw:
                current = []
                return
            bullet_text = re.sub(r"^- +", "", raw, count=1)
            bold = _BOLD_LEAD_RE.match(bullet_text)
            abstract = (bold.group(1) if bold else bullet_text[:140]).strip()[:140]
            sentence_end = bullet_text.find(". ", len(abstract))
            overview = bullet_text[: sentence_end + 1] if sentence_end != -1 else bullet_text[:280]
            chunks.append({
                "section_idx": section_idx, "bullet_idx": bullet_idx, "heading": heading.strip(),
                "abstract": abstract, "overview": overview.strip(), "content": bullet_text,
            })
            current = []

        for line in text.splitlines():
            if re.match(r"^- ", line):
                flush()
                current = [line]
            elif current:
                current.append(line)
        flush()
    return chunks


def ingest_research_chunks(conn, embedder: Embedder, path: Path, file_uri: str, body: str, now_iso: str) -> int:
    store.delete_children(conn, file_uri)
    chunks = chunk_research_bullets(body)
    for chunk in chunks:
        uri = f"{file_uri}#{chunk['section_idx']}-{chunk['bullet_idx']}"
        content_for_embedding = chunk["content"][:3000]
        for level, text in ((0, chunk["abstract"]), (1, chunk["overview"]), (2, content_for_embedding)):
            store.upsert(
                conn, uri=uri, parent_uri=file_uri, level=level, context_type="resource",
                abstract=chunk["abstract"], overview=chunk["overview"], content=chunk["content"],
                content_path=f"{path.name}#{chunk['heading']}", is_leaf=True,
                created_at=now_iso, updated_at=now_iso, embedding=embedder.embed(text or chunk["abstract"]),
            )
    return len(chunks)


def ingest_file(conn, embedder: Embedder, repo_root: Path, path: Path) -> Optional[str]:
    info = classify(repo_root, path)
    if info is None:
        return None
    now_iso = datetime.now(timezone.utc).isoformat()
    parent_uri = ensure_ancestors(conn, embedder, repo_root, info["parents"], now_iso)

    raw_text = path.read_text(errors="replace")
    rel_path = path.relative_to(repo_root).as_posix()
    if info.get("self_collection"):
        abstract, overview, content = build_self_texts(info["self_collection"], raw_text)
    else:
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

    if info["context_type"] == "resource" and rel_path.startswith("research/"):
        ingest_research_chunks(conn, embedder, path, uri, content, now_iso)

    return uri


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Ingest files into the SDLC memory tree")
    parser.add_argument("paths", nargs="*", help="File paths to ingest")
    parser.add_argument(
        "--all", action="store_true",
        help="Reindex artifacts/, research/, skills/, compliance/, glossary/, decisions/adr/, "
             ".sdlc-memory/tree/self/ (decisions, open questions, checklist), sdlc-context.json",
    )
    args = parser.parse_args(argv)

    repo_root = find_repo_root()
    ensure_config(repo_root)
    conn = store.connect(repo_root)
    embedder = Embedder(repo_root)

    targets: list[Path] = []
    if args.all:
        patterns = (
            "artifacts/**/*.md", "research/**/*.md", "skills/*/SKILL.md",
            "compliance/**/*.md", "glossary/*.md", "decisions/adr/*.md",
            ".sdlc-memory/tree/self/*/*.md",
        )
        for pattern in patterns:
            targets.extend(repo_root.glob(pattern))
        context_json = repo_root / "sdlc-context.json"
        if context_json.exists():
            targets.append(context_json)
    for p in args.paths:
        pp = Path(p)
        targets.append(pp if pp.is_absolute() else repo_root / pp)

    ingested = 0
    skipped: list[str] = []
    explicit = {str(t) for t in targets[len(targets) - len(args.paths):]} if args.paths else set()
    for path in targets:
        if not path.exists() or not path.is_file():
            if str(path) in explicit:
                skipped.append(f"{path} (no such file)")
            continue
        uri = ingest_file(conn, embedder, repo_root, path)
        if uri:
            ingested += 1
            print(f"ingested {path} -> {uri}")
        elif str(path) in explicit:
            skipped.append(f"{path} (not an indexable location)")
    print(f"done: {ingested} file(s) indexed (embedder backend: {embedder.backend})")
    # An explicitly named file that was not indexed is an error the caller must
    # see (#1249: a decision silently reported "0 file(s) indexed"). The write
    # hook ignores the exit code, so calling ingest on every write stays safe.
    for s in skipped:
        print(f"SKIPPED: {s} -- indexable: artifacts/<product>/<phase>/, research/, "
              "skills/<name>/SKILL.md, compliance/, glossary/, decisions/adr/, "
              ".sdlc-memory/tree/self/<collection>/<id>.md, sdlc-context.json", file=sys.stderr)
    return 1 if skipped else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
