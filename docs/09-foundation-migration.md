> HISTORICAL EVIDENCE: This document records an earlier plan or assessment.
> It does not establish current product scope, runtime readiness, or write authority.
> Resolve current ownership through the repository root `agent-authority.json`.

# Canopy v2 — Foundation Migration Plan

**Date:** 2026-04-17
**Status:** Plan only. No code changes authorized until Roberto approves.
**Scope:** Replacing shadcn-svelte setup in `canopy/desktop/` with MIOSA Foundation patterns.

---

## 1. Foundation Inventory

### What Foundation Is (Critical Clarification)

Foundation is **not an npm package**. It is a pattern library — a SvelteKit app that runs locally and functions as a living style guide. The correct consumption model per `SETUP-GUIDE.md`:

> "You do NOT install it as an npm package. You extract CSS and HTML from the section files and paste them into your app."

There is no `@miosa-osa/foundation` on npm. The `package.json` has `"name": "@miosa-osa/foundation"` but the package is not published — it is self-referential (SvelteKit app). Git submodule or git dep installation would give you the demo app, not an importable library.

This changes the migration model entirely. See Section 3.

### Component Count and Categories

| Category | Section Count | Key Sections Relevant to Canopy |
|---|---|---|
| Foundation | 5 | Colors, Typography, Spacing, Shadows |
| Actions | 2 | Buttons (4 shape families × 8 variants × 5 sizes) |
| Inputs & Forms | 11 | Inputs, Select, Combobox, Textarea, Sliders |
| Data Display | 14 | Badges, Avatars, Cards, Tables, Accordions, Timeline |
| Navigation | 7 | Nav, Tabs, Menus, CommandPalette, Pagination, Stepper |
| Overlays | 6 | Dialogs, Drawers, Tooltips, HoverCards, Alerts, Toasts |
| Feedback | 6 | Progress, Loading, EmptyStates, ErrorStates |
| BOS Modules | 28+ | **DesktopDock, TerminalInterface, OsaAgent, AgentBuilder, SystemSettings, WorkspaceManager, ProjectManager** |
| AI | 12 | AiChat, MessageDisplay, ChatInputPatterns, Reasoning, ToolCallCards, AiAgentCards |
| Surfaces & Effects | 5 | GlassSurfaces, Animations, FloatingElements, AnimatedBorders |
| Patterns | 6 | Layouts, AuthPatterns, SettingsPatterns, FilterChips |
| Platform | 10 | UsageDashboard, BalanceCredits |
| DevOS Modules | 6 | Less relevant (CI/CD, Code Review, etc.) |

**Svelte UI primitives in `src/lib/ui/`:** 27 Bits UI-backed components exported from `index.ts` — Button, Input, Modal, Tooltip, Tabs, Menu, Select, Textarea, Slider, Toggle, Checkbox, Radio, Avatar, ScrollArea, Alert, Progress, Toast, Toaster, toast(), Accordion, Table, Breadcrumb, Separator, Skeleton, Loading, Popover, and 6 OSA-specific (PillButton, GlassCard, GradientBackground, RoundedInput, AppCard, ProgressDots).

### Token System

Foundation uses **9 hex CSS custom properties**, not HSL, not OKLCh:

```css
:root {
  --dt:   #111;      /* primary text */
  --dt2:  #555;      /* secondary text */
  --dt3:  #888;      /* tertiary text */
  --dt4:  #bbb;      /* quaternary text */
  --dbg:  #fff;      /* base background */
  --dbg2: #f5f5f5;   /* surface */
  --dbg3: #eee;      /* elevated surface */
  --dbd:  #e0e0e0;   /* primary border */
  --dbd2: #f0f0f0;   /* subtle border */
}
.dark {
  --dt:   #fff;  --dt2:  #aaa;  --dt3:  #777;  --dt4:  #555;
  --dbg:  #1a1a1a; --dbg2: #242424; --dbg3: #2e2e2e;
  --dbd:  #333;  --dbd2: #2a2a2a;
}
```

**Token name collision with Canopy:** Canopy already uses `--dt` (data-theme attribute prefix in some files). Foundation's `--dt` = "display text primary". Verify no collision before adopting Foundation names.

**Glass tokens** (additional, in `app.css`):
```css
--glass-bg: rgba(255,255,255,0.05);  --glass-border: rgba(255,255,255,0.1);
--glass-shadow: 0 8px 32px rgba(0,0,0,0.3);  --glass-blur: 20px;
```

