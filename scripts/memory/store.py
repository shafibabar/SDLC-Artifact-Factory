"""SQLite-backed context store for the SDLC memory engine.

Mirrors the shape of OpenViking's unified context collection
(openviking/storage/collection_schemas.py): one row per context node,
identified deterministically (openviking/storage/vector_ids.py pattern),
carrying both a sparse (FTS5/BM25) and dense (embedding) representation so
hybrid search matches OpenViking's vector+sparse_vector design.

Dense vectors are stored as JSON float arrays. If the optional `sqlite-vec`
extension is importable it is loaded for accelerated ANN search; otherwise
this falls back to brute-force cosine similarity in Python, which is exact
(not approximate) and fast enough at the scale of a single repo's context
tree (hundreds to low thousands of nodes).
"""

from __future__ import annotations

import json
import math
import sqlite3
from pathlib import Path
from typing import Any, Iterable, Optional

from common import context_id, db_path, memory_root

SCHEMA = """
CREATE TABLE IF NOT EXISTS contexts (
    id TEXT PRIMARY KEY,
    uri TEXT NOT NULL,
    parent_uri TEXT,
    level INTEGER NOT NULL,
    context_type TEXT NOT NULL,
    abstract TEXT DEFAULT '',
    overview TEXT DEFAULT '',
    content TEXT DEFAULT '',
    content_path TEXT DEFAULT '',
    tags TEXT DEFAULT '[]',
    category TEXT DEFAULT '',
    is_leaf INTEGER DEFAULT 0,
    active_count INTEGER DEFAULT 0,
    created_at TEXT,
    updated_at TEXT,
    embedding TEXT
);
CREATE INDEX IF NOT EXISTS idx_contexts_parent ON contexts(parent_uri);
CREATE INDEX IF NOT EXISTS idx_contexts_uri ON contexts(uri);
CREATE INDEX IF NOT EXISTS idx_contexts_level ON contexts(level);

CREATE VIRTUAL TABLE IF NOT EXISTS contexts_fts USING fts5(
    id UNINDEXED, uri UNINDEXED, text
);
"""


def connect(repo_root: Optional[Path] = None) -> sqlite3.Connection:
    path = db_path(repo_root)
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    _try_load_sqlite_vec(conn)
    conn.executescript(SCHEMA)
    conn.commit()
    return conn


def _try_load_sqlite_vec(conn: sqlite3.Connection) -> bool:
    try:
        import sqlite_vec  # type: ignore

        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
        return True
    except Exception:
        return False


def upsert(
    conn: sqlite3.Connection,
    *,
    uri: str,
    parent_uri: Optional[str],
    level: int,
    context_type: str,
    abstract: str = "",
    overview: str = "",
    content: str = "",
    content_path: str = "",
    tags: Optional[list[str]] = None,
    category: str = "",
    is_leaf: bool = False,
    created_at: str,
    updated_at: str,
    embedding: Optional[list[float]] = None,
    active_count: Optional[int] = None,
) -> str:
    cid = context_id(uri, level)
    existing = conn.execute(
        "SELECT active_count, created_at FROM contexts WHERE id = ?", (cid,)
    ).fetchone()
    if active_count is None:
        active_count = existing["active_count"] if existing else 0
    created = existing["created_at"] if existing and existing["created_at"] else created_at

    conn.execute(
        """
        INSERT INTO contexts (id, uri, parent_uri, level, context_type, abstract, overview,
                               content, content_path, tags, category, is_leaf, active_count,
                               created_at, updated_at, embedding)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            uri=excluded.uri, parent_uri=excluded.parent_uri, level=excluded.level,
            context_type=excluded.context_type, abstract=excluded.abstract,
            overview=excluded.overview, content=excluded.content,
            content_path=excluded.content_path, tags=excluded.tags, category=excluded.category,
            is_leaf=excluded.is_leaf,
            updated_at=excluded.updated_at,
            embedding=COALESCE(excluded.embedding, contexts.embedding)
        """,
        (
            cid, uri, parent_uri, level, context_type, abstract, overview, content,
            content_path, json.dumps(tags or []), category, int(is_leaf), active_count, created,
            updated_at, json.dumps(embedding) if embedding is not None else None,
        ),
    )
    conn.execute("DELETE FROM contexts_fts WHERE id = ?", (cid,))
    conn.execute(
        "INSERT INTO contexts_fts (id, uri, text) VALUES (?, ?, ?)",
        (cid, uri, " \n ".join(filter(None, [abstract, overview, content]))),
    )
    conn.commit()
    return cid


