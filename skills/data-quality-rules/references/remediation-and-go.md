# Remediation and Go — the four-path workflow at the pipeline boundary

Reference for `data-quality-rules`. Covers the remediation workflow (quarantine, auto-correct, reject-to-DLQ, alert), the `dq_quarantine` store, the auto-correct rule catalogue, reject-to-DLQ wiring, and the Go validation implementation that runs at each pipeline-stage boundary. Grounded in this repo's stack (Go + chi + pgx + PostgreSQL + Redpanda). Self-contained.

## The four remediation paths

When a record fails a data-quality rule, the gate selects exactly one *primary* path — plus an orthogonal alert signal. Collapsing these into a binary pass/fail is the central anti-pattern: the four paths have different owners, different stores, and different resolution loops.

| Path | Trigger | Store / destination | Owner | Reversible? |
|---|---|---|---|---|
| **Auto-correct** | Deterministic, lossless fix exists | corrected in place; original hash retained | Automated | n/a — lossless |
| **Quarantine** | Processed OK but result fails a quality/confidence rule; a judgment call | `dq_quarantine` table | Data Steward | yes — release or reject on review |
| **Reject** | Malformed / undecodable / hard-invariant violation | Dead Letter Queue (Redpanda topic) | Engineering | replay after root-cause fix |
| **Alert** | A rule's failure *rate* crosses a threshold (orthogonal) | `metrics-instrumentation-plan` alert | On-call / steward | n/a — signal, not a record path |

### Selection order (the decision the gate makes)

```
1. Is the input malformed / a hard invariant broken (missing tenant_id, undecodable)?
        → REJECT to DLQ.  Stop. (A steward cannot fix a broken schema.)
2. Is the failure deterministically & losslessly fixable (trim, canonicalize, dedupe)?
        → AUTO-CORRECT, then re-evaluate the corrected record from step 1.
3. Did it process OK but fail a probabilistic/quality rule (confidence < threshold)?
        → QUARANTINE for steward review. (Never auto-correct a judgment call.)
4. Independently: did this rule's failure RATE cross its alert threshold this window?
        → ALERT (in addition to whatever path 1-3 chose for the record).
```

