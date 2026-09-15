"""Local embedding + rerank models for the SDLC memory engine.

Direct analog of OpenViking's pluggable model clients
(openviking/models/embedder/base.py, openviking/models/rerank.py) but
running fully local/offline -- no network calls at query time, no
dependency on the OpenViking repo or service.

Preferred backend: `fastembed` (ONNX, CPU, no torch, no server) for both
dense embeddings and cross-encoder rerank -- installed per-repo by
scripts/memory/bootstrap.sh into <repo>/.sdlc-memory/.venv.

If fastembed isn't installed yet (bootstrap hasn't run, or offline with no
cached model), both embedding and rerank degrade to deterministic,
dependency-free fallbacks so the rest of the pipeline (BM25 + hierarchical
walk + hotness) keeps working correctly, just with weaker semantic
matching. This mirrors OpenViking's own pluggability -- a swappable model
client behind a stable interface -- rather than a hard requirement.
"""

from __future__ import annotations

import hashlib
import math
import re
from functools import lru_cache
from typing import Optional

from common import load_config

_TOKEN_RE = re.compile(r"[a-z0-9]+")


def _tokenize(text: str) -> list[str]:
    return _TOKEN_RE.findall(text.lower())


def _hash_embedding(text: str, dim: int) -> list[float]:
    """Deterministic, dependency-free bag-of-hashed-tokens embedding.
    Not semantic, but stable, fast, and good enough to keep the pipeline
    functional before fastembed is provisioned."""
    vec = [0.0] * dim
    for tok in _tokenize(text):
        h = int(hashlib.md5(tok.encode("utf-8")).hexdigest(), 16)
        vec[h % dim] += 1.0
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


@lru_cache(maxsize=1)
def _fastembed_embedder(model_name: str):
    from fastembed import TextEmbedding  # type: ignore

    return TextEmbedding(model_name=model_name)


@lru_cache(maxsize=1)
def _fastembed_reranker(model_name: str):
    from fastembed.rerank.cross_encoder import TextCrossEncoder  # type: ignore

    return TextCrossEncoder(model_name=model_name)


class Embedder:
    def __init__(self, repo_root=None):
        self.cfg = load_config(repo_root)
        self.dim = int(self.cfg["embedding_dim"])
        self._backend: Optional[str] = None

    def embed(self, text: str) -> list[float]:
        text = text or ""
        try:
            model = _fastembed_embedder(self.cfg["embedding_model"])
            vec = next(iter(model.embed([text])))
            self._backend = "fastembed"
            return [float(x) for x in vec]  # numpy float32 -> native float (JSON-serializable)
        except Exception:
            self._backend = "hash-fallback"
            return _hash_embedding(text, self.dim)

    @property
    def backend(self) -> str:
        return self._backend or "unknown"


class Reranker:
    def __init__(self, repo_root=None):
        self.cfg = load_config(repo_root)
        self._backend: Optional[str] = None

    def score(self, query: str, documents: list[str]) -> list[float]:
        if not documents:
            return []
        try:
            model = _fastembed_reranker(self.cfg["rerank_model"])
            raw_scores = list(model.rerank(query, documents))
            self._backend = "fastembed"
            # Cross-encoder output is an unbounded logit; squash to (0,1) so
            # it composes correctly with hotness blending and score
            # propagation, which both assume roughly-0..1 semantic scores.
            return [1.0 / (1.0 + math.exp(-float(s))) for s in raw_scores]
        except Exception:
            self._backend = "lexical-fallback"
            return [_lexical_overlap(query, doc) for doc in documents]

    @property
    def backend(self) -> str:
        return self._backend or "unknown"


def _lexical_overlap(query: str, doc: str) -> float:
    """Fallback rerank: Jaccard token overlap. Deterministic, no dependency,
    used only when fastembed's cross-encoder isn't available."""
    q = set(_tokenize(query))
    d = set(_tokenize(doc))
    if not q or not d:
        return 0.0
    return len(q & d) / len(q | d)
