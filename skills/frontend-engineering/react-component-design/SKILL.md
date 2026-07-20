---
name: react-component-design
description: >
  Teaches how to design React components from the ux-architect's component specs —
  single-responsibility components, composition over prop-drilling (children,
  slots, compound components, render props), custom hooks to extract logic,
  presentational/container separation, the Atomic Design taxonomy, and controlled
  vs uncontrolled patterns. Implements the ux-architect’s ui-component-spec in
  React + TypeScript. Used by the frontend-engineer during Implement.
version: 1.1.0
phase: implement
owner: frontend-engineer
created: 2026-06-25
tags: [implement, frontend, react, components, composition, custom-hooks, atomic-design]
---

# React Component Design

## Purpose

A component is a single, well-named visual responsibility. Good component design keeps each one small, composable, and testable by behaviour — so the UI grows by combining pieces rather than by inflating God-components with ever more props. This skill turns the ux-architect's `ui-component-spec` into React + TypeScript components that match the specified props, states, and interactions exactly.

The component spec is the contract; this skill implements it. If a spec is ambiguous, raise it to the ux-architect — the spec is updated, not guessed (see the handoff in the ux-architect AGENT).

---

## Implement to the Spec

Each `ui-component-spec` defines props, state variants, interactions, and accessibility. The implementation realises all of them — every state, not just the happy one.

```tsx
// from ui-component-spec: DataAssetTable (Organism) → DataAssetListView Read Model
interface DataAssetTableProps {
  readonly assets: ReadonlyArray<DataAsset>;
  readonly isLoading: boolean;
  readonly error: AppError | null;
  readonly onClassify: (id: string) => void;
}

export function DataAssetTable({ assets, isLoading, error, onClassify }: DataAssetTableProps) {
  if (isLoading) return <TableSkeleton rows={10} />;        // Loading state (spec)
  if (error)     return <ErrorBanner error={error} />;       // Error state (spec)
  if (assets.length === 0) return <DataAssetEmptyState />;    // Empty state (spec)
  return (
    <table aria-label="Data assets">                         {/* a11y from spec */}
      <tbody>
        {assets.map((a) => (
          <DataAssetRow key={a.id} asset={a} onClassify={onClassify} />
        ))}
      </tbody>
    </table>
  );
}
```

Every state variant from the spec maps to a render path; every interaction maps to a handler. (These same states become the test cases — see `react-component-testing`.)

---

## Atomic Design Taxonomy

Mirror the spec's taxonomy so the code structure matches the design language:

| Level | Lives in | Example |
|---|---|---|
| Atom | `shared/ui/` | `Button`, `SensitivityBadge`, `Input` |
| Molecule | `shared/ui/` or feature | `SearchBar`, `FormField` |
| Organism | feature `components/` | `DataAssetTable`, `ClassificationModal` |
| Template | feature / `app/` | `DetailPageLayout` |
| Page | feature (route element) | `DataAssetListPage` |

Atoms/molecules are app-agnostic and shared; organisms and pages belong to their feature.

---

## Composition Over Prop-Drilling

When a prop is threaded through several layers only to reach a deep child, that is prop-drilling — a smell. Solve it by composition, not by more props.

### Children and slots
Pass rendered UI in, instead of passing data down to be rendered.

```tsx
// Instead of <Card title titleIcon actions bodyData ... > (prop explosion),
// compose with slots:
<Card>
  <Card.Header icon={<ShieldIcon />}>Compliance</Card.Header>
  <Card.Body><GapSummary tenantId={tenantId} /></Card.Body>
</Card>
```

### Compound components
Related components share implicit state via a small, feature-private context — the API stays declarative.

```tsx
<Tabs defaultValue="assets">
  <Tabs.List>
    <Tabs.Trigger value="assets">Assets</Tabs.Trigger>
    <Tabs.Trigger value="lineage">Lineage</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Panel value="assets"><DataAssetTable …/></Tabs.Panel>
</Tabs>
```

