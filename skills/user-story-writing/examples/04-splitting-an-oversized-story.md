# Example 4 — Splitting one oversized story, pattern by pattern

Self-contained. A worked split, to read when a story fails INVEST's **Small** or **Estimable** and more than one splitting pattern seems to apply. The product is a B2B data-estate mapping platform (standard profile) that connects a company's storage sources, classifies sensitive files and reports gaps to a compliance team. Its personas are a Data Steward (P-1) and a Compliance Officer (P-2); those roles belong to this product only.

## Input

> **US-100 (draft, from the user):** "As a Data Steward, I want to connect, configure and monitor any supported storage source and scan it for sensitive data, so that our whole data estate is mapped for the audit."
>
> **Context:** supported sources are Google Drive, Amazon S3 and SharePoint. The FRD has UR-2 "a Data Steward must be able to bring a storage source under scanning" (FR-2.1 connect, FR-2.2 re-authenticate, FR-2.3 scan, FR-2.4 flag by rule) and BR-3 to BR-5, the three classification rules. Nobody on the team has used SharePoint's Graph API. The epic is EPIC-2 "Connect any supported storage source in under five minutes" (JS-2.1 "When we sign the contract, I want our sources connected the same day, so the first scan runs before the kickoff call").

## Why it fails

Three verbs (connect, configure, monitor) plus a fourth (scan); three data sources; each connector has a happy path and an expired-credential path; scanning enforces three rules; and SharePoint cannot be sized at all. It fails **Small** (dozens of conditions) and **Estimable** (no seed example can be written for SharePoint). It is an epic's worth of stories, not one.

## Step 1 — Verb before noun (house rule)

Split the compound action first: *connect*, *configure*, *monitor*, *scan*. Ask the user what "configure" and "monitor" mean. "Configure" turns out to be choosing which folders to include (part of connecting); "monitor" is seeing whether the last scan succeeded. Three verbs survive: **connect** (with folder choice), **scan**, **see scan status**.

## Step 2 — Connect, split by Data (SPIDR), happy path first

- **US-101** connect Google Drive through a guided authorisation, choosing folders *(the most common source first)*
- **US-102** connect an S3 bucket by a read-only role *(Data)*
- **US-103** connect a SharePoint site *(Data; not yet estimable, see Step 5)*
- **US-104** re-authenticate a Google Drive source whose token expired, so a failed scan resumes *(Paths split of US-101)*

## Step 3 — Scan, split by business rule, then simple before complex

- **US-105** scan a connected source and flag files matching a personal-data pattern *(BR-3)*
- **US-106** flag files shared outside the company *(BR-4)*
- **US-107** flag files older than the retention threshold *(BR-5)*
- **US-108** resume a very large scan after a mid-scan failure *(the hard case deferred; how large and how fast are NFR targets the story cites, not numbers on the card)*

## Step 4 — Status is its own small story

- **US-109** see whether each source's last scan succeeded, and why not *(the "monitor" verb)*

## Step 5 — Spike out what nobody can size

- **US-110 Spike:** how SharePoint's Graph API authorises a read-only crawler for one site. Output: a one-page decision note. **Unblocks:** US-103.

## Result

| Story | Card (abridged) | Traces to | Pattern |
|---|---|---|---|
| US-101 | As a Data Steward (P-1), I want to connect our Google Drive in a guided flow and choose its folders, so that the first scan can start without raising an IT ticket | EPIC-2 · UR-2 (FR-2.1) · JS-2.1 | Verb, then Data (most common first) |
| US-102 | …connect an S3 bucket… | EPIC-2 · UR-2 (FR-2.1) · JS-2.1 | Data |
| US-103 | …connect a SharePoint site… | EPIC-2 · UR-2 (FR-2.1) · JS-2.1 | Data (waits on US-110) |
| US-104 | …re-authorise an expired Drive connection, so that the failed scan resumes without starting over | EPIC-2 · UR-2 (FR-2.2) · JS-2.1 | Paths |
| US-105 | …flag files with personal data… | EPIC-2 · UR-2 (FR-2.3, FR-2.4) · JS-2.1 | Rules (BR-3) |
| US-106 | …flag files shared outside the company… | EPIC-2 · UR-2 (FR-2.4) · JS-2.1 | Rules (BR-4) |
| US-107 | …flag files past retention… | EPIC-2 · UR-2 (FR-2.4) · JS-2.1 | Rules (BR-5) |
| US-108 | …resume a very large scan after a failure… | EPIC-2 · UR-2 (FR-2.3) · JS-2.1 | Simple then complex |
| US-109 | …see whether each source's last scan succeeded and why not… | EPIC-2 · UR-2 (FR-2.3) · JS-2.1 | Verb |
| US-110 | Spike: SharePoint read-only authorisation | Unblocks US-103 | Spike |

One un-sizable story became nine stories and a spike. Each child is an end-to-end slice a Data Steward can see working, and each gets its own seed example and, later, its own acceptance criteria. Independence: US-101 ships first with no dependency; US-105 needs *some* connected source, which US-101 provides, recorded as an ordering note on US-105, not baked into its card.

## The splits that were rejected

| Rejected split | Why |
|---|---|
| "Build the connector framework" / "build the scanner engine" / "build the dashboard" | Layer split: none delivers anything a Data Steward can accept |
| "Connect, part 1 / part 2" | Neither half is testable alone |
| One story per customer tenant | Every tenant connects the same way; split only where behaviour or data differs |
| US-108 with "within 30 minutes for 1M files" on the card | A quality target: it belongs to `nfr-specification`, and the story cites its ID |
