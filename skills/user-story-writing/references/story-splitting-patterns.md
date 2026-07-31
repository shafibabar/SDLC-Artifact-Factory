# Story-Splitting Patterns

When a story fails **Small** or **Estimable**, it is split into INVEST-compliant
children rather than planned as-is. Splitting is a first-class, continuous
craftsmanship skill — not a fallback you reach for only once a story has already grown
too big. This reference catalogues the named patterns (drawn from Mike Cohn's *User
Stories Applied*, Cohn's later **SPIDR** framework, and Richard Lawrence's widely-cited
splitting patterns) and then walks a full worked split of an oversized repo story.

**The golden rule of a good split: every child is still a vertical slice.** A child
story must remain Independent, Valuable, and Testable on its own. Splitting by
architectural layer ("build the database story, then the API story, then the UI story")
violates this — none of those layers delivers user value alone. Split so each child
ships a thin end-to-end increment.

---

## SPIDR (Mike Cohn)

SPIDR is Cohn's mnemonic for five reliable ways to split almost any story. Try them in
roughly this order; the first that yields valuable children wins.

| Letter | Split by | When to use it |
|---|---|---|
| **S — Spikes** | A time-boxed investigation whose output is knowledge | The story is not estimable due to technical uncertainty |
| **P — Paths** | The distinct paths through the workflow | The story has a happy path plus error/alternate paths |
| **I — Interfaces** | The different interfaces or clients | The story spans several UIs, devices, or entry points |
| **D — Data** | The different data types or sources it handles | The story works across Drive / S3 / SharePoint, etc. |
| **R — Rules** | The distinct business rules it must honor | The story bundles several rules (thresholds, tiers) |

- **Spikes** — carve out the uncertainty as a separate, time-boxed spike story. Its
  deliverable is a decision or a proof of concept, not shippable software. Once it
  lands, the original story becomes estimable.
- **Paths** — the happy path becomes the first story; each alternate or error path
  becomes its own follow-on. Re-authenticating an expired token, handling a revoked
  permission, and retrying a failed scan are all separate Paths.
- **Interfaces** — if the same capability is offered through a web UI, a CLI, and an API,
  each interface is a candidate story once one of them proves the capability.
- **Data** — one story per data type or source. This is the most common split for this
  repo's connector work: "connect Google Drive" and "connect S3" are separate Data
  splits of "connect a storage source."
- **Rules** — one story per business rule. See "By Business-Rule Variation" below.

---

## By Workflow Step

If the story covers a multi-step process, split each step into its own story. A "review
and approve a data-classification change" story splits into *view the pending change*,
*add a reviewer comment*, and *approve or reject* — each independently demonstrable.

## By CRUD Operation

Cohn treats Create / Read / Update / Delete as a *specific and separate* pattern from a
generic "read vs. write" pair. When a story bundles all four operations for one entity,
split each operation into its own story:

> "Manage retention policies" → *Create a retention policy* · *View retention policies*
> · *Edit a retention policy* · *Delete a retention policy*.

Create and Read almost always deliver value first; Update and Delete often follow. This
is finer-grained than merely separating reading from writing, and it surfaces which
operations are actually needed for the increment.

## By Business-Rule Variation

When a story's behavior differs by business rule, split each rule variation into its own
story instead of writing conditional logic inside one story. For this repo: "classify a
file by sensitivity" splits by the classification rules — *flag files matching a PII
pattern*, *flag files above a size threshold*, *flag files shared externally* — each rule
an independently valuable and testable increment.

## Happy Path First

Write the basic success scenario as the first story; error and edge cases become
subsequent stories. This is the **Paths** split applied with the happy path taken first,
and it is usually the single most effective way to shrink a story: ship the case that
covers 80% of usage, defer the exceptions.

## Simple Then Complex (defer the hard part)

Split the simple/common case from the complex/rare case within one capability, shipping
the simple version first even when a stakeholder asked for the complex version by
default. "Scan a folder" ships before "scan a folder with 1M+ files and resume on
failure" — the robustness/performance hardening is deferred to its own story rather than
holding the common case hostage to the rare one.

## Split by Verb Before Noun

When a story bundles multiple actions ("connect, configure, and monitor a source"),
split by the *verb* (connect / configure / monitor) before considering finer data-based
splits. Decomposing the compound action first usually yields three cleanly valuable
stories; only then ask whether any one of them needs a further Data split.

---

## Choosing a Pattern

| The story is too big because… | Reach for |
|---|---|
| It handles many data types/sources | Data (SPIDR) |
| It has a happy path plus error paths | Happy path first / Paths (SPIDR) |
| It bundles several verbs/actions | Split by verb before noun |
| It enforces several business rules | Rules (SPIDR) / by business-rule variation |
| It is a multi-step workflow | By workflow step |
| It does all of CRUD on one entity | By CRUD operation |
| It is too uncertain to estimate | Spike (SPIDR) |
| The hard case is blocking the easy case | Simple then complex |

Most oversized stories admit several valid splits. Prefer the one whose children are
each **independently valuable** — a split that produces a child no user cares about
(e.g., a pure infrastructure slice) is the wrong split.

---

## Worked Split — an Oversized Repo Story

**Original (fails Small and Estimable):**

> **US-100:** As a Data Steward, I want to connect any supported storage source and scan
> it for sensitive data, so that our whole data estate is mapped for the SOC 2 audit.

Why it fails: "any supported storage source" spans Google Drive, S3, and SharePoint
(a **Data** axis); "connect … and scan" bundles two verbs; each connector has a happy
path plus an expired-credential path; scanning enforces several classification rules.
This is an epic, not a story — it will span multiple sprints and cannot be estimated as
one unit.

### Step 1 — Split by verb before noun

*connect* and *scan* separate cleanly:
- **US-101:** connect a storage source
- **US-102:** scan a connected source for sensitive data

### Step 2 — Split US-101 by Data (SPIDR) and take the happy path first

- **US-101a:** As a Data Steward, I want to connect our Google Drive via a guided OAuth
  flow, so that the estate scan can begin without raising an IT ticket. *(happy path)*
- **US-101b:** Connect an S3 bucket via IAM role. *(Data split)*
- **US-101c:** Connect a SharePoint site. *(Data split)*
- **US-101d:** Re-authenticate a Google Drive source whose token has expired, so a scan
  that failed on an expired token resumes. *(Paths split of US-101a)*

### Step 3 — Split US-102 by business-rule variation and simple-then-complex

- **US-102a:** Scan a connected source and flag files matching a PII pattern. *(Rule 1)*
- **US-102b:** Flag files shared externally. *(Rule 2)*
- **US-102c:** Flag files above a retention-age threshold. *(Rule 3)*
- **US-102d:** Resume a large scan (1M+ files) after a mid-scan failure. *(deferred hard
  case — simple then complex)*

### Step 4 — Spike out remaining uncertainty

If SharePoint's connector API is unfamiliar and US-101c cannot be estimated:
- **US-101c-spike:** Time-boxed investigation of the SharePoint Graph API auth model;
  output is a one-page decision note, not shippable code.

### Result

One un-estimable epic becomes nine INVEST-compliant children (plus a spike). Each is a
vertical slice a Data Steward can see working, each fits a sprint, and each carries its
own acceptance criteria. Independence check: US-101a can ship first with no dependency;
US-102a depends only on *some* source being connected, satisfied once US-101a lands —
recorded as an ordering note, not baked into the cards.
