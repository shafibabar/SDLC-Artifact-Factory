# Chart-Selection Guide (Knaflic)

Reference material for `dashboard-specification`. Grounded in Cole Nussbaumer
Knaflic, *Storytelling with Data*
(`research/data-and-analytics/storytelling-with-data-knaflic.md`). This guide covers
**which chart type answers which metric question**, the decluttering pass, the
preattentive-attribute emphasis technique, and the chart forms to never specify.

Scope reminder: this skill specifies the chart **type** and its **emphasis intent**
(what the eye should land on first, and why). Exact hex colour, font family, grid
placement, and animation belong to `ui-component-spec` / `react-dashboard-components`.
"Use one accent colour" is a *type/emphasis* decision and belongs here; "the accent
is `#C0392B`" is a styling decision and does not.

---

## The core rule

Knaflic's test for every visual is: **does this chart make the point easy to see?** —
not "does it look impressive." Chart selection is driven by *what the metric needs to
show*, never by what looks sophisticated. Match the form to the question first; make
it pretty second (and elsewhere).

---

## Chart-type selection by question

| The metric's question is… | Prescribed chart | Why |
|---|---|---|
| One number that stands alone ("77% coverage") | **Single number / big text** | When there is one number to convey, plain text/a single big number communicates it faster than any chart; a chart wraps a lone number in needless ink. |
| Change of one/few series over time | **Line chart** | The eye reads slope as rate of change; a line makes trend direction and inflection immediate. |
| Comparison across categories | **Bar chart** | Length along a common baseline is compared far more accurately by the visual system than angle or area — the reason pie/donut lose to bars. |
| Ranked categories, long labels | **Horizontal bar, sorted by value** | Horizontal accommodates long category names without rotated text; sorting by value turns the chart itself into the ranking. |
| One metric across categories at two points in time (e.g. "coverage per Bounded Context, this quarter vs last") | **Slopegraph** | Two aligned vertical axes with a connecting line per category; the slope of each line shows which categories rose, fell, or held — a before/after comparison a grouped bar chart makes far harder to read. |
| Precise values across many dimensions | **Table** | When the audience needs to look up exact figures rather than perceive a shape, a well-formatted table (right-aligned numbers, minimal borders) beats any chart. |
| Two related measures over the same categories | **Two side-by-side bar/line panels**, not a dual-axis chart | Separate panels keep each measure honestly scaled; a shared second axis fabricates a correlation the data may not support. |

When a widget's question does not map cleanly to a row above, restate the question
more sharply — an ambiguous chart choice almost always means the metric question is
still ambiguous.

---

## What to NEVER specify

Knaflic rejects these as a matter of course, not case-by-case:

- **Pie charts and donut charts.** Humans compare length accurately and angle/area
  poorly; anything beyond two or three slices becomes guesswork. Use a bar chart.
- **3D effects (3D bars, 3D pie, drop shadows on data).** The added dimension carries
  no information and distorts apparent values — a back bar looks shorter than an equal
  front bar. Flat, always.
- **Dual-axis charts.** Two different Y-axes on one plot invite the reader to see a
  correlation that is an artifact of how the axes were scaled. Split into two panels.
- **Secondary/decorative charts with no question.** If a widget does not answer a
  question a viewer would act on, it is a vanity widget (see
  `references/widget-metric-definitions.md`) regardless of how it is drawn.

---

## The decluttering pass (Gestalt)

Every specified chart type carries an implicit instruction to the implementer: remove
visual elements that cost attention but add no information. Knaflic grounds *why*
removal works in Gestalt principles of perception, so declutter is not minimalism for
its own sake — it is letting existing perceptual structure do the grouping work so the
redundant elements can go.

| Gestalt principle | What it means | Decluttering consequence |
|---|---|---|
| **Proximity** | Elements placed near each other are perceived as related | Use whitespace to group; drop dividing lines/boxes between related items |
| **Similarity** | Shared colour/shape reads as one group | Colour a series once; a legend becomes unnecessary if you label directly |
| **Enclosure** | A boundary implies a set | Whitespace already encloses — the chart border is usually redundant |
| **Closure** | The eye completes a partial shape | Full gridlines/borders are often unneeded; the eye infers them |
| **Continuity / Connection** | The eye follows lines and links | A connecting line groups points more strongly than a shared colour |

Declutter checklist to attach to any specified chart (the implementer applies it):

- Remove chart borders and heavy gridlines; keep at most faint reference gridlines.
- Remove data markers on every point of a dense line; keep markers only where a value
  is called out.
- Replace a legend with **direct labels** on the series wherever the space allows.
- Strip excess decimal precision ("76.83%" → "77%") unless precision is the point.
- Remove redundant titles/axis labels that repeat what a direct label already says.

Rule of thumb: **justify anything kept, not anything removed.**

---

## Preattentive attributes — drawing the eye

Certain visual properties — **colour (hue), size, position, and enclosure** — are
processed *before* conscious attention, so they can steer the eye to a specific
element before the viewer reads a word. Knaflic's signature technique:

> Keep almost everything in a muted, low-contrast base (typically gray), and use a
> single deliberate accent hue only on the data the viewer should look at first.

Consequence for a spec: **contrast used everywhere draws attention nowhere; contrast
used once is unmistakable.** So a chart-type spec should state the **emphasis intent**
— *which* element the accent marks and *why* — not the colour value:

```
Chart type: horizontal bar, sorted by value
Emphasis intent: the single bar for the Bounded Context that breached its
  coverage target is the accent element; all other bars are the muted base.
  Rationale: the viewer's decision is "which context to escalate," so the eye
  should land on the breaching context first.
(Exact accent hue: ui-component-spec's call, subject to its accessible palette.)
```

Preattentive attributes to reach for, in rough priority: **position** (top/left reads
first), **hue** (one accent), **size** (bigger = more important). Reserve them for the
message; do not spend them on chrome.

---

## Accessibility and the "so what"

- **Accessibility is a type-level constraint, not just styling.** Never encode meaning
  in hue alone — an accent must be reinforced by position, a label, or size so a
  colour-vision-deficient viewer still reads it. State this in the emphasis intent.
- **State the takeaway on explanatory widgets.** A chart that shows data without
  stating what to conclude has not communicated. For an explanatory widget, the spec's
  **Intended takeaway** field is the "so what" the annotation/target-line must carry.
  Exploratory monitoring widgets are exempt — the user derives their own takeaway by
  filtering.

---

## Worked selections for this repo

| Metric question | Chart | Emphasis intent |
|---|---|---|
| "What is my estate's classification coverage right now?" | Single number (%) | The number itself; a target line if below target |
| "Is Restricted content growing faster than review?" | Line, two series (Restricted count, reviewed count) over time | Accent the Restricted line; direct-label both, no legend |
| "Coverage per Bounded Context, this quarter vs last" | Slopegraph | Accent contexts whose slope fell |
| "Open compliance gaps by framework control" | Horizontal bar, sorted by open-gap count | Accent the top (most-gaps) bar |
| "Ingestion throughput over the last 24h" | Line | Accent the segment where throughput dropped below SLO |
| "Exact open gaps with asset, opened-at, owner" | Table | Right-align counts/timestamps; no accent (lookup, not perception) |

Each selection is a *type + emphasis* decision this skill owns; the palette, spacing,
and component behaviour that render it belong to the ux-architect and frontend-engineer.
