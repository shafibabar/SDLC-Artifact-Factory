# Colour Contrast and Motion-Reduction — Full Standard

Self-contained reference for `react-accessibility`. States the exact
WCAG contrast ratios this repo verifies mechanically, and the exact
`prefers-reduced-motion` handling required for any animation this app
ships.

---

## 1. Contrast Ratios — Exact Numbers

| SC | Level | Applies to | Minimum ratio |
|---|---|---|---|
| 1.4.3 Contrast (Minimum) | AA | Normal body text | 4.5:1 against its background |
| 1.4.3 Contrast (Minimum) | AA | Large text — ≥18pt (24px) regular weight, or ≥14pt (18.66px) bold | 3:1 against its background |
| 1.4.11 Non-text Contrast | AA | UI component boundaries/states (input borders, focus indicators, icon-only button glyphs) and meaningful graphical objects (chart bars/lines, icons conveying information) | 3:1 against adjacent colour(s) |
| 1.4.1 Use of Color | A | Any information conveyed by colour | Colour is never the *only* channel — pair with text, an icon, or a pattern |

`1.4.1` is not a contrast-ratio rule but belongs in this standard
because it governs the same "can a colour-blind or low-vision user
perceive this" question: a badge that passes 1.4.3's ratio but conveys
its meaning by hue alone (a green chip vs a red chip, no text) still
fails 1.4.1.

## 2. Verification

- **Automated**: `jest-axe`'s `color-contrast` rule catches 1.4.3
  text-contrast violations reliably; it does **not** reliably catch
  1.4.11 (non-text) violations — icon-only buttons, chart strokes, and
  focus-ring contrast need a manual or design-tool check.
- **Manual tools**: a contrast checker (WebAIM Contrast Checker, or a
  browser DevTools colour picker's built-in contrast readout) against
  the actual foreground/background pair, not an eyeballed guess.
- **Verify at the design-token level, not per-instance**: if this
  product's colour tokens (`--color-text`, `--color-surface`,
  `--color-warning`, …) are pre-verified as contrast-compliant pairs,
  every component built from those tokens inherits the guarantee —
  cheaper and more reliable than checking each rendered instance by
  hand. A one-off inline colour that bypasses the token set is exactly
  where 1.4.3/1.4.11 violations creep in; treat an inline colour value
  in component code as a review flag.
- **Not-colour-alone (1.4.1)** is a code-review check, not a tool
  check: does removing colour (grayscale the screenshot) still leave
  the meaning legible via text/icon/pattern? If not, it fails.

```tsx
<SensitivityBadge level="Restricted" /> // renders the word "Restricted" + colour + icon, not colour alone
```

## 3. Motion Reduction

WCAG's own success criteria on motion are narrower than the practice
this repo requires, so state the boundary precisely rather than
overclaim it:

- **2.2.2 Pause, Stop, Hide (Level A)** requires that any moving,
  blinking, or auto-updating content that starts automatically and
  lasts more than five seconds can be paused, stopped, or hidden by the
  user.
- **2.3.3 Animation from Interactions (Level AAA)** — a stricter
  criterion requiring that motion triggered by user interaction can be
  disabled, unless the animation is essential to the function — sits
  at AAA, above this repo's stated AA target.

Honouring the `prefers-reduced-motion` media query is not, therefore,
strictly mandated by the AA conformance level this repo targets — it
is adopted here as required practice anyway, because it is the
low-cost, user-controlled mechanism that satisfies both the letter of
2.2.2 and the spirit of 2.3.3 for near-zero implementation cost, for
users who have told their OS they need it. Treat any animation or
transition this app ships as needing a reduced-motion path — this is a
repo standard, applied uniformly, not a per-component judgment call.

### Implementation

```ts
// src/shared/hooks/usePrefersReducedMotion.ts
export function usePrefersReducedMotion(): boolean {
  const [reduced, setReduced] = useState(
    () => window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const onChange = () => setReduced(mq.matches);
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);
  return reduced;
}
```

```css
/* Prefer the CSS media query over JS for pure CSS transitions/animations —
   no hook, no re-render, and it also catches animations no component code
   gates explicitly. */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

The CSS media query is the default mechanism (catches every CSS
transition/animation in one place, including ones added later with no
per-component opt-in). Reach for the `usePrefersReducedMotion` hook
only when the motion is JS-driven (an imperative animation library, a
canvas/WebGL transition in `react-graph-visualization`) where CSS
can't reach it.

## 4. Verification for Motion

- `jest-axe` does not check `prefers-reduced-motion` handling —
  assert it directly: render with `window.matchMedia` mocked to report
  `reduce: true`, and assert the component renders without the
  animated variant (no `motion.div` transition props applied, or the
  CSS class that carries the transition is absent).
- Manual: toggle the OS-level "reduce motion" setting and confirm no
  non-essential animation plays.