### Render props / function-as-child
For reusable behaviour with caller-controlled rendering (a virtualiser, a data boundary).

**Note on Context:** Context solves prop-drilling for *low-frequency, widely-read* values (theme, current user, tenant). It is **not** a state manager — overusing it causes re-render storms (see `react-state-management` and `react-performance-optimization`).

---

## Custom Hooks — Extract Logic from Markup

A component should read like a description of the UI. Move non-trivial logic (data fetching, derived state, effects, event wiring) into a custom hook so the component body stays declarative and the logic is independently testable.

```tsx
// feature hook: encapsulates the classify workflow (mutation + optimistic update + toast)
function useClassifyDataAsset(assetId: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ level, idempotencyKey }: { level: SensitivityLevel; idempotencyKey: string }) =>
      api.classifyDataAsset(assetId, level, idempotencyKey),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["data-assets"] }),
  });
}

// the component just declares intent:
function ClassificationModal({ assetId, onClose }: ClassificationModalProps) {
  const classify = useClassifyDataAsset(assetId);
  // …render; on submit: classify.mutate({ level, idempotencyKey: crypto.randomUUID() })
  // The key lives in the mutation variables — generated once per user intent, so a
  // TanStack Query retry re-runs mutationFn with the SAME variables and the same key.
}
```

Rules for hooks: name them `useX`; one responsibility each; return a stable, typed object; follow the Rules of Hooks (top level, not in conditionals).

---

## Presentational vs Container

- **Presentational** components take data + callbacks via props, render UI, hold no server state. They are trivially testable and reusable (most `shared/ui` atoms/molecules).
- **Container** components (usually a page or feature organism) wire data (via hooks/`react-api-client`) to presentational children.

Keep the split clean: a presentational component never calls the network; a container delegates rendering to presentational children.

---

## Controlled vs Uncontrolled

- **Controlled** inputs (value + onChange) when the parent needs the value live (validation, dependent fields) — the default for forms tied to app state.
- **Uncontrolled** (refs / `defaultValue`) for simple, write-once inputs where live value isn't needed — fewer re-renders.
- For complex forms, use a form library (React Hook Form) that keeps inputs uncontrolled under the hood for performance while exposing a controlled-feeling API.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Implements the spec | Every spec state/interaction/a11y realised | Only the happy path built |
| Single responsibility | Small, well-named components | God-components with dozens of props |
| Composition | children/slots/compound over prop-drilling | Props threaded through many layers |
| Logic in hooks | Non-trivial logic extracted to `useX` | Fetching/effects tangled in markup |
| Presentational/container split | Presentational components network-free | Atoms calling the API |
| Context not abused | Context for low-frequency values only | Context as a state manager (re-render storms) |

---

## Anti-Patterns

- **The God-component** — one component owning fetch, transform, filter state, modal state, and three render modes behind boolean props. Split by responsibility; compose.
- **Boolean-prop proliferation** — `<Table compact bordered selectable withActions>` multiplies variants combinatorially. Prefer slots/compound components, or a single typed `variant` union.
- **Prop-drilling past two layers** — a prop that a component only forwards is a composition failure; pass rendered children instead of raw data.
- **`React.FC`** — obscures the props type, historically implied `children`, and adds nothing over a plain typed function. Type the props interface; write a plain function.
- **Logic in markup** — `useEffect` chains and fetch orchestration inline in the component body. Extract to a named `useX` hook; the component reads as UI.
- **Conditional hooks** — calling a hook inside `if`/`map`/early-return breaks the Rules of Hooks. All hooks at top level, unconditionally; branch *after*.
- **Guessing at ambiguous specs** — inventing a state the `ui-component-spec` doesn't define. The spec is updated first, then implemented.

---

## Output Format

Produces React + TypeScript components and their behaviour tests (written first):

```
src/shared/ui/*.tsx                       (atoms/molecules)
src/features/<feature>/components/*.tsx    (organisms)
src/features/<feature>/hooks/use*.ts       (custom hooks)
*.test.tsx                                 (React Testing Library; written first)
```
