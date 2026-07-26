# Chart Library Selection and Accessibility Standard

Self-contained reference for `react-dashboard-components`. Deepens the
SKILL.md body's text/table-alternative requirement into an exact,
checkable standard, and states the exact criteria for choosing between
Recharts and visx.

---

## 1. Chart Library Selection

| Library | Choose when | Cost |
|---|---|---|
| **Recharts** (default) | The chart is a standard type — bar, stacked bar, line, area, grouped bar (the SKILL.md body's question→chart-type table) | Declarative React components over SVG; ships reasonable default markup Recharts itself renders, but the text/table alternative in §2 is still required regardless — Recharts does not generate one for you |
| **visx** | The visual is genuinely bespoke — a shape or layout no standard chart type expresses (a custom sparkline glyph, a layered composite visual the ux-architect's spec specifically calls for) | Lower-level, d3-based; no chart-level component to lean on for markup or interaction defaults — the team hand-builds every accessibility affordance in §2, not just the data-table alternative |

Library choice is downstream of the question→chart-type decision the
SKILL.md body already makes (distribution → bar, trend → line, and so
on) — never the reverse. Never choose visx for visual polish alone; its
cost (hand-built accessibility, hand-built interaction) is paid on every
bespoke chart, so it must be earned by a real requirement Recharts's
catalog can't express.

## 2. The Text/Table Alternative — Exact Standard

**Trigger:** every chart, no exceptions. A two-bar comparison is not
"too simple to need one" — the standard does not carve out a size or
complexity exemption.

**Content requirement:** the alternative must contain **the same data
points the chart visualizes** — same categories/series, same values, same
units — not a placeholder message. "Chart data unavailable as text" or an
unlabeled `<img>`-style fallback fails this standard; it must be possible
to read every value the chart shows from the alternative alone.

**Structure requirement:** a real `<table>` — `<caption>` naming what the
chart shows, `<th scope="col">` for each series, `<th scope="row">` for
each category — never a `<div role="grid">` reproduction (see `react-
accessibility`'s semantic-first rule; the same native-element-first
reasoning that governs data tables governs this alternative table). It
must be reachable via a screen reader's table-navigation commands (row/
column announcement, header association) — not merely present somewhere
in the DOM. A visually-hidden (`sr-only`) table that is real markup
satisfies this; an `aria-hidden` or `display:none` table does not, because
`display:none` also removes it from the accessibility tree.

**Placement pattern** (either is acceptable; pick one and apply it
consistently across the dashboard):

```tsx
// Pattern A — always-present, visually-hidden table alongside the visual chart
<figure aria-label="Compliance gaps by framework, open count per framework">
  <figcaption>Open compliance gaps by framework</figcaption>
  <ResponsiveContainer width="100%" height={280}>
    <BarChart data={gapsByFramework}>
      <XAxis dataKey="framework" /><YAxis allowDecimals={false} />
      <Tooltip /><Legend />
      <Bar dataKey="open" name="Open gaps" fill="var(--color-warning)" />
    </BarChart>
  </ResponsiveContainer>
  <table className="sr-only">
    <caption>Open compliance gaps by framework — table view</caption>
    <thead><tr><th scope="col">Framework</th><th scope="col">Open gaps</th></tr></thead>
    <tbody>
      {gapsByFramework.map((row) => (
        <tr key={row.framework}><th scope="row">{row.framework}</th><td>{row.open}</td></tr>
      ))}
    </tbody>
  </table>
</figure>

// Pattern B — a "View as table" toggle switching the same data between renderings
<ChartOrTable data={gapsByFramework} view={view} onViewChange={setView} />
// `view` is a discriminated union ("chart" | "table"), never two booleans —
// see react-component-design's discriminated-union prop standard.
```

Pattern A costs nothing extra for the user (both are always available);
Pattern B is preferable when the table would be genuinely large (see the
virtualization threshold in `references/data-density-and-virtualization-
standard.md`) and rendering both at once is wasteful. Never permanently
hide the table with no toggle and no `sr-only` equivalent — that is a
data point a screen-reader user cannot reach at all.

**`aria-label` requirement:** the chart's container names what it shows
in one sentence — `aria-label="Compliance gaps by framework, open count
per framework"`, not `aria-label="Bar chart"`. A label describing the
chart type but not its content fails this standard.

**Colour requirement:** series are distinguished by direct label,
pattern, or position — never colour alone (WCAG 1.4.1, `react-
accessibility`'s not-colour-alone rule) — and colour contrast for chart
graphic elements meets the 3:1 non-text minimum (WCAG 1.4.11, same
skill). A legend that relies on colour swatches with no series name next
to each fails both this standard and `react-accessibility`'s.

## 3. Data Storytelling Still Applies to the Alternative

The SKILL.md body's data-storytelling rule (order by value, not
alphabetically, unless order is meaningful) applies identically to the
table alternative — the table is not exempt from the ordering the chart
itself uses. A chart sorted by severity next to a table sorted
alphabetically presents two different stories from the same data.
