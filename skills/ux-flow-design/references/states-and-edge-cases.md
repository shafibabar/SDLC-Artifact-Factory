# Screen/State Inventory, and Designing Error, Edge & Empty States — Reference

Comprehensive reference for the screen/state inventory method, the full canonical
state set every screen must design for, the discipline of designing error, edge,
and empty states explicitly, and a fully worked flow for this product (a Data
Steward classifying an estate) showing the happy path plus its empty-estate,
ingestion-failure, and permission-denied branches.

The `SKILL.md` body states the mandate. This file is the method and the worked
example.

---

## 1. Why a Screen Is Never One Thing

A flow that names a screen once — `[ Estate list ]` — has told the
`frontend-engineer` almost nothing about what to build, because "the estate list"
is really a family of states: the version while data loads, the version with no
data, the version when the fetch fails, the version with some data and some still
loading, and the fully populated version. Each is a distinct thing to build,
distinct copy to write, and a distinct branch a flow can route to. Under-specify
the set and the missing states get invented in production, inconsistently, by
whoever hits them first.

The **screen/state inventory** is the artifact that forces the full set to be
named before any screen is designed. It is produced *before* individual flows, and
the flows then route to states drawn from it.

---

## 2. The Canonical State Set — the Five UI States

Every screen that shows fetched or user-generated data must design for the five UI
states popularized by Scott Hurff ("The 5 states you need to design for"). Naming
them explicitly is how omissions become visible:

| State | Also called | Screen shows | Design obligation |
|---|---|---|---|
| **Blank state** | Empty state | No data exists yet | A message + an actionable CTA into the flow that populates it — never a bare blank screen |
| **Loading state** | — | Data is being fetched | A determinate or indeterminate progress indicator; skeletons for known layout |
| **Partial state** | Incomplete | Some data present, some pending/failed | Show what loaded; clearly mark what is still coming or what failed, per item |
| **Error state** | — | The fetch or action failed | A plain-language cause + a recovery action (retry / correct / signposted exit) |
| **Ideal state** | Full / success state | Fully populated, everything worked | The design most mockups only ever show — the *least* risky of the five |

The trap Hurff names: teams design the **ideal state** first and treat the other
four as afterthoughts, when the blank, partial, and error states are where users
actually get stuck. The inventory inverts that — you enumerate all five per screen
and justify any you deliberately omit (e.g. a screen that can never be empty).

### Deriving the states for a screen

For each screen in the flows, ask five questions:

