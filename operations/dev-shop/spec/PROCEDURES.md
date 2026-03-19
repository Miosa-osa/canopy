# Procedure Registry v1.0

> Dev Shop — action and query bindings for software development operations.

## Action Bindings (Side-Effect Producers)

### CreateBranch → Actions.create_branch/2
  @spec create_branch(context(), %{repo: String.t(), base: String.t(), name: String.t(), ticket_id: String.t()}) :: {:ok, branch_ref} | {:error, reason}
  Runtime: git provider (hot-swap between GitHub, GitLab, Bitbucket)
  Timeout: 15s
  Approval: none

### RunTests → Actions.run_tests/2
  @spec run_tests(context(), %{repo: String.t(), branch: String.t(), suite: :unit | :integration | :e2e | :all, parallel: boolean()}) :: {:ok, %{passed: integer(), failed: integer(), skipped: integer(), duration_ms: integer(), report_url: String.t()}} | {:error, reason}
  Runtime: CI provider (hot-swap between GitHub Actions, CircleCI, BuildKite)
  Timeout: 600s
  Sandbox: yes
  Approval: none

### Deploy → Actions.deploy/2
  @spec deploy(context(), %{repo: String.t(), branch: String.t(), target: :staging | :production, strategy: :rolling | :blue_green | :canary}) :: {:ok, deployment_id} | {:error, reason}
  Runtime: deployment provider (hot-swap between Vercel, AWS, Fly.io, K8s)
  Timeout: 300s
  Approval: governance.deploy_review (if target == :production)

### CreatePR → Actions.create_pr/2
  @spec create_pr(context(), %{repo: String.t(), head: String.t(), base: String.t(), title: String.t(), body: String.t(), reviewers: [String.t()], labels: [String.t()]}) :: {:ok, pr_id} | {:error, reason}
  Runtime: git provider
  Timeout: 15s
  Approval: none

### ReviewCode → Actions.review_code/2
  @spec review_code(context(), %{pr_id: String.t(), repo: String.t(), focus: [:security | :performance | :correctness | :style], depth: :quick | :thorough}) :: {:ok, %{comments: [comment()], verdict: :approve | :request_changes | :needs_discussion}} | {:error, reason}
  Runtime: code review engine (LLM-backed)
  Timeout: 120s
  Approval: none

### MergePR → Actions.merge_pr/2
  @spec merge_pr(context(), %{pr_id: String.t(), repo: String.t(), strategy: :squash | :merge | :rebase}) :: {:ok, merge_sha} | {:error, reason}
  Runtime: git provider
  Timeout: 30s
  Approval: governance.merge_review (if base == :main and approvals < 2)

### NotifyDev → Actions.notify_dev/2
  @spec notify_dev(context(), %{channel: :slack | :email | :github, message: String.t(), urgency: :low | :normal | :high, mention: [String.t()]}) :: :ok
  Runtime: notification hub
  Timeout: 10s
  Approval: none

### RollbackDeploy → Actions.rollback_deploy/2
  @spec rollback_deploy(context(), %{deployment_id: String.t(), target: :staging | :production}) :: {:ok, rollback_id} | {:error, reason}
  Runtime: deployment provider
  Timeout: 120s
  Approval: none (rollbacks are pre-approved for speed)


## Query Bindings (Pure Functions)

### AnalyzeCode → Queries.analyze_code/2
  @spec analyze_code(context(), %{repo: String.t(), path: String.t() | :all, analysis: [:complexity | :dependencies | :security | :duplication]}) :: {:ok, %{findings: [finding()], risk_score: float(), hotspots: [String.t()]}}
  Runtime: static analysis engine (Sonar, Semgrep, custom)
  Cache: TTL 300s, key: {repo, path, hash(head_sha)}

### CheckCoverage → Queries.check_coverage/2
  @spec check_coverage(context(), %{repo: String.t(), branch: String.t(), threshold: float()}) :: {:ok, %{total: float(), by_file: map(), uncovered_critical: [String.t()], meets_threshold: boolean()}}
  Runtime: coverage provider
  Cache: TTL 120s, key: {repo, branch, head_sha}

### LintCheck → Queries.lint_check/2
  @spec lint_check(context(), %{repo: String.t(), branch: String.t(), rules: :default | :strict | :custom}) :: {:ok, %{errors: integer(), warnings: integer(), auto_fixable: integer(), details: [lint_issue()]}}
  Runtime: linter engine (ESLint, Credo, RuboCop — per-repo config)
  Cache: TTL 60s, key: {repo, branch, head_sha, rules}

### GetBuildStatus → Queries.get_build_status/2
  @spec get_build_status(context(), %{repo: String.t(), branch: String.t()}) :: {:ok, %{status: :passing | :failing | :pending, jobs: [job()], duration_ms: integer(), url: String.t()}}
  Runtime: CI provider
  Cache: TTL 15s, key: {repo, branch}

### CheckDependencies → Queries.check_dependencies/2
  @spec check_dependencies(context(), %{repo: String.t(), scope: :outdated | :vulnerable | :license | :all}) :: {:ok, %{outdated: [dep()], vulnerabilities: [vuln()], license_issues: [dep()]}}
  Runtime: dependency scanner (Dependabot, Snyk, custom)
  Cache: TTL 3600s, key: {repo, scope, hash(lockfile)}

### GetPRStatus → Queries.get_pr_status/2
  @spec get_pr_status(context(), %{pr_id: String.t(), repo: String.t()}) :: {:ok, %{checks: [check()], approvals: integer(), conflicts: boolean(), mergeable: boolean(), age_hours: integer()}}
  Runtime: git provider
  Cache: TTL 30s, key: {pr_id, repo}
