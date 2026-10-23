#!/usr/bin/env python3
"""calculate-business-case.py — bottom-up pricing business case with sensitivity.

Owned by the pricing-and-packaging skill. Deterministic arithmetic only: it
makes no pricing decision. The agent applying the skill chooses the inputs
(from WTP evidence, the canvas cost structure and counted segment sizes) and
judges the result.

Usage:
    calculate-business-case.py <input.json>

Input JSON:
    {
      "currency": "EUR",                 # optional, default ""
      "period": "year",                  # optional, default "year"
      "fixed_cost": 400000,              # build + run cost not tied to a customer
      "sensitivity": [-0.2, 0, 0.2],     # optional multipliers applied to price and adoption
      "segments": [
        {"name": "Team", "size": 2000, "adoption": 0.05,
         "price": 5000, "cost_to_serve": 900}
      ]
    }

    size          customers in the segment (counted, > 0)
    adoption      share that buys at this price, 0 < adoption <= 1
    price         realised price per customer per period (list net of expected discount), >= 0
    cost_to_serve variable cost per customer per period, >= 0

Output: Markdown tables on stdout — per-segment base case, net, break-even
adoption multiplier, and a price x adoption sensitivity grid of net.
Warnings (stdout, prefixed "WARNING:") for any price below cost to serve.
Exit codes: 0 ok (the case may still be negative; the reader judges),
2 invalid input.
"""
import json
import sys


def fail(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(2)


def num(seg: dict, key: str, idx: int) -> float:
    v = seg.get(key)
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        fail(f"segment {idx}: '{key}' must be a number")
    return float(v)


def fmt(x: float) -> str:
    return f"{x:,.0f}"


def load(path: str) -> dict:
    try:
        with open(path) as fh:
            data = json.load(fh)
    except (OSError, ValueError) as e:
        fail(f"cannot read {path}: {e}")
    if not isinstance(data, dict):
        fail("top level must be an object")
    segs = data.get("segments")
    if not isinstance(segs, list) or not segs:
        fail("'segments' must be a non-empty list")
    for i, s in enumerate(segs):
        if not isinstance(s, dict) or not isinstance(s.get("name"), str) or not s["name"]:
            fail(f"segment {i}: needs a non-empty 'name'")
        if num(s, "size", i) <= 0:
            fail(f"segment {i}: 'size' must be > 0")
        a = num(s, "adoption", i)
        if not 0 < a <= 1:
            fail(f"segment {i}: 'adoption' must be in (0, 1]")
        if num(s, "price", i) < 0 or num(s, "cost_to_serve", i) < 0:
            fail(f"segment {i}: 'price' and 'cost_to_serve' must be >= 0")
    fixed = data.get("fixed_cost", 0)
    if isinstance(fixed, bool) or not isinstance(fixed, (int, float)) or fixed < 0:
        fail("'fixed_cost' must be a number >= 0")
    sens = data.get("sensitivity", [-0.2, 0, 0.2])
    if (not isinstance(sens, list) or not sens
            or any(isinstance(m, bool) or not isinstance(m, (int, float)) or m <= -1 for m in sens)):
        fail("'sensitivity' must be a non-empty list of numbers > -1")
    return data


def net(segs: list, fixed: float, pm: float = 0.0, am: float = 0.0) -> float:
    total = 0.0
    for s in segs:
        customers = s["size"] * min(s["adoption"] * (1 + am), 1.0)
        total += customers * (s["price"] * (1 + pm) - s["cost_to_serve"])
    return total - fixed


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: calculate-business-case.py <input.json>")
    data = load(sys.argv[1])
    segs, fixed = data["segments"], float(data.get("fixed_cost", 0))
    cur = data.get("currency", "")
    per = data.get("period", "year")
    unit = f"{cur} per {per}".strip()
    sens = sorted(float(m) for m in data.get("sensitivity", [-0.2, 0, 0.2]))

    print(f"## Base case ({unit})\n")
    print("| Segment | Size | Adoption | Customers | Price | Revenue | Cost to serve | Contribution |")
    print("|---|---|---|---|---|---|---|---|")
    tot_rev = tot_con = 0.0
    warnings = []
    for s in segs:
        customers = s["size"] * s["adoption"]
        rev = customers * s["price"]
        con = rev - customers * s["cost_to_serve"]
        tot_rev += rev
        tot_con += con
        if s["price"] < s["cost_to_serve"]:
            warnings.append(f"WARNING: {s['name']}: price {fmt(s['price'])} is below cost to serve "
                            f"{fmt(s['cost_to_serve'])}; every customer loses money")
        print(f"| {s['name']} | {fmt(s['size'])} | {s['adoption']:.1%} | {fmt(customers)} | "
              f"{fmt(s['price'])} | {fmt(rev)} | {fmt(s['cost_to_serve'])} | {fmt(con)} |")
    print(f"| **Total** | | | | | {fmt(tot_rev)} | | {fmt(tot_con)} |\n")
    print(f"Fixed cost: {fmt(fixed)}. **Net: {fmt(tot_con - fixed)}**\n")
    if tot_con > 0:
        print(f"Break-even adoption at base price: {fixed / tot_con:.2f}x the base adoption.\n")
    else:
        print("Break-even adoption at base price: none (contribution is not positive).\n")

    print(f"## Sensitivity: net ({unit}) by price change (rows) x adoption change (columns)\n")
    print("| Price \\ Adoption | " + " | ".join(f"{m:+.0%}" for m in sens) + " |")
    print("|---|" + "---|" * len(sens))
    for pm in sens:
        cells = " | ".join(fmt(net(segs, fixed, pm, am)) for am in sens)
        print(f"| {pm:+.0%} | {cells} |")
    lo = sens[0]
    print(f"\nPessimistic corner (price {lo:+.0%}, adoption {lo:+.0%}): "
          f"net {fmt(net(segs, fixed, lo, lo))}.")
    for w in warnings:
        print(w)


if __name__ == "__main__":
    main()