1. **Blank** — can this screen have zero items? (A new tenant's estate: yes.)
2. **Loading** — does it fetch async? (Almost always: yes.)
3. **Partial** — can it show some items while others load or fail? (A multi-source
   estate where one source's ingestion failed: yes.)
4. **Error** — can the fetch itself fail entirely? (Yes.)
5. **Ideal** — what does "everything worked" look like?

Any "yes" is a state that goes in the inventory and becomes a routable node in the
flows.

---

## 3. Blank / Empty States Are Not Errors

The most common state mistake in this product's flows is routing an **empty**
condition to an **error** screen. A brand-new tenant whose estate has not been
scanned yet has *no data assets* — that is a valid, expected, first-use state, not
a failure. Routing it to "Something went wrong" tells a new customer their product
is broken on day one.

Rules for a blank/empty state:

- **Never a bare blank screen.** Always a message and a next action.
- **The CTA leads somewhere actionable** — into the flow that ends the emptiness.
  For an empty estate: "Connect a data source to start mapping your estate" →
  Connect-Source flow.
- **Plain language, no jargon** — Shafi's reviewers and real Data Stewards read
  this, not engineers.
- **Distinguish first-use empty from filtered-empty.** "No assets yet" (connect a
  source) is a different state, with different copy and CTA, from "No assets match
  this filter" (clear the filter). Both are blank states; they are not the same
  node.

---

## 4. Error States Must Recover

An error branch that dead-ends is a flow-design failure, not a copywriting one.
Every error state ends in exactly one of three things:

- a **retry** (transient faults — 5xx, network) — ideally with backoff, and an
  escalation path if it keeps failing;
- a **corrective action** (recoverable input problems — 422) — the user fixes
  something and resubmits, usually a loop back to the input screen;
- a **signposted exit** (unrecoverable in-context — 403, gone-404) — the user is
  told plainly what happened and where to go next (who can grant access; back to
  the list).

"Something went wrong" with no next step fails all three. Map each API outcome from
`references/flow-notation-and-types.md` §3 to one of these three recovery shapes.

---

## 5. Edge States — Valid but Unusual

Beyond the five UI states, enumerate the business-rule edges that are valid but
easy to forget:

- **First-use** — the very first time through, before any data or settings exist.
- **Single-item** — a list with exactly one row (does the bulk toolbar still make
  sense? does "select all" appear?).
- **Maximum limits** — the estate with 10,000 assets (pagination, virtualization,
  the "showing 100 of 10,000" state).
- **Stale** — data loaded, then invalidated by a background event (a scan finished
  after the page rendered) — offer a refresh, don't silently diverge.

Each edge that applies becomes a state in the inventory.

---

## 6. Worked Flow — Data Steward Classifies an Estate

This is the full artifact for one job, showing the happy path and three non-happy
branches drawn from the state set above. Personas: **Data Steward** (owns
classification of the estate) and, downstream, the **Compliance Officer** (reads
the resulting gap posture). Notation per `references/flow-notation-and-types.md`.

**Job:** JS-002 — classify the assets in a connected estate.
**Entry points:** Estate tree row → "Classify"; Asset detail header → "Classify".
**Preconditions:** authenticated (valid JWT); at least one source connected.
**Exit points:** success (assets classified); permission-denied (signposted);
empty-estate (routed to Connect-Source); abandon (Cancel discards draft).

### 6.1 Happy path (ideal state throughout)

```
(( Start: estate-browser remote — Estate tree ))
  → < GET /v1/estate?tenantId >
  → { estate contents? }
  ↳ has assets → [ Estate tree — ideal state, assets listed ]
       → ( Data Steward selects an asset )
       → [ Asset detail ]
       → ( Clicks "Classify" )
       ⟿ HAND-OFF → classification remote  (assetId, tenantId; re-check data-assets:classify)
       → [ Classify modal — ideal state ]
       → ( Selects sensitivity: Public / Internal / Confidential / Restricted )
       → ( Saves )
       → < PATCH /v1/data-assets/{assetId}/classification >
       → { API response? }
       ↳ 200 → [ Classify modal closes; asset row shows new badge ]
             (( End: asset classified ))
```

### 6.2 Empty-estate branch (blank state — NOT an error)

Reached when the tenant has connected no source, or a scan has not yet produced
any assets. This is first-use, not failure:

```
  ↳ no assets → [ Estate tree — blank state ]
       Headline: "No data assets yet"
       Body: "Connect a data source to start mapping your estate."
       CTA: "Connect a source" → (( goto: Connect-Source flow ))
```

Distinguish from filtered-empty: if the Data Steward has applied a filter that
matches nothing, that is a *different* blank state — "No assets match this filter"
with a "Clear filter" CTA — not the first-use one.

### 6.3 Ingestion-failure branch (partial + error states)

An estate is assembled from multiple sources (Google Drive, S3, uploaded
PDF/DOCX/XLSX). One source's ingestion can fail while others succeed — a **partial
state**, not a total error:

```
  ↳ has some assets, one source failed → [ Estate tree — partial state ]
       Shows: assets from Drive + S3 (loaded)
       Marks: "S3 bucket 'archive': ingestion failed" banner on the affected group
       Per-source recovery: ( Retry this source ) → < POST /v1/sources/{id}/rescan >
       Rest of estate remains classifiable while the failed source retries.
```

If *every* source failed (total fetch error, not partial):

```
  ↳ estate fetch failed entirely → [ Estate tree — error state ]
       Cause (plain): "We couldn't load your estate."
       Recovery: ( Retry )  → loops to < GET /v1/estate >
                 with backoff; after N failures, signpost support.
```

### 6.4 Permission-denied branch (signposted exit)

The Data Steward can browse but lacks `data-assets:classify` (a Compliance Officer
may hold classify rights this Steward does not, or vice versa, under
Attribute-Based Access Control). The classification remote re-checks server-side —
UI gating in the estate-browser remote is never trusted across the seam:

```
       → < PATCH /v1/data-assets/{assetId}/classification >
       → { API response? }
       ↳ 403 Forbidden → [ Classify modal — permission-denied state ]
             Cause: "You don't have permission to classify assets."
             Signpost: "Ask a Compliance Officer to classify, or request the
                        data-assets:classify capability from your tenant admin."
             Exit: ( Close ) → back to Asset detail (no change)
```

Note this 403 lives *inside* the classification remote, after the hand-off — the
estate-browser remote may pre-emptively hide the Classify action for known-unprivileged
users, but the flow still specifies the 403 path because the permission is
authoritative only server-side.

### 6.5 Session-expired and concurrent-change branches

Complete the flow by mapping the remaining canonical API outcomes:

- **401** (JWT expired mid-classification): re-authenticate, then resume at the
  Classify modal with the draft sensitivity preserved where feasible.
- **409** (another user classified this asset first): show the refreshed
  classification; ask the Data Steward to confirm overwrite or abandon.
- **422** (somehow-invalid level): inline error in the modal; loop back for
  correction.

---

## 7. Inventory Output Shape

The screen/state inventory for the job above, as a table the `frontend-engineer`
builds against:

| Screen | Remote | Blank | Loading | Partial | Error | Ideal | Edge states |
|---|---|---|---|---|---|---|---|
| Estate tree | estate-browser | first-use + filtered-empty | yes | one-source-failed | total-fetch-fail | assets listed | 10k-asset limit; stale-after-scan |
| Asset detail | estate-browser | n/a | yes | — | not-found (404) | detail shown | deleted-since-list |
| Classify modal | classification | n/a | on save | — | 401/403/409/422/5xx | saved + badge | concurrent-edit (409) |
| Gap view | compliance | no-reports-yet | yes | report-generating | fetch-fail | gaps shown | — |

The inventory is complete when every screen a flow touches has an explicit
decision (state or "n/a with reason") for all five UI states plus its applicable
edges.
