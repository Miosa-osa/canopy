# NOTICE

Canopy (desktop) — © 2026 Roberto H. Luna / MIOSA. Licensed under Apache 2.0.

## First-Party Components

### MIOSA Foundation

- Source: https://github.com/Miosa-osa/foundation
- License: First-party MIOSA repository — same ownership as Canopy. No separate
  license required. Attribution recorded here for provenance.
- Commit: a6f26df (April 2026)
- Copied components (verbatim, in `desktop/src/lib/design/foundation/`):
  - 27 Svelte 5 UI primitives: Button, Input, Modal, Tooltip, Separator, Tabs,
    Menu, Select, Textarea, Slider, Toggle, Checkbox, Radio, Avatar, ScrollArea,
    Alert, Progress, Toast/Toaster, Table, Breadcrumb, Accordion, Loading,
    Skeleton, Popover, and OSA-specific components (PillButton, GlassCard,
    GradientBackground, RoundedInput, AppCard, ProgressDots).
- Extracted CSS patterns (into `desktop/src/lib/design/`):
  - `buttons.css` — all 4 button shape families from Foundation `app.css`
  - `glass.css` — glassmorphism tokens and utility classes
  - `tokens/foundation-aliases.css` — token name mapping layer
