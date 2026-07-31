# Knaflic Techniques — Choosing the Visual, Decluttering, and Focusing Attention

This reference expands Lessons 2–5 of Cole Nussbaumer Knaflic's *Storytelling with Data* into the
concrete rules a data-engineer applies when building an explanatory visual for a data story. Every
rule here is a design decision made once, at authoring time, since this repo's Data-phase artifacts
have no live "watch where their eyes go" feedback loop.

---

## Lesson 2 — Choose an Effective Visual (the message → chart mapping)

Choose the chart **from the message**, never the message from an impressive chart. "Chart-first"
thinking — picking a sophisticated-looking chart and reverse-engineering data into it — produces
charts that obscure the point.

| The message you need to land | Chart | Avoid | Why |
|---|---|---|---|
| "It is one number, in context" | Simple bold **text** / single stat with baseline or target | Gauge / speedometer | One number does not need a coordinate system; text is read instantly |
| "X changed over time" | **Line** (or area) | A bar per period | The eye reads slope as trend; bars fragment the shape |
| "X compares across categories" | **Bar**, sorted by value | Pie / donut, radar | Length is compared far more accurately than angle or area |
| "X breaks into parts" | **Stacked bar** (or a short number list if exact values matter) | Pie with >3–4 slices | Angle comparison across many slices is a weak perceptual task |
| "X relates to Y" | **Scatter** | Dual-axis line with mismatched scales | Dual axes fabricate a visual correlation the data may not support |
| "Here is the spread" | **Histogram** or box plot | A single averaged bar | An average hides the distribution the story may be about |

**Never, as a matter of course:** pie charts, donut charts, 3D effects, and secondary (dual) y-axes.
These are policy defaults, not case-by-case judgments — Knaflic bans them because each systematically
distorts or slows perception.

**The five-second test.** Could someone unfamiliar with the underlying query state the message
correctly from the chart alone, in under five seconds? If not, either the chart type is wrong or you
do not yet have a single message — return to the Insight step before designing anything.

### Grounding in this repo's stack

The reporting side of this platform runs OLAP on PostgreSQL. A story's chart is nearly always backed
by one aggregate query. Keep the query shaped like the message:

```sql
-- Message: "classification coverage rose each week last quarter" -> a LINE over time.
-- One row per week, one measure. Nothing extra to declutter later.
SELECT date_trunc('week', classified_at) AS week,
       count(*) FILTER (WHERE classification IS NOT NULL)::numeric
         / count(*) AS coverage_ratio
FROM   assets
WHERE  classified_at >= now() - interval '13 weeks'
GROUP  BY 1
ORDER  BY 1;
```

If the query returns more columns than the message needs, you are pulling exploratory data into an
explanatory visual — trim the SELECT, not the chart afterwards.

---

## Lesson 3 — Eliminate Clutter

Clutter is any visual element that costs the eye attention but carries no information. Every clutter
element makes the message harder to find. Run this pass on **every** finished visual, and justify
anything you keep rather than justifying removal:

| Clutter element | Default action |
|---|---|
| Gridlines | Remove, or mute to the faintest gray if a few reference lines genuinely aid reading |
| Chart border / plot box | Remove — whitespace already bounds the plot (Gestalt *enclosure*) |
| Data markers on every point of a dense line | Remove; mark only the point(s) the message is about |
| Legend, when there are few series | Remove and **label the lines directly** at their right end |
| Redundant axis titles / repeated units | Remove; state the unit once |
| Excess decimal precision | Round to what the sample supports (e.g. "74%" not "73.6127%") |
| 3D, shadows, gradients, background fills | Remove entirely |
| Diagonal / rotated axis labels | Rotate the chart to horizontal bars so labels read straight |

### The Gestalt principles behind decluttering

Decluttering is not minimalism for its own sake — it works because human visual perception *already*
groups elements, so redundant grouping marks can be removed. Knaflic leans on six Gestalt principles:

- **Proximity** — elements placed near each other are read as a group. Use whitespace to group; you
  rarely need dividers.
- **Similarity** — elements sharing color or shape are read as one set. This is what lets a single
  accent color define "the important series."
