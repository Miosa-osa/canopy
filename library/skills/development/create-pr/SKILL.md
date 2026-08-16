# /create-pr

> Create a pull request with summary, test plan, and proper labeling.

## Usage
```
/create-pr [--base <branch>] [--draft] [--title "title"]
```

## What It Does
Analyzes all commits on the current branch vs the base branch, generates a PR title and description, pushes the branch, and creates the PR using `gh`. Includes a summary of changes, test plan, and links to related issues.

## Implementation
1. **Analyze changes** -- `git log` and `git diff` against base branch.
2. **Generate PR title** -- concise (<70 chars), focused on the "what".
3. **Generate PR body** -- summary bullets, test plan checklist, related issues.
4. **Push branch** -- `git push -u origin <branch>`.
5. **Create PR** -- `gh pr create` with title, body, labels, reviewers.
6. **Return URL** -- display the PR link.

## Examples
```bash
# Create PR against main
/create-pr

# Create draft PR against specific base
/create-pr --base develop --draft

# Create PR with explicit title
/create-pr --title "Add user authentication flow"
```
