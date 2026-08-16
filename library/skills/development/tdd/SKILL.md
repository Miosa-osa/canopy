---
name: tdd-enforcer
description: "Enforces Test-Driven Development discipline with RED-GREEN-REFACTOR cycle"
trigger: "always"
priority: 2
---

# TDD Enforcer Skill

Enforces strict Test-Driven Development discipline. You cannot prompt your way into TDD discipline - you need forcing functions that make TDD the path of least resistance.

## Activation

This skill activates when:
- Creating new features
- Implementing new functionality
- Keywords: "implement", "create", "add feature", "build"

## TDD Cycle

### Phase 1: RED (Write Failing Test First)

Before writing ANY implementation code:

1. **Understand the requirement**
   - What behavior should the code exhibit?
   - What are the inputs and expected outputs?
   - What edge cases exist?

2. **Write the test FIRST**
   ```
   // The test must:
   // - Define expected behavior
   // - Be specific and focused
   // - FAIL when run (no implementation yet)
   ```

3. **Run the test - confirm it FAILS**
   - If test passes without implementation → test is wrong
   - Red phase complete only when test fails for right reason

### Phase 2: GREEN (Minimum Implementation)

4. **Write MINIMUM code to pass**
   - Don't over-engineer
   - Don't add extra features
   - Just make the test pass

5. **Run the test - confirm it PASSES**
   - If still failing → fix implementation
   - Green phase complete when test passes

### Phase 3: REFACTOR (Improve Code)

6. **Refactor while keeping tests green**
   - Improve code structure
   - Remove duplication
   - Enhance readability
   - Run tests after each change

## Enforcement Rules

### Pre-Implementation Check
Before writing any feature code, verify:
- [ ] Test file exists for the feature
- [ ] Test defines expected behavior
- [ ] Test currently fails (RED state)

### Blocking Conditions
BLOCK implementation if:
- No test exists for the feature
- Test already passes (skipped RED phase)
- Test doesn't cover the feature being implemented

### Quality Gates
- Minimum 80% coverage for new code
- All tests must pass before commit
- No implementation without corresponding test

## Framework Detection

### JavaScript/TypeScript
```bash
# Jest
npm test -- --coverage

# Vitest
npx vitest run --coverage

# Playwright (E2E)
npx playwright test
```

### Go
```bash
# Unit tests with coverage
go test -cover -coverprofile=coverage.out ./...

# View coverage
go tool cover -html=coverage.out
```

### Python
```bash
# pytest with coverage
pytest --cov=. --cov-report=html
```

## Example Workflow

```markdown
## Task: Add user authentication

### 1. RED: Write failing test
```typescript
// auth.test.ts
describe('authenticateUser', () => {
  it('should return token for valid credentials', async () => {
    const result = await authenticateUser('user@test.com', 'password123');
    expect(result.token).toBeDefined();
    expect(result.expiresIn).toBe(3600);
  });

  it('should throw error for invalid credentials', async () => {
    await expect(
      authenticateUser('user@test.com', 'wrong')
    ).rejects.toThrow('Invalid credentials');
  });
});
```

### 2. Run test → FAILS (function doesn't exist)

### 3. GREEN: Minimum implementation
```typescript
// auth.ts
export async function authenticateUser(email: string, password: string) {
  const user = await findUserByEmail(email);
  if (!user || !verifyPassword(password, user.passwordHash)) {
    throw new Error('Invalid credentials');
  }
  return {
    token: generateToken(user),
    expiresIn: 3600
  };
}
```

### 4. Run test → PASSES

### 5. REFACTOR: Improve code quality
- Extract constants
- Add input validation
- Improve error messages
```

## Integration with Hooks

### Pre-commit Hook
```bash
#!/bin/bash
# Block commits without test coverage

# Get changed files
changed_files=$(git diff --cached --name-only --diff-filter=ACM)

# Check for test files
for file in $changed_files; do
  if [[ $file =~ \.(ts|js|go|py)$ ]] && [[ ! $file =~ (test|spec) ]]; then
    # Implementation file - check for corresponding test
    test_file="${file%.*}.test.${file##*.}"
    if ! git diff --cached --name-only | grep -q "$test_file"; then
      echo "ERROR: No test file for $file"
      echo "TDD requires tests FIRST. Add $test_file"
      exit 1
    fi
  fi
done
```

## Metrics Tracked

- Tests written before implementation: Count
- RED-GREEN-REFACTOR cycles completed: Count
- Coverage percentage: Percentage
- Test-first compliance rate: Percentage
