"""Hotness scoring for cold/hot memory lifecycle management.

Direct port of OpenViking's openviking/retrieve/memory_lifecycle.py --
same formula, same defaults:

    freq     = sigmoid(log1p(active_count))
    recency  = exp(-decay_rate * age_days), decay_rate = ln(2) / half_life_days
    hotness  = freq * recency   (0.0 if updated_at is None)
"""

from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Optional

DEFAULT_HALF_LIFE_DAYS = 7.0


def _sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


def parse_iso(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return None


def hotness_score(
    active_count: int,
    updated_at: Optional[str],
    now: Optional[datetime] = None,
    half_life_days: float = DEFAULT_HALF_LIFE_DAYS,
) -> float:
    updated_dt = parse_iso(updated_at)
    if updated_dt is None:
        return 0.0
    now = now or datetime.now(timezone.utc)
    age_days = max((now - updated_dt).total_seconds() / 86400.0, 0.0)
    freq = _sigmoid(math.log1p(max(active_count, 0)))
    decay_rate = math.log(2) / max(half_life_days, 1e-6)
    recency = math.exp(-decay_rate * age_days)
    return freq * recency


def blend(semantic_score: float, hotness: float, alpha: float) -> float:
    """final = (1-alpha)*semantic + alpha*hotness -- same blend OpenViking's
    hierarchical_retriever._convert_to_matched_contexts uses."""
    return (1.0 - alpha) * semantic_score + alpha * hotness
