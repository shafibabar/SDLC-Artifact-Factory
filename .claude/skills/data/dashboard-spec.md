# Skill: data/dashboard-spec

## Purpose
Produce a Dashboard Specification for one persona role — the complete wireframe-level design of what the persona sees, what data is displayed, how it is arranged, and what interactions are available. Dashboard specs are the input to UI implementation and Grafana dashboard JSON.

## Inputs
- `artifacts/data/analytics-requirements.md`
- `artifacts/ideate/personas/{persona-slug}.md`
- `artifacts/design/domain/read-models/`
- `artifacts/design/ux/information-architecture.md`
- **Argument required:** persona slug (e.g. `compliance-officer`, `administrator`)

## Output
**File:** `artifacts/data/dashboards/{persona-slug}-dashboard.md`
**Registers in manifest:** yes

## Dashboard Rules (enforced)
- Every panel on the dashboard answers a specific business question from analytics-requirements.md.
- Primary metric is visible above the fold — no scrolling required for the most important number.
- Empty states are designed for every panel (no data, loading, error).
- Drill-down paths are specified: what happens when a user clicks a number or chart element.
- No raw database values in UI — all values are labelled in business language.

## Artifact Template

```markdown
# Dashboard Specification: {Persona Name}

**Product:** {product_name}
**Phase:** Data
**Artifact:** Dashboard Specification
**Persona:** {persona name and role}
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Dashboard Purpose

**Primary job:** {The JTBD this dashboard fulfils — from persona's JTBD analysis}
**Access role:** `{role_name}` and above
**Scope:** Tenant-scoped — all data filtered to authenticated user's tenant

---

## Layout: Compliance Officer Dashboard

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Compliance Posture                                    Tenant: Acme Corp │
│  Framework: [GDPR ▾]  Period: [Last 30 days ▾]    Updated: 2 min ago   │
├──────────────┬──────────────┬──────────────┬─────────────────────────── │
│  Posture     │ Open         │ Overdue      │  Files Scanned              │
│  Score       │ Findings     │ Findings     │  Coverage                   │
│              │              │              │                             │
│   82%        │   14         │    3         │   94% (1,204/1,282)        │
│  [▲ +3% wk] │  3 CRITICAL  │  > 30 days   │  Last scan: 2h ago         │
├──────────────┴──────────────┴──────────────┴───────────────────────────┤
│  Findings by Severity (bar chart — click bar → filtered findings list)  │
│  ████ CRITICAL: 3  ████████ HIGH: 8  ████████████████ MEDIUM: 24  LOW │
├─────────────────────────────────────────────────────────────────────────┤
│  Posture Score Trend — 90 days (line chart)                             │
│  100 ┤                                                             ●     │
│   80 ┤         ●─────●─────●─────●─────●─────●─────●────●─────●        │
│   60 ┤    ●─●                                                            │
│   40 ┤                                                                   │
│      └─────────────────────────────────────────────────────────────────  │
├─────────────────────────────────────────────────────────────────────────┤
│  Open Findings (table — sortable, filterable)                           │
│  Rule            │ Severity │ Entity type    │ Location │ Age   │ Action │
│  GDPR Art.5(1)(e)│ CRITICAL │ PII_NATIONAL_ID│ HR Drive │ 5d    │ Review │
│  GDPR Art.17     │ HIGH     │ PII_EMAIL      │ Sales S3 │ 12d   │ Review │
│  ...                                                             [Load more]│
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Panel Specifications

### Panel 1: Posture Score (KPI Card)
| Attribute | Value |
|-----------|-------|
| **Business question** | Q-CO-01: What is our current compliance posture score? |
| **Data source** | `compliance_posture_daily` read model |
| **Metric** | `posture_score` (0–100) for selected framework |
| **Comparison** | Week-over-week delta (▲▼) |
| **Refresh** | Every 5 minutes |
| **Drill-down** | Click → Framework detail view (rule-by-rule breakdown) |
| **Empty state** | "No data yet — scan required" |
| **Colour logic** | Green ≥ 90; Amber 70–89; Red < 70 |

---

### Panel 2: Open Findings (KPI Card)
| Attribute | Value |
|-----------|-------|
| **Business question** | Q-CO-02: How many open findings and how many are critical? |
| **Data source** | `finding_summary` read model |
| **Metrics** | Total open count; breakdown by severity |
| **Drill-down** | Click total → findings table filtered to OPEN; click CRITICAL count → filtered to CRITICAL |
| **Refresh** | Every 5 minutes |
| **Empty state** | "No open findings — your estate is clean" (positive reinforcement) |

---

### Panel 3: Overdue Findings (KPI Card)
| Attribute | Value |
|-----------|-------|
| **Business question** | Q-CO-06: Which findings have been open longest? |
| **Data source** | `finding_summary` read model |
| **Metric** | Count of findings open > 30 days |
| **Colour logic** | Red if any overdue; Green if 0 |
| **Drill-down** | Click → findings table filtered to overdue |

---

### Panel 4: Findings by Severity (Bar Chart)
| Attribute | Value |
|-----------|-------|
| **Business question** | Q-CO-02: Distribution by severity |
| **Chart type** | Horizontal bar chart (accessible; colour + label) |
| **Interaction** | Click bar → findings table filtered to that severity |
| **Accessibility** | Colour + pattern fill; values shown as numbers alongside bars |

---

### Panel 5: Posture Score Trend (Line Chart)
| Attribute | Value |
|-----------|-------|
| **Business question** | Q-CO-05: How has posture changed over 90 days? |
| **X-axis** | Date (daily points) |
| **Y-axis** | Posture score 0–100 |
| **Reference lines** | 90 (target), 70 (warning threshold) |
| **Period selector** | 7d / 30d / 90d / custom |
| **Empty state** | "Score history will appear after 7 days of data" |

---

### Panel 6: Open Findings Table
| Attribute | Value |
|-----------|-------|
| **Business question** | Q-CO-02, Q-CO-06: Which findings need attention? |
| **Columns** | Rule, Severity (badge), Entity type, Location, Age, Status, Actions |
| **Default sort** | Severity DESC, Age DESC |
| **Filtering** | By severity, framework, location, status, date range |
| **Pagination** | 25 rows; cursor-based load more |
| **Row action** | "Review" → Finding detail modal; "Acknowledge" inline |

---

## Filter Controls

| Filter | Type | Default | Affects |
|--------|------|---------|---------|
| Framework | Dropdown (single) | All | All panels |
| Period | Dropdown | Last 30 days | Trend chart, overdue calculation |
| Severity | Multi-select | All | Findings table, bar chart |

---

## Data Freshness Indicators

Every panel shows when its data was last updated:
- < 5 min: "Updated {N} min ago" (grey)
- 5–30 min: "Updated {N} min ago" (amber)
- > 30 min: "Data may be stale — last updated {N} min ago" (red)
```

## Quality Checks
- [ ] Every panel answers a specific business question from analytics-requirements.md
- [ ] Posture score is visible above the fold (no scroll required)
- [ ] Empty states defined for all panels
- [ ] Drill-down behaviour specified for all interactive panels
- [ ] Colour coding includes accessible alternative (pattern, label) — not colour alone
- [ ] Data freshness indicators are present
- [ ] All metrics use business language (not field names or database jargon)
