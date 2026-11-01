# Example 2 (standard): 1:N scenarios, seeded partner fixtures, a Fail with workaround and re-test

Self-contained. A B2B product, two design-partner tenants, one criterion written in technical terms, and a defect found and fixed inside the UAT window.

## Input

**Product:** Ledgerly, invoicing for small wholesalers. Profile: standard. Two design partners run UAT on their canary tenants.
**Story US-7:** As a bookkeeper, I want to export the month's invoices, so that I can load them into our accounts package.

**Agreed criteria (as written in Ideate):**

```gherkin
# AC-US-7.1
Given invoices exist for March with status in ('open','paid')
When GET /exports/invoices?month=2026-03 is called
Then the CSV has one row per invoice
And each row's total_gross equals the invoice's total_gross

# AC-US-7.2
Given an invoice for March has status 'void'
When the March export is produced
Then that invoice is not in the CSV
```

## Translation notes

- `GET /exports/…` is the machinery. The bookkeeper's action is "export March's invoices" from the Exports page.
- `total_gross` is a field name. The bookkeeper sees "Total incl. VAT" on screen and in the CSV's "Total" column.
- `status in ('open','paid')` and `'void'` become named invoices the bookkeeper can find in the Invoices list.
- The two criteria are two pieces of work a bookkeeper recognises: a normal month-end export, and checking a voided invoice stays out. So: `UAT-7a`, `UAT-7b`.

## Output (one scenario shown in full; UAT-7b follows the same shape)

```markdown
### UAT-7a: Bookkeeper exports March's invoices for the accounts package

**Traces to:** AC-US-7.1
**Performed by:** bookkeeper

**Preconditions and test data** (seeded by requirements-analyst, 2026-11-09, both partner tenants):
- Harbour Foods tenant: INV-2041 €1,200.00 Paid, INV-2042 €84.50 Open, INV-2043 €310.00 Open, all dated March 2026 — confirm by: Invoices, filter March, shows exactly these three
- Same customer names and amounts seeded in the Kestrel Wholesale tenant as INV-3041–3043

**Environment:** tenant harbour-uat · eu-west · build 2026.11.4
**Flags:** `csv-export-v2` on for harbour-uat

**Context (Given):** March 2026 shows three invoices: two Open, one Paid.

**Steps (When):**
1. Open Exports.
2. Choose "Invoices", month "March 2026", and Export.
3. Open the downloaded CSV in a spreadsheet.

**Expected Outcome (Then):**
- The file has three invoice rows: INV-2041, INV-2042, INV-2043.
- Each row's Total matches "Total incl. VAT" on that invoice's page (1,200.00 / 84.50 / 310.00).

**Runs:**

| Date | Tester (role) | Result | Evidence | Defect / workaround | Re-test of | Found outside this scenario |
|---|---|---|---|---|---|---|
| 2026-11-10 | Ana Ruiz (bookkeeper, Harbour Foods) | Fail: INV-2042 total shows 84.5 in the CSV; the accounts package rejects it | rec/UAT-7a-1.mp4 | FB-14, High; workaround: fix the cell by hand before import | — | — |
| 2026-11-12 | Ana Ruiz (bookkeeper, Harbour Foods) | Pass | rec/UAT-7a-2.mp4 | FB-14 closed | 2026-11-10 | — |
```

## Why it looks like this

- **No field names, no endpoint** in the steps or outcomes, yet the rule is unchanged: one row per invoice, totals equal.
- **Look-alike data in both tenants**, so each partner runs the same work and their results are comparable.
- **The Fail has a severity, a workaround a bookkeeper can follow, and a re-run linked by `Re-test of`.** The first run line stays; the fix is proven by the second, and UAT-7b was re-checked the same day because it uses the same export.
- **The severity is the bookkeeper's impact** (the import is rejected), set at capture. Whether a still-open High would have allowed sign-off is `acceptance-sign-off`'s rule, not this file's.

## The weak first draft

```markdown
### UAT-007: Export
Steps: call GET /exports/invoices?month=2026-03, check total_gross = invoices.total_gross
Result: [x] Pass (one total formatting issue, minor)
```

An ID with no letter and the wrong form, engineering steps a bookkeeper cannot run, no named data, and a Fail recorded as a Pass with a note.
