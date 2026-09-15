"""Shared helpers for the SDLC memory engine.

Conventions ported from OpenViking (openviking/core/context.py, directories.py,
openviking_cli/utils/uri.py) but reimplemented locally with no dependency on
the OpenViking repo/service:

- Every retrievable unit is a "context" addressed by a URI: sdlc://<scope>/<path>
  scopes: product | research | skills
- level 0 = abstract (one-liner), level 1 = overview (short paragraph),
  level 2 = detail (full content).
- State lives under <repo_root>/.sdlc-memory/, created in whichever repo this
  plugin is enabled in -- never inside the plugin's own repo.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any, Optional

MEMORY_DIRNAME = ".sdlc-memory"

DEFAULT_CONFIG: dict[str, Any] = {
    "half_life_days": 7.0,
    "score_propagation_alpha": 0.7,
    "hotness_alpha": 0.25,
    "max_parallel_child_searches": 4,
    "max_convergence_rounds": 3,
    "candidate_limit": 40,
    "result_limit": 10,
    "embedding_model": "BAAI/bge-small-en-v1.5",
    "rerank_model": "Xenova/ms-marco-MiniLM-L-6-v2",
    "embedding_dim": 384,
}


def find_repo_root(start: Optional[str] = None) -> Path:
    """Locate the consuming repo's root (nearest ancestor with a .git dir),
    never the plugin's own root. Falls back to cwd if no .git is found.

    Hook processes are launched by Claude Code with cwd set to the PLUGIN's
    own directory, not the project being worked on (confirmed by live
    testing -- see scripts/post-artifact-created.sh's comment) -- so hook
    scripts must pass the real project path explicitly. They do this via
    the SDLC_MEMORY_REPO_ROOT env var (set from the hook payload's own
    `cwd` field) rather than relying on this process's OS cwd.
    """
    env_root = os.environ.get("SDLC_MEMORY_REPO_ROOT")
    if env_root:
        return Path(env_root).resolve()
    p = Path(start or os.getcwd()).resolve()
    for candidate in [p, *p.parents]:
        if (candidate / ".git").exists():
            return candidate
    return p


def memory_root(repo_root: Optional[Path] = None) -> Path:
    root = repo_root or find_repo_root()
    return root / MEMORY_DIRNAME


def tree_root(repo_root: Optional[Path] = None) -> Path:
    return memory_root(repo_root) / "tree"


def db_path(repo_root: Optional[Path] = None) -> Path:
    return memory_root(repo_root) / "index.db"


def config_path(repo_root: Optional[Path] = None) -> Path:
    return memory_root(repo_root) / "config.json"


def load_config(repo_root: Optional[Path] = None) -> dict[str, Any]:
    cfg_path = config_path(repo_root)
    cfg = dict(DEFAULT_CONFIG)
    if cfg_path.exists():
        try:
            cfg.update(json.loads(cfg_path.read_text()))
        except Exception:
            pass
    return cfg


def ensure_config(repo_root: Optional[Path] = None) -> dict[str, Any]:
    cfg_path = config_path(repo_root)
    cfg_path.parent.mkdir(parents=True, exist_ok=True)
    if not cfg_path.exists():
        cfg_path.write_text(json.dumps(DEFAULT_CONFIG, indent=2) + "\n")
    return load_config(repo_root)


def context_id(uri: str, level: int) -> str:
    """Deterministic id, mirroring OpenViking's L0/L1/L2 id derivation
    (openviking/storage/vector_ids.py): the .abstract.md / .overview.md
    sidecar path is hashed for L0/L1, the raw uri for L2."""
    if level == 0:
        seed = f"{uri}/.abstract.md"
    elif level == 1:
        seed = f"{uri}/.overview.md"
    else:
        seed = uri
    return hashlib.md5(seed.encode("utf-8")).hexdigest()


_SAFE_SEGMENT = re.compile(r"[^A-Za-z0-9._-]+")


def sanitize_segment(segment: str) -> str:
    return _SAFE_SEGMENT.sub("-", segment).strip("-") or "item"


def uri_parent(uri: str) -> Optional[str]:
    scheme, _, rest = uri.partition("://")
    if "/" not in rest.rstrip("/"):
        return None
    parent_rest = rest.rstrip("/").rsplit("/", 1)[0]
    if not parent_rest:
        return None
    return f"{scheme}://{parent_rest}"


_BLOCK_SCALAR_RE = re.compile(r"^[>|][+-]?\d*$")


def parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Minimal YAML-frontmatter parser (key: value pairs, plus YAML block
    scalars -- `>` folded and `|` literal -- since 186/187 of this plugin's
    real skills author `description: >` multi-line blocks; without this,
    every such field parses to the literal string ">" and retrieval quality
    collapses across virtually the whole skill corpus). Returns (fields, body)."""
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end == -1:
        return {}, text
    raw = text[3:end].strip("\n")
    body = text[end + 4 :].lstrip("\n")
    fields: dict[str, Any] = {}
    lines = raw.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        i += 1
        if not line.strip() or line.strip().startswith("#") or ":" not in line:
            continue
        key_indent = len(line) - len(line.lstrip(" "))
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()

        if _BLOCK_SCALAR_RE.match(value):
            folded = value.startswith(">")
            block_lines: list[str] = []
            while i < len(lines):
                nxt = lines[i]
                if nxt.strip() == "":
                    i += 1
                    continue
                nxt_indent = len(nxt) - len(nxt.lstrip(" "))
                if nxt_indent <= key_indent:
                    break
                block_lines.append(nxt.strip())
                i += 1
            fields[key] = " ".join(block_lines) if folded else "\n".join(block_lines)
        elif value.startswith("[") and value.endswith("]"):
            items = [v.strip().strip("'\"") for v in value[1:-1].split(",") if v.strip()]
            fields[key] = items
        else:
            fields[key] = value.strip("'\"")
    return fields, body


def first_paragraph(body: str, max_chars: int = 500) -> str:
    for para in re.split(r"\n\s*\n", body.strip()):
        para = para.strip()
        if para and not para.startswith("#"):
            return para[:max_chars]
    stripped = body.strip()
    return stripped[:max_chars]
