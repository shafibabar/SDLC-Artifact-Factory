# The Signed Chaos Statement

Self-contained. Copy when a fault must go to any system other than the run's own throwaway cluster: a designated environment, staging, production, a tenant's environment. Without it, signed and current, the runner refuses and injects nothing. It is drafted by `test-strategist` and signed by the product owner, once per experiment window; there is no standing statement (no standing production chaos). Each refusal below was run on 2026-11-28 with nothing injected.

Only Toxiproxy faults run under a statement: Chaos Mesh (a privileged daemon) and in-process Go tests are refused outside the throwaway cluster, whatever the statement says. The Toxiproxy instance between the product and the dependency on that system is set up by `platform-engineer` and named in the statement.

### `tests/chaos/statements/verify-tides-latency-staging-2026-12.json`

```json
{
 "statement_id": "verify-tides-latency-staging-2026-12",
 "product": "harbour-pilots",
 "base_url": "https://api.staging.harbour.example",
 "toxiproxy_api": "https://toxiproxy.staging.harbour.example",
 "purpose": "verify that the tide-window fallback of release 3.4 holds on staging's network when the tide tables answer late",
 "blast_radius": "calls from harbour to tides on staging, through the tides proxy only; no other service, no other proxy",
 "faults": [
  {"tool": "toxiproxy", "proxy": "tides", "type": "latency", "max_attributes": {"latency": 2000, "jitter": 200}}
 ],
 "abort": {"sli_below": 0.9, "over_seconds": 10, "max_seconds": 120},
 "impact": {
  "other_users": "testers on staging see stale tide windows for up to two minutes",
  "other_teams": "pilot-app team, told on 2026-11-27; they pause their staging tests in the window",
  "dependent_systems": "none: only harbour calls tides",
  "third_parties": "none: no third party is behind the tides proxy",
  "data": "none written; the probe only reads tide windows",
  "cost": "none: staging is already running"
 },
 "how_to_stop": "Ctrl-C in the runner's terminal (it removes the toxic and verifies), or DELETE the toxic on the Toxiproxy API",
 "watched_by": "test-strategist at the terminal and the staging on-call",
 "window_start": "2026-12-03T09:00:00Z",
 "window_end": "2026-12-03T10:00:00Z",
 "marker": "served",
 "approved_by": "Product owner",
 "approved_on": "2026-11-28",
 "expires_on": "2026-12-03"
}
```

| Field | Rule | Refused when (run) |
|---|---|---|
| `statement_id` | A name. Where the system serves the marker, `GET <base_url>/.well-known/chaos-statement` answers `{"statement_id": "<this id>"}` | `serves statement "someone-else"` |
| `base_url`, `toxiproxy_api` | Exactly where: scheme, host, port, nothing after; `https` unless on this machine | `must be https unless it is on this machine` |
| `purpose` | What is verified. A statement is never a standing licence | missing |
| `blast_radius` | What the fault may touch, in words | missing |
| `faults` | Each allowed fault: `tool` (`toxiproxy`), `proxy`, toxic `type`, and the largest value of each attribute | `does not allow a timeout toxic on proxy "tides"`; `latency (5000) exceeds what the chaos statement allows (2000)` |
| `abort` | The abort conditions signed; the experiment's may only be stricter, and its length no longer than `max_seconds` | `abort conditions are looser than the ones the chaos statement was signed with` |
| `impact` | Other users, other teams, dependent systems, third parties, data, cost; `none` where nothing | `has no impact.other_teams` |
| `how_to_stop`, `watched_by` | How it is stopped; who watches | missing |
| `window_start`, `window_end` | Date-times with a time zone; the whole run (steady state, fault, recovery, plus a minute) must fit | `would not fit inside the statement's window` |
| `marker` | `served`, or `cannot be served: <why>` for a system nobody here can change; only that one check is then skipped | missing marker: `does not serve the chaos statement marker` |
| `approved_by`, `approved_on` | The product owner's name and date of sign-off; empty, a placeholder or a future date is refused | `has no approved_by: it carries no product-owner sign-off` |
| `expires_on` or `single_use_run_id` | At least one; a single-use statement runs only when `CHAOS_RUN_ID` equals it | `expired on`; `neither expires_on nor single_use_run_id`; `for run "run-77" only` |

Run with `make chaos-verify EXPERIMENT=tests/chaos/experiments/<id>.json STATEMENT=tests/chaos/statements/<id>.json`. The runner records the statement verbatim in the result, and the report prints it. The file is committed; it holds no secret (a Toxiproxy token, if the API requires one, is given for the run in `TOXIPROXY_AUTH_TOKEN`).

Seen accepted (2026-11-28): a statement naming the lab product and a real Toxiproxy v2.13.0 on loopback, `marker: "cannot be served: ..."`: PASS, the toxic removed and verified; the same statement against a product with no fallback: aborted at an SLI of 0.000, FAIL, the toxic removed.