Dark mode mechanism: Foundation uses `.dark` class on root element. Canopy currently uses `data-theme="dark"` attribute. These must be reconciled (one approach or both via CSS selector).

### Key Design Specifics

- **Buttons:** 4 shape families — `.btn-pill` (radius: 9999px), `.btn-rounded` (8px), `.btn-compact` (6px), `.btn-glass` (transparent + backdrop-filter). Classes are global utility strings, not component props — no tailwind-variants dependency.
- **Glassmorphism:** `backdrop-filter: blur(20px)` with `rgba()` backgrounds. CSS-only, zero JS.
- **Shadow focus:** Foundation uses `outline: 2px solid` for focus-visible (no box-shadow focus rings). Matches Canopy's spec exactly.
- **Monochrome palette:** The 9 tokens are gray-spectrum only. Color used only for semantic states (green success, red error, amber warning) — hardcoded in section files, not tokenized.
- **CSS Prefix System:** Every section uses a 2-3 char prefix (`dk-`, `dw-`, `tb-`, etc.) for zero-collision extraction. No Shadow DOM, no CSS modules — just plain class prefixes.

### Dependencies

Foundation's runtime deps (what gets bundled into consuming apps when patterns are extracted):

| Dep | Role | Canopy has it? |
|---|---|---|
| Bits UI `^2.14.4` | Accessible primitives for `src/lib/ui/` Svelte components | Yes (`^2.18.0`) |
| `lucide-svelte ^0.562.0` | Icons | Yes (`^1.0.1`) — **version gap** |
| `tailwindcss ^4.1.17` | Utility classes for library chrome | Yes (`^4`) |
| `tailwind-merge ^3.5.0` | Class merging util | Yes (`^3.5.0`) |
| `clsx ^2.1.1` | Class conditional util | Yes (`^2.1.1`) |
| `shiki ^3.19.0` | Syntax highlighting (AI/code sections) | Not installed |

**Dev only in Foundation:** Svelte 5, SvelteKit, vite, svelte-check, TypeScript. These are already in Canopy at matching or newer versions.

### Documentation Quality

No Storybook. Foundation is its own SvelteKit app at `localhost:5174/component-library`. Sidebar renders all sections live. Each section is a self-contained demo. No written API docs per component — the section file IS the documentation. The `CLAUDE.md`, `SETUP-GUIDE.md`, and `README.md` are agent-readable references.

---

## 2. What Canopy Has Today vs What Foundation Provides

### Side-by-Side Table

| Canopy Current | Foundation Equivalent | Match? |
|---|---|---|
| OKLCh token system (`--bg`, `--fg`, `--border`, etc.) | 9 hex custom properties (`--dt`, `--dbg`, `--dbd`) | Partial — different names, different color space, different count |
| `data-theme="dark"` dark mode switch | `.dark` class toggle on root | Conflict — needs reconciliation |
| `shadcn-svelte` button (`tailwind-variants` based) | `.btn-pill`, `.btn-rounded`, `.btn-compact`, `.btn-glass` utility classes | Replace — Foundation's is simpler and richer |
| `shadcn-svelte` Input component | Foundation `Input` UI primitive + `inputs-forms/Inputs.svelte` patterns | Replace |
| `shadcn-svelte` Dialog (multi-file: dialog.svelte + 8 sub-files) | Foundation `Modal` UI primitive + `overlays/Dialogs.svelte` patterns | Replace — Foundation is simpler |
| `shadcn-svelte` Separator | Foundation `Separator` UI primitive | Direct replacement |
| `shadcn-svelte` Tooltip (4-file compound) | Foundation `Tooltip` UI primitive | Direct replacement |
| `shadcn-svelte` Badge | Foundation `data-display/Badges.svelte` patterns (CSS only, no Svelte component) | Replace with CSS extraction |
| Canopy ThemeToggle.svelte (custom, token-based) | No Foundation equivalent | Keep as-is — it's app-specific |
| Canopy inset shell pattern (sidebar + `main`) | Foundation `DesktopDock.svelte` has dock patterns, but no direct inset shell | Keep shell CSS — not worth replacing |
| Canopy motion tokens (keyframes, easings) | Foundation has `Animations.svelte` patterns (CSS) | Partially overlap — Canopy's is more Canopy-specific |
| shadcn-svelte semantic token bridge in `app.css` (`--background`, `--foreground`, `--primary`, etc.) | Not needed with Foundation | Delete this entire bridge layer |
| `mode-watcher` npm dep | Not in Foundation | Remove — Foundation uses `.dark` class only |
| `tailwind-variants` npm dep | Not in Foundation | Remove — Foundation uses plain CSS classes |