- **Enclosure** — a boundary implies a set. A plot border is therefore usually *redundant* because the
  chart area is already enclosed by whitespace — remove it.
- **Closure** — the eye completes a partial shape, so full borders and gridlines are often unnecessary;
  the axes alone imply the frame.
- **Continuity** — the eye follows the smoothest path; aligned elements read as related, so alignment
  replaces literal separators.
- **Connection** — a line connecting elements binds them more strongly than shared color or size; this
  is why line charts read as continuous change.

The practical rule: **let existing perceptual structure do the grouping, then delete the marks that
were doing it redundantly and expensively.**

---

## Lesson 4 — Focus Attention with Preattentive Attributes

Certain visual properties are processed by the visual system *before* conscious attention — meaning
they draw the eye to an element before the viewer reads a single word. Knaflic's key preattentive
attributes for charts are **color (hue), size, position, and enclosure**.

The signature technique:

> Keep almost everything in a muted, low-contrast base color (typically **gray**), and spend a single
> deliberate **accent color** only on the one data point or series that carries the message.

**Contrast used everywhere draws attention nowhere; contrast used once is unmistakable.** A chart
where every series has its own bright color forces the viewer to hunt for the point. A chart that is
gray except for the one line the story is about *hands* them the point.

Applied ranking of the attributes for directing the eye:

| Attribute | Use it to say | Example in a data story |
|---|---|---|
| **Color / hue** | "look here first" | The one week where coverage crossed the SLA line, in accent; all other weeks gray |
| **Size** | "this is bigger / more important" | The headline number set large; supporting numbers small |
| **Position** | "read this first" | Top-left placement of the takeaway (Western reading order) |
| **Enclosure** | "these belong together" | A faint box around the two bars being compared |

Spend at most one or two of these per visual. Every additional emphasis competes with the others.

---

## Lesson 5 — Think Like a Designer

Four lenses to apply to any finished visual (Knaflic's "four A's"):

- **Affordances** — the visual should look like what it does. Things meant to be compared should be
  visually adjacent; a clickable element should look different from a static one; emphasis should sit
  on what matters, not decoration.
- **Accessibility** — do not encode meaning in color alone. Roughly 1 in 12 men has a color-vision
  deficiency; pair the accent color with position, a direct label, or a shape so the message survives
  in grayscale. Keep text/background contrast high.
- **Aesthetics** — a visually considered chart is trusted and read more carefully than a sloppy one,
  all else equal. Alignment, consistent spacing, and restraint buy credibility.
- **Acceptance** — an audience used to dense default charts may resist a lean redesign. Sometimes you
  build buy-in by iterating toward the cleaner style over several reviews rather than shipping a
  radical redesign in one step.

---

## Worked Before / After

**Before (exploratory density presented as explanatory):** a multicolor line chart of extraction
confidence for *seven* source types over 90 days, full gridlines, a plot border, a legend of seven
entries the viewer must map back to seven similarly-bright lines, y-axis labeled to two decimals, a
generic title "Extraction Confidence by Source." The viewer cannot tell what they are meant to
conclude — every line competes equally, nothing is emphasized.

**After (one message, decluttered, focused):**

- Reduced to the **one** series that carries the message — PDF sources — with the six others either
  removed or collapsed into a single muted "all other sources" band for context.
- **Line chart** (change over time), gridlines removed, plot border removed, legend removed and the
  PDF line **labeled directly** at its right end.
- The PDF line is the single **accent color**; the context band is gray. Preattentive color does the
  work the legend used to do.
- A **marker and annotation** on the week the new customer's scanned-PDF estate began ingesting —
  size and position draw the eye to the cause.
- Y-axis rounded to whole percentages; title replaced with the **takeaway**: "PDF extraction
  confidence dropped 17 points after a scanned-PDF-heavy estate began ingesting."

The After version passes the five-second test; the Before version fails it. The data behind both is
identical — only the explanatory design changed. See `references/worked-data-story.md` for the full
narrative this After visual sits inside, and `references/narrative-and-annotation.md` for how the
takeaway title and annotation are written.
