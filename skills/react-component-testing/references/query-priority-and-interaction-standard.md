# Query-Priority and Interaction Standard

Self-contained reference for `react-component-testing`. Two related standards live here: the exact order in which a test must attempt to find an element, and why `@testing-library/user-event` is the required interaction API rather than `fireEvent`. Both exist for the same underlying reason — a test that can only pass by reaching past the accessibility tree or past real browser event sequencing is a test that has stopped proving anything about the actual user experience.

---

## The Query-Priority Order, and Why Each Rung Exists

Testing Library exposes many ways to find an element. They are not interchangeable alternatives to pick by taste — they form a strict priority order, because each rung down the list proves a weaker claim about what a real user (specifically, a user of assistive technology) can actually do with the rendered UI:

| Priority | Query | What a pass proves | What a failure means |
|---|---|---|---|
| 1 | `getByRole` (with `name`) | An assistive-technology user can find this element by its role and accessible name — the strongest possible signal, because the accessibility tree is exactly what a screen reader consumes | The element has no role, or no accessible name, reachable the way AT reaches it |
| 2 | `getByLabelText` | A form field has a real programmatic label a screen reader announces on focus | The field relies on a placeholder or visual-only label |
| 3 | `getByPlaceholderText` / `getByText` | The element exists and shows the right non-interactive content, but proves nothing about interactivity or labelling | N/A — these are for static content, not controls |
| Last resort | `getByTestId` | Only that an element with that attribute exists in the DOM — proves nothing about whether *any* user, sighted or not, can find or operate it | N/A — reaching for this is itself the finding |

The order is not a style preference; it is ordered by evidentiary strength about accessibility. `getByRole` succeeding is direct proof a screen reader can locate and name the control. `getByTestId` succeeding proves only that a string attribute is present in the rendered markup — a `<div data-testid="save-button">` with no role, no keyboard handler, and no accessible name passes a `getByTestId` query while being completely invisible to a screen reader and unusable from a keyboard. A test suite that reaches for `getByTestId` as its default query can reach 100% "passing" while shipping a UI a meaningful fraction of users cannot operate at all.

```tsx
// ✅ getByRole — proves an AT user can find and name this control
screen.getByRole("button", { name: /classify/i });
screen.getByRole("combobox", { name: /sensitivity level/i });

// ✅ getByLabelText — proves the field has a real label, not a placeholder
screen.getByLabelText(/sensitivity level/i);

// ⚠️ getByText — fine for static content, proves nothing about interactivity
screen.getByText(/3 assets selected/i);

// ❌ getByTestId — last resort only; if you reach for this, fix the component first
screen.getByTestId("save-button");
```

**When `getByTestId` is legitimate:** a genuinely un-queryable element with no role, label, or stable text — a canvas-rendered graph node, a decorative wrapper `div` used only for a CSS Grid placement hook that carries no user-facing semantics at all. Even then, treat its presence as a prompt to ask whether the underlying markup should be fixed (a `role="img"` with an accessible name, an `aria-label` on the wrapper) rather than as a comfortable default.

This ordering is the same discipline `react-accessibility`'s Testing Accessibility section states from the accessibility side: "if a test can't find an element by its accessible name, neither can a screen reader" — query priority and WCAG 4.1.2 (Name, Role, Value) conformance are the same check performed from two directions.

---

## `user-event` vs `fireEvent`: Why Realistic Simulation Wins

`fireEvent` (from `@testing-library/react`) dispatches exactly the one DOM event you name — `fireEvent.change(input, { target: { value: "Confidential" } })` fires a single synthetic `change` event and nothing else. `@testing-library/user-event` simulates the **full sequence of events a real browser produces** for that interaction — typing into a field fires `pointerdown` → `mousedown` → `focus` → `keydown` → `keypress` → `input` → `keyup` for every character, in order; clicking a button fires `pointerdown` → `mousedown` → `focus` → `pointerup` → `mouseup` → `click`.

This is not a stylistic preference. Any component logic that depends on one of the intermediate events — an `onKeyDown` handler that intercepts `Enter` to submit a form, an `onFocus` handler that opens a combobox's listbox, a `mousedown`-based drag-start — is invisible to `fireEvent` and only exercised by `user-event`. A test written with `fireEvent.change` can report green while the component's real keyboard handling is completely broken, because `fireEvent` never triggered the code path that handles it.

```tsx
// Component under test: submits on Enter, not just on blur.
function ClassificationInput({ onSubmit }: { onSubmit: (v: string) => void }) {
  const [value, setValue] = useState("");
  return (
    <input
      aria-label="Sensitivity level"
      value={value}
      onChange={(e) => setValue(e.target.value)}
      onKeyDown={(e) => { if (e.key === "Enter") onSubmit(value); }}
    />
  );
}

// ❌ fireEvent — never dispatches keydown, so onSubmit is never proven to fire
fireEvent.change(screen.getByLabelText(/sensitivity level/i), { target: { value: "Confidential" } });
// onSubmit was never called; this test cannot catch a broken Enter-to-submit handler.

// ✅ user-event — types character-by-character, firing real keydown/keyup,
// then Enter, exactly as a physical keyboard would
const user = userEvent.setup();
await user.type(screen.getByLabelText(/sensitivity level/i), "Confidential{Enter}");
expect(onSubmit).toHaveBeenCalledWith("Confidential");
```

A second, equally important reason: `user-event` respects **disabled and pointer-events state** the way a real browser does — `user.click()` on a `disabled` button or one covered by another element throws, exactly as a real click would fail silently or hit the wrong target. `fireEvent.click` bypasses all of that and fires the handler regardless, which can mask a genuinely broken disabled-state implementation.

**Standard:** every interaction in a component test goes through `userEvent.setup()` and its methods (`.click`, `.type`, `.tab`, `.selectOptions`, `.keyboard`, `.hover`). `fireEvent` is reserved for the rare case of dispatching an event `user-event` has no method for (a custom DOM event a third-party widget emits) — never as the default interaction mechanism.