### Canopy-Specific Gaps (Foundation Cannot Cover These)

These are app-specific to Canopy. Foundation has no pattern for them. They must be built from scratch using Foundation CSS conventions:

| Component | Why Foundation Can't Help |
|---|---|
| `LiveTerminal.svelte` | xterm.js integration — no DOM pattern maps to an xterm instance |
| `TranscriptView.svelte` | Canopy-specific union type rendering (assistant/thinking/tool_call/diff/stdout) |
| `RuntimeCard.svelte` | Canopy domain object — no generic equivalent |
| `RuntimeConfigForm.svelte` | Schema-driven form — Foundation has form patterns but not runtime-adaptive |
| `DiffReview.svelte` | File tree + diff viewer — Foundation has no diff pattern |
| `Composer.svelte` | @mention inline picker + runtime selector — no Foundation analog |
| `QuotaGauge.svelte` | Circular progress for runtime quota — Foundation has linear progress only |
| `AgentCard.svelte`, `SessionRow.svelte` | Domain-specific — extract styling from Foundation's `AgentBuilder.svelte` and `OsaAgent.svelte` sections |

**Note:** `TerminalInterface.svelte` in Foundation is CSS demo patterns (terminal chrome, tab bars, output formatting). It does NOT wrap xterm.js. It gives Canopy the visual CSS to style around an xterm instance, not the xterm integration itself.

### Overlaps — Direct Replacements Available

Foundation covers these with cleaner implementations than current shadcn-svelte setup:

- Button: Foundation's `btn-pill-*` / `btn-compact-*` replaces `tailwind-variants` approach
- Input: Foundation's `Input.svelte` primitive replaces shadcn Input
- Dialog/Modal: Foundation's `Modal.svelte` primitive replaces 9-file shadcn Dialog
- Tooltip: Foundation's `Tooltip.svelte` primitive replaces 4-file shadcn Tooltip
- Separator: Direct swap
- CommandPalette: Foundation has `CommandPalette.svelte` section — extract CSS + HTML
- Tabs: Foundation has `Tabs` primitive + `TabsSection.svelte` patterns
- Toast/Toaster: Foundation has `Toaster.svelte` + `toast()` + `Toasts.svelte` patterns

### Conflicts Requiring Resolution

1. **Token namespace collision:** Canopy's `--bg`, `--fg`, `--border` vs Foundation's `--dbg`, `--dt`, `--dbd`. Both are CSS custom properties but with different names. Strategy: keep Canopy's OKLCh tokens as the source of truth, then add Foundation's `--dt*`/`--dbg*`/`--dbd*` names as aliases pointing to Canopy's tokens. This lets Foundation patterns work without rewriting Canopy's entire token system.

2. **Dark mode mechanism:** Canopy uses `data-theme="dark"` attribute. Foundation uses `.dark` class. The shell layout and ThemeToggle need to set both — or Foundation's CSS selectors need to be adapted on extraction.

