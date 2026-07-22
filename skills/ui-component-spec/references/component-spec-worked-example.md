# Component Spec Worked Example: ClassificationModal

A full worked example of a **Local** (fragment-specific) component spec,
demonstrating every section of the format at once. Self-contained —
loadable without reading `SKILL.md` first. For the equivalent example of a
**Shared** component's spec, see `references/shared-component-contract.md`'s
`SensitivityBadge` example.

---

```
Component: ClassificationModal
Level: Organism
Scope: Local (apps/data-assets)
Domain mapping: ClassifyDataAsset command
Owned by: frontend-engineer
```

**Props:**

| Prop | Type | Required | Default | Description |
|---|---|---|---|---|
| `assetId` | `string` | Yes | — | UUID of the asset to classify |
| `assetName` | `string` | Yes | — | Display name shown in modal title |
| `currentLevel` | `SensitivityLevel \| null` | No | `null` | Pre-selects current classification |
| `onSuccess` | `(level: SensitivityLevel) => void` | Yes | — | Called after successful classification |
| `onClose` | `() => void` | Yes | — | Called when modal is dismissed |

**State variants:**

| State | Visual | Behaviour |
|---|---|---|
| Open (no selection) | Sensitivity options shown; Save disabled | User must select a level before saving |
| Open (selection made) | Chosen option highlighted; Save enabled | User can save |
| Saving | Save button shows spinner; form fields disabled | API call in progress |
| Success | Modal closes; parent list updates | `onSuccess` callback fires |
| Error (API) | Error banner below form; form re-enabled | User can retry |
| Error (validation) | Inline error under sensitivity selector | Shown before API call if level missing |

**Interactions:**

| Interaction | Response |
|---|---|
| Select sensitivity level | Radio button selected; Save button enabled |
| Click Save | POST to API; show saving state |
| Click Cancel | `onClose()` called; no API call |
| Press Escape | `onClose()` called |
| Click overlay | `onClose()` called |

**Accessibility:**

- `role="dialog"` with `aria-modal="true"` and `aria-labelledby` pointing
  to modal title
- Focus trapped within modal while open
- Focus moves to first radio button when modal opens
- Focus returns to "Classify" trigger button when modal closes

**Dependency note:** this Local Organism's sensitivity options use the
Shared `SensitivityBadge` atom (`references/shared-component-contract.md`)
for the visual treatment of each option — the modal itself owns the
classification workflow (fragment-specific), while the badge's visual
representation of a sensitivity level is shared across every fragment that
displays one.
