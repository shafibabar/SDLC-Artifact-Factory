#!/usr/bin/env python3
"""Hierarchical retriever for the SDLC memory engine.

Ports the algorithm in OpenViking's openviking/retrieve/hierarchical_retriever.py:

QUICK mode  -- flat hybrid (BM25 + dense) search, no tree walk, no rerank.
               Cheap; used for the always-on per-turn orientation layer.
THINKING mode -- best-first tree walk:
    1. global hybrid search restricted to level in {0,1} (directory
       abstracts/overviews) -> candidate directories
    2. cross-encoder rerank of those candidates -> directory_scores, pushed
       onto a max-heap (negated score)
    3. pop up to MAX_PARALLEL best unvisited directories per round, expand
       their children; propagate score: final = alpha*child + (1-alpha)*parent
       (score_propagation_alpha); leaves (level==2) collected, directories
       re-pushed for further recursion
    4. convergence: stop when the top-k URI set is stable for
       MAX_CONVERGENCE_ROUNDS rounds, or the pool stops growing that long
    5. dedup by URI (max score kept)
    6. hotness blend reorders the final top-k; returned URIs are "touched"
       (active_count bumped), same as OpenViking's access-driven hotness.
"""

from __future__ import annotations

import argparse
import heapq
import json
import sys
from datetime import datetime, timezone
from typing import Any, Optional

import store
from common import load_config
from hotness import blend, hotness_score
from models import Embedder, Reranker, _lexical_overlap


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _rrf_merge(*ranked_lists: list[dict[str, Any]], k: int = 60) -> dict[str, dict[str, Any]]:
    """Reciprocal rank fusion across the BM25 and dense result lists,
    mirroring OpenViking's vector+sparse_vector hybrid scoring."""
    merged: dict[str, dict[str, Any]] = {}
    for ranked in ranked_lists:
        for rank, row in enumerate(ranked):
            uri = row["uri"]
            contribution = 1.0 / (k + rank + 1)
            if uri not in merged:
                merged[uri] = {"row": row, "score": 0.0}
            merged[uri]["score"] += contribution
            if row.get("level", 99) < merged[uri]["row"].get("level", 99):
                merged[uri]["row"] = row
    return merged


def hybrid_search(conn, embedder: Embedder, query: str, level: Optional[list[int]], limit: int) -> list[dict[str, Any]]:
    bm25 = store.bm25_search(conn, query, level=level, limit=limit)
    q_emb = embedder.embed(query)
    dense = store.dense_search(conn, q_emb, level=level, limit=limit)
    merged = _rrf_merge(bm25, dense)
    results = [{**v["row"], "score": v["score"]} for v in merged.values()]
    results.sort(key=lambda r: r["score"], reverse=True)
    return results[:limit]


def score_node(embedder: Embedder, query: str, query_embedding: list[float], row: dict[str, Any]) -> float:
    text = " ".join(filter(None, [row.get("abstract", ""), row.get("overview", "")]))
    lexical = _lexical_overlap(query, text)
    dense = 0.0
    if row.get("embedding"):
        try:
            emb = json.loads(row["embedding"])
            dense = store.cosine(query_embedding, emb)
        except Exception:
            dense = 0.0
    else:
        dense = store.cosine(query_embedding, embedder.embed(text))
    return 0.6 * dense + 0.4 * lexical


def apply_hotness(rows: list[dict[str, Any]], alpha: float, half_life_days: float) -> list[dict[str, Any]]:
    now = datetime.now(timezone.utc)
    for r in rows:
        hot = hotness_score(r.get("active_count", 0), r.get("updated_at"), now, half_life_days)
        r["hotness"] = hot
        r["final_score"] = blend(r.get("score", 0.0), hot, alpha)
    rows.sort(key=lambda r: r["final_score"], reverse=True)
    return rows


def quick_search(conn, embedder: Embedder, cfg: dict, query: str, level: Optional[list[int]], limit: int) -> list[dict[str, Any]]:
    results = hybrid_search(conn, embedder, query, level, cfg["candidate_limit"])
    deduped: dict[str, dict[str, Any]] = {}
    for r in results:
        if r["uri"] not in deduped or r["score"] > deduped[r["uri"]]["score"]:
            deduped[r["uri"]] = r
    return apply_hotness(list(deduped.values()), cfg["hotness_alpha"], cfg["half_life_days"])[:limit]


