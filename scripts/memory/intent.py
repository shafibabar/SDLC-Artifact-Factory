"""Intent analysis: turn a raw prompt into a small set of declarative search
queries, mirroring OpenViking's openviking/retrieve/intent_analyzer.py.

OpenViking calls its main LLM for this. To keep this fully offline and add
zero Claude-token cost per turn, this uses a local Ollama model if present
on the machine (same fallback precedent as OpenViking's own
openviking_cli/utils/ollama.py). If Ollama isn't installed/reachable, it
falls back to treating the raw prompt as a single query -- still correct,
just without the LLM-driven multi-query expansion.
"""

from __future__ import annotations

import json
import re
import urllib.request
from typing import Any

OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_TIMEOUT = 2.5

PROMPT_TEMPLATE = """You are a search-query planner. Given the user's message, produce up to 5 \
short, self-contained, declarative search queries (noun/verb phrases, not questions) that would \
retrieve the most relevant prior context. Tag each with a context_type of "skill", "resource", \
or "memory". Respond with ONLY JSON: {{"queries": [{{"query": str, "context_type": str, \
"priority": 1-5}}]}}.

User message: {message}
"""


def _try_ollama(message: str) -> list[dict[str, Any]] | None:
    payload = json.dumps(
        {
            "model": "llama3.2",
            "prompt": PROMPT_TEMPLATE.format(message=message[:4000]),
            "stream": False,
            "format": "json",
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL, data=payload, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(req, timeout=OLLAMA_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        text = body.get("response", "")
        parsed = json.loads(text)
        queries = parsed.get("queries", [])
        cleaned = []
        for q in queries[:5]:
            query = str(q.get("query", "")).strip()
            if not query:
                continue
            cleaned.append(
                {
                    "query": query,
                    "context_type": q.get("context_type") if q.get("context_type") in
                    ("skill", "resource", "memory") else None,
                    "priority": int(q.get("priority", 3)),
                }
            )
        return cleaned or None
    except Exception:
        return None


def _fallback(message: str) -> list[dict[str, Any]]:
    query = re.sub(r"\s+", " ", message).strip()[:300]
    if not query:
        return []
    return [{"query": query, "context_type": None, "priority": 3}]


def build_query_plan(message: str) -> list[dict[str, Any]]:
    return _try_ollama(message) or _fallback(message)
