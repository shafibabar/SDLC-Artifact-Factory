# The Dead Letter Queue Standard — Topic Naming, Retry-Count Header, and the Unchanged Envelope

Full worked material referenced from `SKILL.md`'s "Retry with Backoff, then DLQ"
section. Self-contained — reads without the parent body already in context. Covers:
the exact `<topic>.dlq` naming convention, the exact `x-retry-count` header
convention, why the original envelope is forwarded byte-for-byte unchanged with
failure metadata carried only in headers, and what a DLQ message must never lose.

---

## 1. Why a Dead Letter Queue, and Not Infinite Retry or a Silent Drop

A record can fail for two structurally different reasons: it is **undecodable**
(a schema violation, a corrupt payload — retrying changes nothing, since the bytes
never become decodable) or it is **decodable but the work keeps failing** after
`SKILL.md`'s `withRetry` exhausts its bounded attempts (a downstream
dependency is down, a business-rule violation that will not self-resolve). Both cases
share one property: continuing to retry blocks the partition's head — every record
behind the stuck one waits, since offsets commit in order (`references/offset-commit-standard.md`).
The **Dead Letter Queue (DLQ)** is the release valve: route the failing record
somewhere durable and monitored, and let the partition keep moving.

---

## 2. DLQ Topic Naming: `<topic>.dlq`, Exactly

```go
func dlqTopic(sourceTopic string) string {
    return sourceTopic + ".dlq"
}
```

One DLQ topic per source topic — `data-asset.classified` routes to
`data-asset.classified.dlq`, `pii-scan.completed` routes to `pii-scan.completed.dlq`.
**Never one shared DLQ topic across multiple source topics.** A shared DLQ forces
every downstream consumer of failed messages (an alerting job, a manual-replay
tool, an operator's inspection query) to filter by embedded metadata to find the
messages it cares about, and makes DLQ depth — the alerting metric this standard
exists partly to enable (§4) — ambiguous: a depth alarm on a shared topic cannot say
which source topic is actually failing without opening messages. The `<topic>.dlq`
suffix keeps that answer in the topic name itself.

---

## 3. The `x-retry-count` Header, Exactly

```go
func (c *Consumer) toDLQ(ctx context.Context, rec *kgo.Record, cause error, attempts int) {
    dlqRec := &kgo.Record{
        Topic: dlqTopic(rec.Topic),
        Key:   rec.Key,   // preserves the original partition key (usually tenant_id) for DLQ ordering/inspection
        Value: rec.Value, // the original envelope bytes, byte-for-byte unchanged — see §4
        Headers: append(append([]kgo.RecordHeader{}, rec.Headers...), // original headers preserved (incl. trace context)
            kgo.RecordHeader{Key: "x-retry-count", Value: []byte(strconv.Itoa(attempts))},
            kgo.RecordHeader{Key: "x-failure-reason", Value: []byte(truncate(cause.Error(), 2048))},
            kgo.RecordHeader{Key: "x-original-topic", Value: []byte(rec.Topic)},
            kgo.RecordHeader{Key: "x-original-partition", Value: []byte(strconv.Itoa(int(rec.Partition)))},
            kgo.RecordHeader{Key: "x-original-offset", Value: []byte(strconv.FormatInt(rec.Offset, 10))},
            kgo.RecordHeader{Key: "x-failed-at", Value: []byte(time.Now().UTC().Format(time.RFC3339))},
        ),
    }
    if err := c.producer.ProduceSync(ctx, dlqRec).FirstErr(); err != nil {
        slog.ErrorContext(ctx, "DLQ produce failed", "topic", dlqRec.Topic, "err", err) // last resort: log; do not retry the DLQ send itself
    }
}
```

**`x-retry-count`'s value is the number of attempts `withRetry` actually made before
giving up** — `0` for a record that never entered the retry loop at all (an
undecodable payload fails at the decode step, before any attempt), `c.maxAttempts`
for a record that exhausted every retry. This is the count set **once**, at the
moment a record is forwarded to the DLQ — it is not a value that increments while
sitting in Redpanda, because a message on a topic is immutable (`Immutable Events`)
and Redpanda has no mechanism to rewrite a header on an already-published record.
If a human operator later replays a DLQ message back onto its original topic as a
manual remediation step (a separate, deliberate operational action, not an automatic
requeue this standard performs), and that replay fails again, the *next* DLQ push for
that manually-replayed record carries a **new**, independently-computed `x-retry-count`
reflecting only the attempts made during that specific redelivery — it is not summed
with the header value from the earlier DLQ message. Any tooling that needs a
cumulative failure count across multiple manual replays must compute it by reading
every DLQ message for that `event_id`, not by trusting a single header to have
accumulated across pushes it was never present for.

---

## 4. The Envelope Forwarded Unchanged, Failure Metadata Only in Headers

**`Value: rec.Value` copies the original record's bytes through untouched — never
re-decoded, re-marshalled, or reshaped.** Two reasons this is not optional:

- **An undecodable record has no other representation.** If decoding is what failed,
  the raw bytes are the *only* thing that can be preserved at all — there is no
  decoded struct to re-marshal from.
- **Re-marshalling a JSON payload that *did* decode successfully is not
  guaranteed to reproduce byte-identical output** (map key ordering, numeric
  formatting, and whitespace are all marshaller-dependent) even when the logical
  content is unchanged. A DLQ message exists partly as a forensic record of exactly
  what was received; re-serializing it introduces a needless, avoidable discrepancy
  between "what the consumer saw" and "what's on the DLQ topic for a human to inspect."

Failure metadata (`x-retry-count`, `x-failure-reason`, and the rest of §3's headers)
is carried **only** in Redpanda record headers, never merged into the payload body.
This keeps the DLQ record's `Value` decodable by the exact same envelope schema
(`event-schema-design`) as the original topic — a reprocessing tool can attempt to
decode a DLQ message's `Value` with the same decoder it uses for the live topic,
falling back to headers only for the failure-specific metadata it doesn't need for
that decode.

**Original headers are preserved, not replaced** — `append(append([]kgo.RecordHeader{}, rec.Headers...), ...)`
carries the original W3C trace-context headers through, so a trace that ends at a
DLQ push is still the *same* trace the record's producer started, not a disconnected
one. This is the DLQ-specific instance of `SKILL.md`'s "Continue the trace" rule.

---

## 5. DLQ Depth Is an Alerting Metric, Not a Silent Sink

A DLQ that nobody watches is a slower, quieter version of dropping the message. DLQ
depth (`consumer lag`-equivalent for the DLQ topic itself) belongs on the same
dashboard as consumer lag and is the signal that turns "a record failed once" into
an actionable incident — the specific alerting-threshold and on-call routing design
is `alerting-rules-design`'s concern, not this skill's; this standard's obligation
ends at guaranteeing every DLQ'd record carries enough information (§3, §4) for
whatever monitors that depth to act on it.
