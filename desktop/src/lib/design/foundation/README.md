# Foundation Primitives

Copied from Miosa-osa/foundation at commit a6f26df (April 2026).

First-party MIOSA repo — not an external dependency, no npm package exists.
Sync upstream changes manually via a future sync script (TBD).

## What is here

27 Svelte 5 component primitives backed by Bits UI accessible primitives.
All components use `$lib/utils` (`cn()`) which is already present in Canopy.

## Import in Canopy

Import directly from the directory using an alias (if configured) or by path:

```svelte
import Modal from '$lib/design/foundation/modal/Modal.svelte';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '$lib/design/foundation/tabs';
import { toast, Toaster } from '$lib/design/foundation/toast';
```

## Do NOT edit directly

Edits here will be overwritten on the next upstream sync.
Canopy-specific adaptations belong in `$lib/design/` sibling files, not inside this directory.

## Modifications made during copy

- None. All files pasted verbatim.
- `$lib/utils` imports resolve correctly because Canopy's `src/lib/utils.ts` exports the same `cn()` function.
- Internal relative imports (e.g. `../loading/Loading.svelte`) resolve correctly because the directory structure is preserved.