def thinking_search(conn, embedder: Embedder, reranker: Reranker, cfg: dict, query: str, limit: int) -> dict[str, Any]:
    max_parallel = cfg["max_parallel_child_searches"]
    alpha = cfg["score_propagation_alpha"]
    max_rounds = cfg["max_convergence_rounds"]

    global_results = hybrid_search(conn, embedder, query, level=[0, 1], limit=cfg["candidate_limit"])
    dir_uris = list({r["uri"] for r in global_results})
    dir_texts = []
    dir_rows: dict[str, dict[str, Any]] = {}
    for uri in dir_uris:
        row = next(r for r in global_results if r["uri"] == uri)
        dir_rows[uri] = row
        dir_texts.append(" ".join(filter(None, [row.get("abstract", ""), row.get("overview", "")])))
    rerank_scores = reranker.score(query, dir_texts) if dir_texts else []

    heap: list[tuple[float, str]] = []
    for uri, rscore in zip(dir_uris, rerank_scores):
        heapq.heappush(heap, (-rscore, uri))

    query_embedding = embedder.embed(query)
    visited: set[str] = set()
    collected: dict[str, dict[str, Any]] = {}
    stable_rounds = 0
    prev_topk: Optional[frozenset[str]] = None
    prev_pool_size = 0
    rounds = 0

    while heap and rounds < 25:
        rounds += 1
        batch: list[tuple[float, str]] = []
        while heap and len(batch) < max_parallel:
            neg_score, uri = heapq.heappop(heap)
            if uri in visited:
                continue
            visited.add(uri)
            batch.append((-neg_score, uri))
        if not batch:
            break

        for parent_score, parent_uri in batch:
            for child in store.children(conn, parent_uri):
                child = dict(child)
                child_score = score_node(embedder, query, query_embedding, child)
                final = alpha * child_score + (1 - alpha) * parent_score
                if child["is_leaf"]:
                    existing = collected.get(child["uri"])
                    if not existing or final > existing["score"]:
                        collected[child["uri"]] = {**child, "score": final}
                else:
                    if child["uri"] not in visited:
                        heapq.heappush(heap, (-final, child["uri"]))
                    # A non-leaf directory can also itself be directly relevant
                    # (e.g. matches the query at the overview level) -- keep it
                    # as a candidate result too, mirroring OpenViking treating
                    # directory-level matches as retrievable context.
                    existing = collected.get(child["uri"])
                    if not existing or final > existing["score"]:
                        collected[child["uri"]] = {**child, "score": final}

        topk = frozenset(sorted(collected, key=lambda u: -collected[u]["score"])[:limit])
        pool_size = len(collected)
        if topk == prev_topk or pool_size == prev_pool_size:
            stable_rounds += 1
        else:
            stable_rounds = 0
        prev_topk, prev_pool_size = topk, pool_size
        if stable_rounds >= max_rounds:
            break

    final_rows = apply_hotness(list(collected.values()), cfg["hotness_alpha"], cfg["half_life_days"])
    return {
        "results": final_rows[:limit],
        "rounds": rounds,
        "directories_visited": len(visited),
        "embedder_backend": embedder.backend,
        "reranker_backend": reranker.backend,
    }


def to_public(row: dict[str, Any], include_content: bool) -> dict[str, Any]:
    """Shape a result for agent consumption: abstract/overview only by
    default -- never the raw embedding, never full content -- so retrieval
    itself doesn't undo the token savings it exists to produce. Pass
    --full to drill into L2 content for specific URIs once identified."""
    public = {
        "uri": row["uri"],
        "is_leaf": bool(row.get("is_leaf")),
        "abstract": row.get("abstract", ""),
        "overview": row.get("overview", ""),
        "content_path": row.get("content_path", ""),
        "category": row.get("category", ""),
        "tags": row.get("tags", "[]"),
        "active_count": row.get("active_count", 0),
        "updated_at": row.get("updated_at"),
        "score": round(row.get("score", 0.0), 4),
        "hotness": round(row.get("hotness", 0.0), 4) if "hotness" in row else None,
        "final_score": round(row.get("final_score", row.get("score", 0.0)), 4),
    }
    if include_content:
        public["content"] = row.get("content", "")
    return public


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="SDLC memory hierarchical retriever")
    parser.add_argument("query")
    parser.add_argument("--mode", choices=["quick", "thinking"], default="thinking")
    parser.add_argument("--level", type=int, nargs="*", default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--full", action="store_true", help="Include full L2 content in results (drill-down; costs tokens)")
    args = parser.parse_args(argv)

    cfg = load_config()
    limit = args.limit or cfg["result_limit"]
    conn = store.connect()
    embedder = Embedder()

    if args.mode == "quick":
        results = quick_search(conn, embedder, cfg, args.query, args.level, limit)
        output = {"mode": "quick", "results": results, "embedder_backend": embedder.backend}
    else:
        reranker = Reranker()
        output = thinking_search(conn, embedder, reranker, cfg, args.query, limit)
        output["mode"] = "thinking"

    now_iso = _now_iso()
    for r in output["results"]:
        store.touch(conn, r["uri"], now_iso)
    output["results"] = [to_public(r, args.full) for r in output["results"]]

    print(json.dumps(output, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