3. **Radius philosophy conflict:** Canopy's canonical radius is 8px (`--radius-lg`), with buttons at 6px (`--radius-md`). The design spec explicitly states "not pill (MIOSA)". Foundation's primary CTA button is `.btn-pill` at 9999px. For Canopy: use `.btn-rounded` (8px) as the default workhorse. Reserve `.btn-pill` for onboarding only (per Foundation's own shape decision guide). Do NOT use `.btn-pill` as the primary CTA everywhere.

4. **OKLCh vs hex:** Canopy's signal colors (green accent, amber warn, etc.) are OKLCh for perceptual uniformity. Foundation hardcodes semantic colors as hex (`#22c55e`, `#ef4444`, `#f59e0b`). These can coexist — keep Canopy's OKLCh signal tokens, Foundation's semantic hardcodes are in section demos not in primitives.

---

## 3. Migration Approach

### Installation Method: CSS/HTML Extraction (Required)

Foundation is not installable as a package. The three options from the prompt do not apply:

- **(a) npm/git dep** — Would install the SvelteKit demo app, not a library. Broken.
- **(b) pnpm workspace link** — Same problem. Foundation has no package entrypoint.
- **(c) git submodule** — Valid for reference only. Gives access to section files to extract from. Useful if you want to pull updates, but not a runtime dependency.

**Recommended approach:** Clone Foundation once as a reference repo (already at `/tmp/competitor-research/foundation/`). Extract CSS and HTML patterns by hand, section by section. For Foundation's `src/lib/ui/` Svelte primitives (Button, Input, Modal, Tooltip, etc.) — these CAN be copied directly as Svelte component files since they're Bits UI wrappers with no external Foundation-only dependency.

If version control over Foundation patterns is desired, use **git submodule** at `canopy/packages/foundation-ref/` for the reference, with a clear `README` noting it's read-only. No submodule needed at runtime.

### What to Keep, Replace, and Decide

**KEEP (no change):**
- `+layout.svelte` shell CSS (inset pattern is correct, Foundation has nothing better)
- Canopy OKLCh token files (`oklch.css`, `typography.css`, `spacing.css`, `radius.css`, `motion.css`, `terminal.css`) — these are Canopy-specific and Foundation has no OKLCh equivalent
- `ThemeToggle.svelte` — app-specific, token-correct
- All Tauri, TanStack Query, Tiptap, xterm.js dependencies
- Canopy's `data-theme` mechanism (but add `.dark` class in parallel — see Step 2 below)
- Canopy's `--accent` signal green — this is Canopy's brand color, not Foundation's

**REPLACE:**
- 6 shadcn-svelte primitive directories (`button/`, `input/`, `dialog/`, `separator/`, `tooltip/`, `badge/`) → Foundation `src/lib/ui/` component files (copy them into `src/lib/design/primitives/`)
- `app.css` shadcn bridge section (the `--background`, `--foreground`, `--primary` aliases) → replaced with Foundation token aliases pointing to Canopy's OKLCh tokens
- Button component: drop `tailwind-variants`-based `buttonVariants` → Foundation plain CSS button classes extracted into a new `src/lib/design/buttons.css`
- `mode-watcher` npm dep → remove (Foundation uses `.dark` class; handle in existing `ui.svelte.ts` store)
- `tailwind-variants` npm dep → remove (only used by shadcn button; Foundation doesn't need it)

**CREATE:**
- `src/lib/design/foundation-tokens.css` — maps Foundation's `--dt*`/`--dbg*`/`--dbd*` names to Canopy's OKLCh tokens as CSS aliases
- `src/lib/design/buttons.css` — extracted Foundation button system (all 4 shape families, all variants, all sizes) from `src/lib/styles/app.css` in Foundation
- `src/lib/design/glass.css` — Foundation glass tokens + glass surface patterns from `GlassSurfaces.svelte`

**DECIDE (see Section 6):**
- Whether to copy Foundation's `src/lib/ui/` Svelte components wholesale or maintain Canopy's own Bits UI wrappers

### Step-by-Step Execution Order

1. **Add `.dark` class support** — In `ui.svelte.ts` store and `+layout.svelte`, when setting `data-theme="dark"`, also add class `dark` to `document.documentElement`. Both mechanisms active simultaneously.

2. **Write `foundation-tokens.css`** — Map `--dt` → `var(--fg)`, `--dt2` → `var(--fg-muted)`, `--dt3` → `var(--fg-subtle)`, `--dbg` → `var(--bg)`, `--dbg2` → `var(--bg-elevated)`, `--dbg3` → `var(--bg-inset)`, `--dbd` → `var(--border)`, `--dbd2` → `var(--border)`. Import in `app.css` after OKLCh tokens.

3. **Extract Foundation button CSS** — Copy the `btn-pill-*`, `btn-rounded-*`, `btn-compact-*`, `btn-glass-*` CSS from Foundation's `src/lib/styles/app.css` into `src/lib/design/buttons.css`. Import in `app.css`.

4. **Copy Foundation `src/lib/ui/` components** — Copy the 27+ Foundation UI primitives into `src/lib/design/primitives/foundation/`. Update `$lib` index exports.

5. **Delete shadcn-svelte primitive directories** — Remove `button/`, `input/`, `dialog/`, `separator/`, `tooltip/`, `badge/` from `src/lib/design/primitives/`. Update all import paths in consuming files.

6. **Remove shadcn bridge from `app.css`** — Delete the `--background`, `--foreground`, `--primary`, `--muted`, etc. aliases. Foundation primitives use Foundation token names, not shadcn names.

7. **Remove `mode-watcher` and `tailwind-variants`** — `npm uninstall mode-watcher tailwind-variants` in `canopy/desktop/`.

8. **Extract glass tokens** — Add `--glass-bg`, `--glass-border`, `--glass-shadow`, `--glass-blur` to `src/lib/design/glass.css`. Import in `app.css`.

9. **Extract module-specific patterns** — For each Canopy screen, extract the relevant Foundation section CSS: CommandPalette, Tabs, Navigation, Toasts, Dialogs, EmptyStates, Badges, Avatars. Store in `src/lib/design/patterns/`.

10. **Update all component files** — Replace shadcn import paths with Foundation import paths. Update button markup to use Foundation CSS classes.

11. **Run tests + visual check** — All Vitest tests must pass. Dark mode visual pass. Biome lint pass.

---

## 4. Specific File List

### Files to Delete

```
canopy/desktop/src/lib/design/primitives/button/button.svelte
canopy/desktop/src/lib/design/primitives/button/index.ts
canopy/desktop/src/lib/design/primitives/input/input.svelte
canopy/desktop/src/lib/design/primitives/input/index.ts
canopy/desktop/src/lib/design/primitives/dialog/  (all 10 files)
canopy/desktop/src/lib/design/primitives/separator/separator.svelte
canopy/desktop/src/lib/design/primitives/separator/index.ts
canopy/desktop/src/lib/design/primitives/tooltip/  (all 5 files)
canopy/desktop/src/lib/design/primitives/badge/badge.svelte
canopy/desktop/src/lib/design/primitives/badge/index.ts
```

Estimated: ~20 files deleted.

### Files to Create

```
canopy/desktop/src/lib/design/foundation-tokens.css
canopy/desktop/src/lib/design/buttons.css
canopy/desktop/src/lib/design/glass.css
canopy/desktop/src/lib/design/primitives/foundation/  (copy of Foundation src/lib/ui/ — ~27 Svelte files)
canopy/desktop/src/lib/design/patterns/command-palette.css
canopy/desktop/src/lib/design/patterns/navigation.css
canopy/desktop/src/lib/design/patterns/toasts.css
canopy/desktop/src/lib/design/patterns/empty-states.css
canopy/desktop/src/lib/design/patterns/terminal-chrome.css
```

Estimated: ~40 files created.

### Files to Modify

| File | Change |
|---|---|
| `src/app.css` | Add imports for `buttons.css`, `foundation-tokens.css`, `glass.css`; delete shadcn bridge block (~40 lines) |
| `src/routes/+layout.svelte` | Add `.dark` class synchronization alongside `data-theme` attribute |
| `src/lib/stores/ui.svelte.ts` | Update `setTheme()` to toggle both `data-theme` attribute and `.dark` class |
| `src/lib/design/primitives/ThemeToggle.svelte` | No change needed |
| All route files that import from `$lib/design/primitives/button/` | Update import paths to Foundation equivalents |
| `package.json` | Remove `mode-watcher`, `tailwind-variants` |

Estimated: 5-10 route/component files with import path updates (currently minimal since routes are not fully built).

**LOC delta estimate:** -200 LOC (deleting shadcn compound files + bridge) / +600 LOC (Foundation primitives + CSS). Net: ~+400 LOC, mostly CSS utility systems.

---

## 5. Design System Alignment Check

Roberto's directives vs Foundation's reality:

| Directive | Foundation Compliance | Flag? |
|---|---|---|
| **Monochrome** | Compliant. 9 tokens are gray spectrum only. Color only for semantic states. | No flag |
| **Pill buttons** | Foundation has `.btn-pill` as its hero shape. | FLAG: Canopy design spec (`02-frontend-design.md §3`) explicitly says "Not pill (MIOSA)." There is a direct contradiction between Roberto's directive ("pill buttons") from memory feedback and the current Canopy design spec. Needs resolution. |
| **Shadow focus** | Foundation uses `outline: 2px solid` on `:focus-visible`. Matches Canopy's spec. | No flag |
| **HSL CSS vars** | Foundation uses **hex**, not HSL. The memory note says "HSL CSS vars." Foundation's vars are neither HSL nor OKLCh — they are plain hex. | FLAG: Minor. Hex and HSL are both valid. If Roberto strictly wants HSL, the 9 hex values can be expressed in HSL equivalently. More likely "HSL" in the memory note was shorthand for "not OKLCh, something simpler." Foundation's hex values are the simpler system Roberto likely meant. |
| **Foundation tokens** | Foundation's `--dt`, `--dbg`, `--dbd` naming is the token system. Canopy would add these as aliases. | No flag |
| **No blue** | Foundation's `DesktopDock.svelte` uses blue (`#3b82f6`) for some dock app icons and accent colors. The `OsaAgent.svelte` BUILD mode uses blue. These are demo data colors in section files, not the design system itself. | FLAG: When extracting specific BOS module patterns, filter out demo colors. The Foundation token system is monochrome. Only the demo data uses blue. |

**FLAG SUMMARY — requires Roberto decision before execution:**

1. **Pill vs rounded buttons:** Memory says "pill buttons" but Canopy design spec says "not pill." Which governs?
2. **Blue in BOS module demos:** Acceptable in demo patterns or strip all color from extracted CSS?

---

## 6. Open Questions for Roberto

Three questions. Just three.

1. **Pill buttons or rounded buttons as the default?** Canopy's current design spec (`02-frontend-design.md`) explicitly says "not pill (MIOSA)" and specifies 8px radius buttons. Your feedback memory says "pill buttons." These directly contradict. The answer determines which Foundation button family is the default CTA style for Canopy. Foundation supports both — just pick one as canonical.

2. **OKLCh token system: keep or replace?** Option A: Keep Canopy's OKLCh tokens as the single source of truth and add Foundation's `--dt*`/`--dbg*`/`--dbd*` names as aliases (2-line CSS per token). Canopy's signal colors (electric green, amber, etc.) remain perceptually uniform. Option B: Replace OKLCh entirely with Foundation's 9 hex tokens. Simpler, but loses the cool-tinted neutrals and perceptual precision that the "cockpit" aesthetic benefits from. Recommendation: Option A.

3. **Foundation `src/lib/ui/` primitives — copy-in or rebuild?** Foundation's Svelte primitives are Bits UI wrappers with Foundation CSS applied. Canopy also uses Bits UI. Option A: Copy Foundation's primitives wholesale (~27 files). Faster, but you're maintaining a copy. Option B: Write Canopy's own Bits UI wrappers using Foundation's CSS patterns. More work, but the code is fully Canopy-owned. Given Canopy is early-stage, Option A is faster and the divergence risk is low.

---

## 7. Effort Estimate

| Phase | Effort | Description |
|---|---|---|
| Dark mode reconciliation | 1h | Add `.dark` class alongside `data-theme` |
| Foundation token aliases | 1h | Write `foundation-tokens.css`, test all 9 tokens |
| Button system extraction | 2h | Copy CSS from Foundation `app.css`, test all 4 families |
| Glass CSS extraction | 1h | Copy from `GlassSurfaces.svelte` |
| Copy Foundation UI primitives | 2h | Copy `src/lib/ui/` files, wire imports |
| Delete shadcn primitives + fix imports | 2h | Remove 20 files, update all import sites |
| Strip shadcn bridge from `app.css` | 1h | Remove ~40 lines, verify nothing breaks |
| Extract module patterns (CommandPalette, Tabs, Nav, Toasts, EmptyStates, TerminalChrome) | 4h | Each section needs CSS extraction + scoping |
| Remove `mode-watcher` + `tailwind-variants` | 30min | `npm uninstall` + verify no usages remain |
| Test pass + visual check | 2h | Vitest + dark mode pass + Biome |

**Total: ~16-17 hours** (2 developer days).

### Blockers — Must Resolve Before Starting

1. **Roberto answers the 3 questions in Section 6.** Particularly the pill vs rounded question — it changes which button classes are used everywhere.
2. **Current build must be green.** Run `make test` to confirm no pre-existing failures. A failing test suite before migration makes it impossible to attribute failures correctly during migration.
3. **Route files must exist.** Most of the import-path updates are in route files that don't exist yet. If migration happens before routes are built, import updates are minimal (only `+layout.svelte` and any shared components). Recommend migrating now, before routes multiply.

**No dependency on backend or Tauri.** Migration is purely frontend CSS/component layer. Parallel-safe with backend work.