def touch(conn: sqlite3.Connection, uri_or_id: str, now_iso: str) -> int:
    row = conn.execute(
        "SELECT id FROM contexts WHERE id = ? OR uri = ? ORDER BY level LIMIT 1",
        (uri_or_id, uri_or_id),
    ).fetchone()
    if not row:
        return 0
    conn.execute(
        "UPDATE contexts SET active_count = active_count + 1, updated_at = ? WHERE id = ?",
        (now_iso, row["id"]),
    )
    conn.commit()
    return conn.execute("SELECT active_count FROM contexts WHERE id = ?", (row["id"],)).fetchone()[0]


def children(conn: sqlite3.Connection, parent_uri: str) -> list[sqlite3.Row]:
    """One row per distinct child URI (its level-1/overview record, which
    carries abstract/overview/content/is_leaf/content_path alongside it --
    see ingest.py, every node writes matching level0/1/2 rows)."""
    return conn.execute(
        "SELECT * FROM contexts WHERE parent_uri = ? AND level = 1", (parent_uri,)
    ).fetchall()


def get_by_uri(conn: sqlite3.Connection, uri: str, level: Optional[int] = None) -> list[sqlite3.Row]:
    if level is None:
        return conn.execute("SELECT * FROM contexts WHERE uri = ?", (uri,)).fetchall()
    return conn.execute("SELECT * FROM contexts WHERE uri = ? AND level = ?", (uri, level)).fetchall()


def bm25_search(conn: sqlite3.Connection, query: str, level: Optional[Iterable[int]] = None, limit: int = 40) -> list[dict[str, Any]]:
    if not query.strip():
        return []
    safe_query = " ".join(f'"{t}"' for t in query.split() if t.strip())
    if not safe_query:
        return []
    try:
        rows = conn.execute(
            """
            SELECT c.*, bm25(contexts_fts) AS rank
            FROM contexts_fts
            JOIN contexts c ON c.id = contexts_fts.id
            WHERE contexts_fts MATCH ?
            ORDER BY rank LIMIT ?
            """,
            (safe_query, limit),
        ).fetchall()
    except sqlite3.OperationalError:
        return []
    results = []
    for r in rows:
        if level is not None and r["level"] not in level:
            continue
        # bm25() returns lower-is-better; invert to a 0..1-ish similarity score.
        score = 1.0 / (1.0 + max(r["rank"], 0.0))
        results.append({**dict(r), "sparse_score": score})
    return results


def cosine(a: list[float], b: list[float]) -> float:
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def dense_search(conn: sqlite3.Connection, query_embedding: list[float], level: Optional[Iterable[int]] = None, limit: int = 40) -> list[dict[str, Any]]:
    clause = ""
    params: list[Any] = []
    if level is not None:
        placeholders = ",".join("?" for _ in level)
        clause = f"WHERE level IN ({placeholders})"
        params = list(level)
    rows = conn.execute(f"SELECT * FROM contexts {clause}", params).fetchall()
    scored = []
    for r in rows:
        if not r["embedding"]:
            continue
        emb = json.loads(r["embedding"])
        score = cosine(query_embedding, emb)
        scored.append({**dict(r), "dense_score": score})
    scored.sort(key=lambda x: x["dense_score"], reverse=True)
    return scored[:limit]


def all_uris(conn: sqlite3.Connection) -> set[str]:
    return {row["uri"] for row in conn.execute("SELECT DISTINCT uri FROM contexts")}
