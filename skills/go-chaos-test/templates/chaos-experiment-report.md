---
name: chaos-experiment-report-[YYYY-MM-DD]
version: 1.0.0
phase: quality
owner: test-strategist
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: where the run went (throwaway cluster or the statement id), each experiment's verdict, and any pattern named missing]
traces-to: [the SLO record ([SLO ids]), integration-design's inventory ([downstreams]), commit [sha], chaos statement [id] if any]
---

# Chaos Experiment Report: [product], [YYYY-MM-DD]

<!-- Path: artifacts/<product>/quality/test-reports/chaos-[YYYY-MM-DD].md, written with Write. The product owner approves
     it. Fill it from the result files the runner wrote (<E2E_RESULTS_DIR>/chaos/<experiment id>-result.json) and the
     run's evidence folder. Change no number and no verdict by hand. One report per run put forward as evidence.
     Delete this comment. -->

## Verdict

| Experiment | Pattern | Verdict | Why |
|---|---|---|---|
| [experiment id] | [pattern] | [PASS / FAIL / REFUSED / INVALID] | [the runner's reasons, verbatim] |

[One sentence: what held and what did not. Never call an INVALID or REFUSED experiment passed.]

## Where it ran

[Throwaway cluster: "The run's own kind cluster e2e-[run id], created for this run and deleted after it (run.txt: kind, Helm, kubectl, node image)."]
[Under a chaos statement: the statement printed field by field and verbatim, with "Verification only: a result about that system inside the statement's window."]

## Patterns: present, missing, as configured

| Downstream | Pattern | Present? | Settings in the product | integration-design says |
|---|---|---|---|---|
| [tides] | Circuit breaker | [yes / **missing**] | [5 consecutive, 10 s window, 5 s reset, 1 probe] | [same, or the difference] |

[Each missing pattern, named, with the corrective action for the owning build skill.]

## Each experiment

### [experiment id]

- **Hypothesis:** [verbatim]
- **Steady state:** [SLO id]: [the SLI in the SLO's words] ≥ [objective], measured over [window] s before injection: [value] over [n] requests.
- **Fault:** [tool and exact fault: toxic type and attributes, or the manifest's kind, action and selector]; confirmed active by [Toxiproxy listing / AllInjected].
- **Blast radius:** [verbatim]
- **Abort conditions:** below [sli_below] over [over_seconds] s, or [max_seconds] s in all. [Fired: when and at what value / did not fire.]
- **Result:** SLI during the fault [value] over [n] requests; [degraded answers counted, if a fault header was set]; recovered in [s] / did not recover.
- **Removal:** [verbatim from the result: verified how].
- **Pattern assertions (Go tests):** [each test and its outcome; for a FAIL, the assertion message verbatim].

## What this run does not prove

- A passing experiment shows that this fault did not break this steady state in this run; it does not prove the product reliable. A failing one shows a weakness (SRE book).
- [Every fault, size and combination not tried: e.g. "no broker outage: the product has no broker"; "one replica killed, not two"; "throwaway cluster on one node, not production's network".]
- [Anything the run could not measure: e.g. "livelock: no experiment".]

## Corrective actions

| Finding | Owner | Action | Due |
|---|---|---|---|
| [e.g. no breaker on the call to payments] | [backend-engineer, Go build skills] | [add per integration-design §4] | [date] |

## Not run or unverified

[e.g. the GitHub Actions workflow; HTTPChaos; any experiment listed in the plan but not run, with why.]

## Approval

| Role | Name | Date | Decision |
|---|---|---|---|
| Product owner | | | [Approved / Changes requested] |
