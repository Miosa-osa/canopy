---
name: Analyze TypeScript
description: Systematic debugging and analysis skill for TypeScript codebases. Guides agents through type errors, runtime issues, and build failures with structured diagnostic steps.
provider_format: claude
tags:
  - typescript
  - debugging
  - analysis
---

## TypeScript Analysis Protocol

When encountering TypeScript errors or unexpected runtime behavior, follow this structured approach:

### 1. Triage the error type

- **Type errors** (`TS2xxx`): Check type assignments, generics, and inference chains. Run `tsc --noEmit` for the full list.
- **Runtime errors**: Check for `undefined` access on optional fields, missing null guards, and async/await misuse.
- **Build errors**: Check `tsconfig.json` `strict` flags — especially `strictNullChecks` and `noImplicitAny`.

### 2. Trace the type chain

```typescript
// Use satisfies for type-safe object literals without widening
const config = {
  endpoint: "/api/v1",
  retries: 3,
} satisfies ApiConfig;

// Use unknown + type guards instead of any
function processResponse(data: unknown): Result {
  if (!isApiResponse(data)) throw new Error("Invalid response shape");
  return transform(data);
}
```

### 3. Check strict mode compliance

Canopy backend-generated types (from OpenAPI) are strict. Never cast with `as any`. Use `as const` for literals, `satisfies` for object shape validation.

### 4. Verify generated types are current

Run `pnpm -C desktop typecheck` — if it fails on import paths from `@canopyai/types`, the OpenAPI spec may be stale. Regenerate with `mix canopy.gen.openapi`.

### Resolution checklist

- [ ] `tsc --noEmit` passes with 0 errors
- [ ] No `any` casts (use `unknown` + guards)
- [ ] All async functions have explicit return types
- [ ] Error boundaries wrap feature sections
