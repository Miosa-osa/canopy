# /commit

> Stage changes, generate a meaningful commit message, and commit.

## Usage
```
/commit [--all] [--amend] [-m "message"]
```

## What It Does
Analyzes staged and unstaged changes, generates a commit message that summarizes the "why" not just the "what", and creates the commit. Follows conventional commit format when the project uses it.

## Implementation
1. **Analyze changes** -- run `git diff --staged` and `git status`.
2. **Classify changes** -- feature, fix, refactor, docs, test, chore.
3. **Generate message** -- summarize the intent of changes in 1-2 sentences. Use conventional commit prefix if project convention detected.
4. **Stage** (if `--all`) -- add all modified tracked files.
5. **Commit** -- create the commit with the generated or provided message.
6. **Verify** -- run `git status` to confirm clean state.

## Examples
```bash
# Commit staged changes with auto-generated message
/commit

# Stage all changes and commit
/commit --all

# Commit with explicit message
/commit -m "fix: resolve race condition in session handler"

# Amend the last commit
/commit --amend
```
