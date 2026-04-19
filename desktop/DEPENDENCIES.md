# Desktop Dependencies

New deps added in Phase 5 (Track #99, 2026-04-18). Existing deps unchanged.

---

## Tiptap Extensions

| Package | Version | Purpose | Tracks |
|---|---|---|---|
| `@tiptap/extension-mention` | `^3.22.4` | @-mention autocomplete in editor | Advanced editor |
| `@tiptap/suggestion` | `^3.22.4` | Suggestion popup engine (required by mention) | Advanced editor |
| `@tiptap/extension-table` | `^3.22.4` | Table insertion and editing | Advanced editor |
| `@tiptap/extension-table-row` | `^3.22.4` | Table row node (required by extension-table) | Advanced editor |
| `@tiptap/extension-table-cell` | `^3.22.4` | Table cell node (required by extension-table) | Advanced editor |
| `@tiptap/extension-table-header` | `^3.22.4` | Table header node (required by extension-table) | Advanced editor |
| `@tiptap/extension-image` | `^3.22.4` | Image embed and upload support | Advanced editor |
| `@tiptap/extension-link` | `^3.22.4` | Hyperlink insertion and editing | Advanced editor |
| `@tiptap/extension-placeholder` | `^3.22.4` | Placeholder text when editor is empty | Advanced editor |
| `@tiptap/extension-typography` | `^3.22.4` | Typographic replacements (em dash, quotes, etc.) | Advanced editor |
| `@tiptap/extension-code-block-lowlight` | `^3.22.4` | Syntax-highlighted code blocks via lowlight | Advanced editor |

Note: `@tiptap/core`, `@tiptap/pm`, and `@tiptap/starter-kit` were already present.
Pins tightened from `^3` to `^3.22.4` to satisfy extension peer declarations.

---

## Supporting Libraries

| Package | Version | Purpose | Tracks |
|---|---|---|---|
| `lowlight` | `^3.3.0` | Syntax highlighting engine used by extension-code-block-lowlight | Advanced editor |
| `shiki` | `^4.0.2` | Framework-agnostic syntax highlighter for general code display (lazy-load at use site) | Code display, code blocks |
| `date-fns` | `^4.1.0` | Date arithmetic and relative formatting (e.g., "2 days ago"); `@internationalized/date` covers date-only values but not formatting | Calendar, task dates |
| `layerchart` | `^1.0.13` | Svelte 5-native chart components built on D3 primitives; replaces `recharts` (React) | Dashboard charts |
| `svelte-dnd-action` | `^0.9.69` | Svelte action for drag-and-drop lists and kanban boards; ~13 KB, no React dependency | Kanban board |
| `emoji-picker-element` | `^1.29.1` | Web component emoji picker; zero runtime deps, Apache-2.0; integrates via `<emoji-picker>` custom element | Channel reactions |

---

## Skipped / Already Covered

| Capability | Decision |
|---|---|
| Drawer / Sheet | `bits-ui` already includes Drawer — no separate install |
| Toast | Canopy has its own `ToastContainer` — skip `sonner` |
| Class variance authority | `clsx` + `tailwind-merge` already handle this pattern |
| `class-variance-authority` | Not installed — no concrete consumer beyond existing pattern |
| D3 (standalone) | `layerchart` bundles the D3 primitives it needs — no top-level `d3` install |

---

## License Summary

All new deps are MIT or Apache-2.0. No GPL-family licenses. No license review required.
