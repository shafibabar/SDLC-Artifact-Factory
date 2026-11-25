# benchstat Official Documentation
**Authors:** The Go project (golang.org/x/perf)
**Domain:** Testing (performance)

Accessed 2026-11-25. Version shown: v0.0.0-20261117185222-4febdb082b2c, published 2026-11-17, BSD-3-Clause (https://pkg.go.dev/golang.org/x/perf/cmd/benchstat). All claims below come from that page unless noted.

## Core Concepts

- Input is Go benchmark format; `benchstat [flags] inputs...`.
- Run each benchmark at least 10 times (20 if possible).
- Reports median with confidence interval; comparisons use the Mann-Whitney U test, alpha 0.05 by default. `~` means no statistically significant difference.
- Current output shape:

```
                      │   old.txt   │               new.txt               │
                      │   sec/op    │   sec/op     vs base                │
Encode/format=json-48   1.718µ ± 1%   1.423µ ± 1%  -17.20% (p=0.000 n=10)
Encode/format=gob-48    3.066µ ± 0%   3.070µ ± 2%        ~ (p=0.446 n=10)
geomean                 2.295µ        2.090µ        -8.94%
```

- Filtering and grouping: `-filter`, `-table`, `-row`, `-col`, `-ignore`; `label=path` names columns.
- Advice: idle machine; interleave before and after runs; fix the run count in advance; with many benchmarks about 5% show significance by chance.
- The page describes no regression threshold or failing exit status.

## Actionable Techniques

- Benchmark base and head in the same job, interleaved (follows the advice above).
- The gate needs its own tested script that applies the threshold only to significant rows. Reading benchstat's machine-readable output is a likely route ([unverified] format not checked).
- Write benchmarks with `b.Loop` (https://pkg.go.dev/testing). Built-in results carry no percentile; a p99 requires measuring it and calling `b.ReportMetric` (same page; design inference).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| go-performance-test, go-makefile | W3B-14 to 16; B-4 | Output shape, method, no built-in gate |

## Candidate New Skills/Agents

None.

## Key Terminology

Median, Confidence Interval, Mann-Whitney U Test, Alpha, Geomean.

## Caveats

- Pseudo-versioned; pin a commit.
- [unverified] Noise level of shared CI runners; any percentage threshold such as 12%.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-16: is the skill's output shape old? | The current shape is the one above | Confirmed current shape; compare at rebuild |
| W3B-16: Go 1.24 `b.Loop` | Exists (https://go.dev/doc/go1.24) | Confirmed |
| Narrative 3: a Go benchmark reports no p99 | Not built in; custom metrics are possible | Confirmed with that qualification |
| W3B-15: noise across machines | Page advises idle machine and interleaving | Partly confirmed |
| W3B-14: can benchstat gate by itself? | No such feature documented | Confirmed by absence |