The ordering matters: reject-checks come first (never quarantine malformed input), auto-correct before quarantine (don't send a steward something a rule can fix for free), and alert is evaluated for every record regardless of its individual path.

---

## Auto-correct rule catalogue

Auto-correct is permitted **only** for deterministic, lossless transformations — ones a reviewer would always apply the same way. The original is never discarded silently: the pre-correction `content_hash` / `raw_value` is retained for audit and lineage (`data-lineage-design`).

| Correction | Dimension it serves | Rule |
|---|---|---|
| Whitespace trim | Validity | `strings.TrimSpace` on `raw_value` before format checks |
| Case normalization | Validity / Uniqueness | lowercase an `EMAIL`'s domain part; canonical case for comparison |
| Phone canonicalization | Validity | E.164 normalization of a detected `PHONE` |
| Natural-key dedupe | Uniqueness | on `(data_asset_id, entity_type, normalized_value)` collision, keep the highest-`confidence` row, drop the rest |
| Content-hash dedupe | Uniqueness | same `(tenant_id, content_hash)` asset discovered twice → keep one, link the second's source_uri as an alias |

Never auto-correct: a confidence score, a classification level, or any value whose "fix" requires judgment. "Correcting" a probabilistic extraction manufactures wrong evidence — that is quarantine's job.

---

## The `dq_quarantine` store

Quarantine holds the **processed output** with its failed quality-check result attached — distinct from the DLQ, which holds the **original unprocessable message**. A quarantined record is not broken; it is one the pipeline correctly declined to trust unreviewed.

```sql
CREATE TABLE dq_quarantine (
  id              UUID PRIMARY KEY,
  tenant_id       UUID NOT NULL,
  data_asset_id   UUID NOT NULL,
  entity_id       UUID,                    -- nullable; set for entity-level quarantine
  dimension       TEXT NOT NULL,           -- which DAMA dimension failed
  rule_id         TEXT NOT NULL,
  failed_value    JSONB NOT NULL,          -- the processed result under review
  confidence      NUMERIC(4,3),
  reason          TEXT NOT NULL,           -- human-readable why-quarantined
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','confirmed','corrected','rejected')),
  quarantined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at     TIMESTAMPTZ,
  resolved_by     TEXT                     -- steward identity (audit / Non-Repudiation)
);
CREATE INDEX ON dq_quarantine (status, quarantined_at);   -- for age-based alerting
```

**Quarantine is alerted on age, not volume.** Some quarantine rate is normal (low-confidence extraction on scanned/degraded documents is expected). What is not normal is items sitting unreviewed too long — a steward-capacity problem. The `(status, quarantined_at)` index backs the oldest-pending query that drives `dq_quarantine_age_seconds` in `metrics-instrumentation-plan`.

**Steward resolution loop:** a steward reviews a `pending` row and sets `confirmed` (the automated result was right — release it downstream), `corrected` (fix the value, then release), or `rejected` (drop it). The confirm/correct/reject mix is itself the **steward override rate** — a model-accuracy proxy: a high `corrected` rate means the extraction model needs work, not just threshold tuning.

---

## Reject-to-DLQ wiring

A reject routes the **original** message to a Dead Letter Queue — here, a dedicated Redpanda topic per stage (`<stage>.dlq`), consistent with `data-pipeline-design`'s DLQ disposition. The DLQ is owned by engineering: a growing DLQ is a defect (a bug or an upstream format change), alerted on **volume**. Resolution is fix-root-cause-then-replay, never a steward judgment.

```
malformed / undecodable message
    → publish original bytes + failure metadata to Redpanda topic "<stage>.dlq"
    → increment dlq_depth gauge (metrics-instrumentation-plan)
    → engineer inspects, fixes root cause, replays from the DLQ topic
```

Routing a quarantine case to the DLQ (or vice versa) sends it to the wrong owner: an engineer cannot resolve "is this really an SSN," and a steward cannot fix a broken event schema.

---

## Go implementation at the pipeline boundary

The gate runs at each stage's **output**, so a downstream consumer never re-derives trust. A single `Evaluate` function encodes the selection order above. SOLID: the gate depends on a `Rule` interface, not concrete rules (Open/Closed — add a rule without touching the gate); each remediation sink is its own interface (Single Responsibility).

```go
package dq

import "context"

// Outcome is the primary remediation path chosen for one record.
type Outcome string

const (
	Pass        Outcome = "pass"
	AutoCorrect Outcome = "auto_correct"
	Quarantine  Outcome = "quarantine"
	Reject      Outcome = "reject"
)

type Record struct {
	TenantID    string
	AssetID     string
	EntityID    *string
	EntityType  string
	RawValue    string
	Normalized  string
	Confidence  float64
	Malformed   bool // set by the decoder upstream (undecodable / missing hard field)
}

// Rule evaluates one DAMA dimension against a record.
type Rule interface {
	Dimension() string
	ID() string
	Check(r Record) (ok bool, fixable bool) // fixable => a lossless auto-correct exists
	Correct(r Record) Record                // only called when Check returned fixable
}

type Sinks struct {
	Quarantine func(ctx context.Context, r Record, dim, ruleID, reason string) error
	DLQ        func(ctx context.Context, r Record, stage, reason string) error
	Emit       func(dim, ruleID, entityType string, o Outcome) // -> dq_gate_outcomes ledger
}

// Evaluate applies the four-path selection order for one record at a stage boundary.
func Evaluate(ctx context.Context, stage string, r Record, rules []Rule, s Sinks) (Record, Outcome, error) {
	// 1. Malformed / hard-invariant -> REJECT to DLQ. Never quarantine.
	if r.Malformed || r.TenantID == "" {
		if err := s.DLQ(ctx, r, stage, "malformed or missing tenant_id"); err != nil {
			return r, Reject, err
		}
		s.Emit("integrity", "hard_invariant", r.EntityType, Reject)
		return r, Reject, nil
	}

	for _, rule := range rules {
		ok, fixable := rule.Check(r)
		if ok {
			continue
		}
		// 2. Deterministic lossless fix -> AUTO-CORRECT, then re-check this rule.
		if fixable {
			r = rule.Correct(r) // original raw_value retained upstream for lineage/audit
			if ok2, _ := rule.Check(r); ok2 {
				s.Emit(rule.Dimension(), rule.ID(), r.EntityType, AutoCorrect)
				continue
			}
		}
		// 3. Processed OK but fails a probabilistic/quality rule -> QUARANTINE.
		reason := rule.Dimension() + " rule " + rule.ID() + " failed"
		if err := s.Quarantine(ctx, r, rule.Dimension(), rule.ID(), reason); err != nil {
			return r, Quarantine, err
		}
		s.Emit(rule.Dimension(), rule.ID(), r.EntityType, Quarantine)
		return r, Quarantine, nil
	}

	s.Emit("all", "gate", r.EntityType, Pass)
	return r, Pass, nil // 4. ALERT is evaluated separately off the emitted ledger, per-rule-rate.
}
```

A confidence-threshold rule (the accuracy dimension) is never `fixable` — it can only pass or quarantine, enforcing "never auto-correct a judgment call":

```go
type ConfidenceRule struct {
	thresholds map[string]float64 // entity_type -> min confidence (loaded from config table)
}

func (c ConfidenceRule) Dimension() string { return "accuracy" }
func (c ConfidenceRule) ID() string        { return "confidence_threshold" }

func (c ConfidenceRule) Check(r Record) (ok, fixable bool) {
	min, known := c.thresholds[r.EntityType]
	if !known {
		min = 0.85 // conservative default for an unknown type
	}
	return r.Confidence >= min, false // never fixable: a score is a judgment, not a format
}
func (c ConfidenceRule) Correct(r Record) Record { return r } // never invoked
```

### TDD note

Per this repo's TDD discipline, the gate's test file is written first: table-driven cases asserting that a malformed record rejects (never quarantines), a below-threshold `SSN` quarantines (never auto-corrects), a whitespace-padded email auto-corrects then passes, and a natural-key duplicate dedupes. Each case asserts both the returned `Outcome` and that the correct sink was called exactly once.

## Summary

Four paths, one selection order: reject malformed input to the DLQ first; auto-correct only deterministic lossless failures; quarantine probabilistic judgment calls to the `dq_quarantine` table for a steward; alert on failure rate independently. DLQ is engineering-owned and alerted on volume; quarantine is steward-owned and alerted on age. The Go gate runs at each stage boundary, depends on a `Rule` interface (Open/Closed), and emits every outcome to the ledger that `dq-metrics-and-scorecard.md` scores.
