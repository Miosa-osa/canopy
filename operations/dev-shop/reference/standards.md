# Code Standards

> Formatting, naming, and quality rules. Load at boot.

## TypeScript Standards

### Strict Mode
`tsconfig.json` must have `"strict": true`. No exceptions.

### No `any`
Use `unknown` with type guards instead of `any`. If you must type something
you don't control, use a type assertion with a comment explaining why.

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Variables, functions | camelCase | `getUserById`, `isActive` |
| Types, interfaces, classes | PascalCase | `UserProfile`, `OrderService` |
| Constants | SCREAMING_SNAKE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| Files | kebab-case | `user-service.ts`, `order-repository.ts` |
| Test files | `*.test.ts` or `*.spec.ts` | `user-service.test.ts` |
| Component files | PascalCase | `UserCard.tsx`, `SearchBar.tsx` |
| Enums | PascalCase (name), SCREAMING_SNAKE (values) | `enum Status { ACTIVE, INACTIVE }` |

### Import Order

```typescript
// 1. Node built-ins
import { readFile } from 'fs/promises';

// 2. External packages
import express from 'express';
import { z } from 'zod';

// 3. Internal packages (path aliases)
import { UserService } from '@/services/user-service';

// 4. Relative imports
import { formatDate } from './utils';
```

### Function Length
- Max 30 lines per function (excluding types and comments)
- If longer, extract helper functions
- Exception: switch statements with many cases

### File Length
- Max 300 lines per file
- If longer, split into modules

## Git Standards

### Branch Naming
```
feature/{ticket-id}-{short-description}
fix/{ticket-id}-{short-description}
hotfix/{ticket-id}-{short-description}
refactor/{description}
docs/{description}
```

### Commit Messages
```
{type}({scope}): {description}

{optional body}

{optional footer: ticket reference}
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`

Examples:
- `feat(auth): add refresh token rotation`
- `fix(orders): handle currency rounding edge case`
- `refactor(users): extract validation to service layer`

### PR Requirements
- Title matches commit convention
- Description includes: what, why, how to test
- All CI checks pass
- At least 1 approval from tech-lead or QA
- No unresolved conversations

## SQL Standards

- ALWAYS use parameterized queries
- ALWAYS use migrations (never manual schema changes)
- Table names: plural, snake_case (`users`, `order_items`)
- Column names: singular, snake_case (`user_id`, `created_at`)
- Every table: `id`, `created_at`, `updated_at` columns
- Soft delete: `deleted_at` timestamp (not boolean)
- Foreign keys: `{singular_table}_id` (e.g., `user_id`)
- Indexes: named as `idx_{table}_{columns}`

## API Standards

- RESTful resource naming: plural nouns (`/users`, `/orders`)
- HTTP methods: GET (read), POST (create), PUT (replace), PATCH (update), DELETE (remove)
- Status codes: 200 (OK), 201 (Created), 204 (No Content), 400, 401, 403, 404, 409, 429, 500
- Versioning: URL-based (`/api/v1/`)
- Pagination: `?page=1&per_page=20`
- Filtering: `?status=active&created_after=2026-01-01`
- Sorting: `?sort=created_at&order=desc`
- All responses: JSON with consistent envelope

## Logging Standards

- Format: structured JSON
- Required fields: `timestamp`, `level`, `message`, `request_id`
- Levels: `debug`, `info`, `warn`, `error`, `fatal`
- NEVER log: passwords, tokens, PII, credit card numbers
- ALWAYS log: authentication failures, authorization failures, input validation failures
