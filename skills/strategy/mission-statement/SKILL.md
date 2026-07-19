---
name: mission-statement
description: >
  Teaches how to write a product mission statement — the present-tense declaration
  of what the product does today to move toward its vision. Covers the distinction
  between vision and mission, required components, quality criteria, and how the
  mission constrains scope decisions. Used by the product-strategist agent
  immediately after the vision statement is authored.
version: 1.1.0
phase: strategy
owner: product-strategist
created: 2026-06-24
tags: [strategy, mission, product-discovery, scope]
---

# Mission Statement

## Purpose

A mission statement answers: **what do we do, for whom, and to what end — right now?**

Where the vision describes the future state, the mission describes the present-day work that creates it. The mission changes when the approach changes. The vision changes only when the fundamental purpose changes.

The mission acts as a scope constraint. When a feature, partnership, or initiative does not serve the mission, it is out of scope regardless of how attractive it appears.

---

## Vision vs Mission — The Critical Distinction

| Dimension | Vision | Mission |
|---|---|---|
| Tense | Future | Present |
| Horizon | 3–5+ years | Current product stage |
| Question | Where are we going? | What do we do to get there? |
| Stability | Rarely changes | Evolves as strategy evolves |
| Scope effect | Defines purpose | Constrains scope |

**A common mistake:** writing a mission that is actually a vision (aspirational, future-tense, untestable today) or a vision that is actually a mission (describes current work rather than future destination).

---

## Required Components

Every mission statement must contain three elements:

| Component | Question | Guidance |
|---|---|---|
| **What we do** | What is the primary action the product performs? | Specific enough to exclude activities you will not do. |
| **For whom** | Who is the primary beneficiary? | The same target user named in the vision, possibly more specific. |
| **To what end** | What outcome does the beneficiary experience? | Measurable or at minimum observable. Must connect to the vision. |

---

## Format

```
We [verb: what we do]
for [target user]
so that [outcome the user experiences].
```

The connecting phrase "so that" is important — it forces the mission to state the beneficiary's outcome, not the product's activity.

**Example:**

> We map and classify every data asset stored across an organisation's cloud storage
> for operations and compliance teams at SMBs
> so that they can demonstrate exactly what sensitive data they hold and where it lives,
> without requiring data to move outside their infrastructure.

---

## Step-by-Step Production

1. **Start from the vision.** The mission must be the present-day execution path toward the vision. If the mission does not connect to the vision, one of them is wrong.

2. **Define the primary action.** What is the core thing the product does? Use an active verb: maps, classifies, monitors, generates, connects. Avoid passive or vague verbs: enables, helps, provides, supports.

3. **Name the beneficiary precisely.** Reuse the target user from the vision statement. If the vision covers multiple user types, the mission names the primary one.

4. **State the outcome the beneficiary experiences.** Not what the product outputs — what the user can do or know after using it. Test with: "so that they can…"

5. **Check scope constraint.** Read the mission and ask: does it exclude activities that are not core? A good mission makes it easy to say no.

6. **Check connection to vision.** If you achieve the mission at scale and over time, does it produce the vision? If not, misalignment exists.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Present tense | Describes what the product does today | Describes what it will do |
| Active verb | Starts with or contains a specific action verb | Contains "enable", "help", "support" as the primary verb |
| Beneficiary named | Specific user group | Generic ("users", "companies", "people") |
| Outcome stated | Names what the user can do or know | Describes product features or outputs only |
| Scope constraint | Reading it makes scope decisions easier | So broad any feature could be justified by it |
| Vision alignment | Executing the mission moves toward the vision | Mission could succeed while vision remains unachieved |
| Length | 1–3 sentences, ≤ 50 words | Over 50 words or multiple disconnected clauses |

---

## Anti-Patterns

**Feature list masquerading as mission:** "Our mission is to provide scanning, classification, reporting, dashboards, and alerts for enterprise data." — Lists capabilities, states no outcome.

**Indistinguishable from vision:** "Our mission is to make every organisation's data estate fully transparent and compliant." — This is aspirational and future-tense. It is a vision, not a mission.

**No scope constraint:** "Our mission is to help companies manage their data better." — Every data product on the planet could claim this.

**Internal focus:** "Our mission is to build the best data estate platform using cutting-edge AI." — Describes internal ambition, not user benefit.

---

## Output Format

```markdown
---
name: mission-statement
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: product-strategist
---

# Mission Statement

[Mission — 1–3 sentences, ≤ 50 words]

## Scope Boundary

**In scope:** [3–5 activities the mission explicitly includes]
**Out of scope:** [3–5 activities the mission explicitly excludes]

## Vision Alignment

[One sentence explaining how executing this mission moves toward the vision]
```
