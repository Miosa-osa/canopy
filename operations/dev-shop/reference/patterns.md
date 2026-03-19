# Design Patterns Catalog

> Approved patterns for common problems. Load on-demand when designing features.

## API Patterns

### Repository Pattern
**Use when**: Abstracting data access from business logic.
```typescript
interface UserRepository {
  findById(id: UserId): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  create(data: CreateUserInput): Promise<User>;
  update(id: UserId, data: UpdateUserInput): Promise<User>;
  delete(id: UserId): Promise<void>;
}
```
Business logic depends on the interface, not the implementation.

### Service Layer Pattern
**Use when**: Orchestrating business operations that span multiple repositories.
```typescript
class OrderService {
  constructor(
    private orders: OrderRepository,
    private inventory: InventoryRepository,
    private payments: PaymentGateway,
  ) {}

  async placeOrder(input: PlaceOrderInput): Promise<Order> {
    // Validate inventory
    // Process payment
    // Create order
    // All in a transaction
  }
}
```

### Result Pattern (Error Handling)
**Use when**: Functions that can fail in expected ways.
```typescript
type Result<T, E = AppError> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function parseEmail(input: string): Result<Email, ValidationError> {
  if (!isValidEmail(input)) {
    return { ok: false, error: new ValidationError('Invalid email') };
  }
  return { ok: true, value: input as Email };
}
```
Reserve try/catch for unexpected errors only.

### Pagination Pattern
**Use when**: Any list endpoint that could return > 50 items.
```typescript
interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    per_page: number;
    total: number;
    total_pages: number;
    has_next: boolean;
    has_prev: boolean;
  };
}
```
Default: 20 items per page. Max: 100.

## Frontend Patterns

### Container/Presenter Pattern
**Use when**: Separating data fetching from rendering.
- Container: fetches data, manages state, handles events
- Presenter: pure rendering, receives props, no side effects

### Custom Hook Pattern
**Use when**: Reusing stateful logic across components.
```typescript
function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debounced;
}
```

### Optimistic Update Pattern
**Use when**: User actions that modify server state (likes, saves, toggles).
1. Update UI immediately
2. Send request to server
3. If server fails, revert UI and show error

### Error Boundary Pattern
**Use when**: Preventing a component error from crashing the entire app.
Wrap feature sections in error boundaries with fallback UI.

## Infrastructure Patterns

### Circuit Breaker
**Use when**: Calling external services that might be down.
- Closed: requests flow normally
- Open: requests fail fast (no call to service)
- Half-open: allow one request to test recovery

### Retry with Exponential Backoff
**Use when**: Transient failures in external service calls.
```
Attempt 1: immediate
Attempt 2: wait 1s
Attempt 3: wait 2s
Attempt 4: wait 4s
Max retries: 3-5 depending on operation
```
Add jitter to prevent thundering herd.

### Rate Limiting
**Use when**: All public API endpoints.
- Per-user: 100 requests/minute
- Per-IP: 200 requests/minute
- Auth endpoints: 5 requests/minute per IP
- Use sliding window algorithm

## Anti-Patterns (Do Not Use)

| Anti-Pattern | Why It's Bad | Use Instead |
|-------------|-------------|-------------|
| God Object | Single class doing everything | Single Responsibility Principle |
| Spaghetti SQL | Raw SQL queries scattered everywhere | Repository pattern |
| Prop Drilling | Passing props 5+ levels deep | Context or state management |
| Silent Catch | `catch (e) { /* ignore */ }` | Handle or propagate with context |
| Magic Numbers | Hardcoded values without explanation | Named constants |
| Premature Optimization | Optimizing without profiling | Measure first, then optimize |
