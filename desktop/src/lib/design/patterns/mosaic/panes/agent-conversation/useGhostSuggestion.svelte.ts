/**
 * useGhostSuggestion — reactive ghost-text completions for the composer.
 *
 * Priority order:
 *   1. Slash commands — if draft starts with "/", prefix-match FALLBACK_BUILTINS
 *   2. Recent commands — prefix-match against localStorage canopy:recent-commands
 *   3. Shell builtins — if looksLikeShellCommand(draft), suggest common sub-commands
 *
 * Debounces 300 ms after the draft stops changing.
 * Returns null when no suggestion is available or draft is empty.
 */

import { FALLBACK_BUILTINS } from "$lib/api/queries/build-commands.js";
import { looksLikeShellCommand, SHELL_COMMANDS } from "./shell-detect.js";

export interface GhostSuggestion {
  /** Full completed command text. */
  text: string;
  /** The portion after what the user has already typed (rendered as ghost). */
  suffix: string;
  /** Where this suggestion came from. */
  source: "slash" | "recent" | "shell";
}

// ── Recent-command persistence ────────────────────────────────────────────────

const STORAGE_KEY = "canopy:recent-commands";
const MAX_RECENT = 50;

/** Push a sent command into the recent list (deduped, capped at MAX_RECENT). */
export function trackRecentCommand(command: string): void {
  const trimmed = command.trim();
  if (!trimmed) return;
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    const existing: string[] = raw ? (JSON.parse(raw) as string[]) : [];
    const deduped = [trimmed, ...existing.filter((c) => c !== trimmed)].slice(
      0,
      MAX_RECENT,
    );
    localStorage.setItem(STORAGE_KEY, JSON.stringify(deduped));
  } catch {
    // localStorage unavailable (SSR / private mode) — silently skip
  }
}

function getRecentCommands(): string[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}

// ── Shell sub-command hints ───────────────────────────────────────────────────

/**
 * A small map of common shell commands → their most-typed sub-commands.
 * Only used when the draft token is in SHELL_COMMANDS and nothing longer matches.
 */
const SHELL_HINTS: Record<string, string> = {
  git: 'git commit -m ""',
  npm: "npm install",
  pnpm: "pnpm install",
  yarn: "yarn install",
  docker: "docker ps",
  make: "make build",
  cargo: "cargo build",
  mix: "mix test",
  go: "go build ./...",
  kubectl: "kubectl get pods",
  python: "python3 -m",
  pip: "pip install",
  node: "node --inspect",
  bun: "bun run",
  deno: "deno run",
  curl: 'curl -s -X GET ""',
  wget: 'wget -O - ""',
  ssh: "ssh -i",
  scp: "scp -r",
  rsync: "rsync -avz",
  grep: 'grep -rn "" .',
  find: 'find . -name ""',
  sed: "sed -i ''",
  awk: "awk '{print $1}'",
  cat: "cat",
  less: "less",
  tail: "tail -f",
  head: "head -n 20",
  wc: "wc -l",
  ls: "ls -la",
  cd: "cd",
  mkdir: "mkdir -p",
  rm: "rm -rf",
  cp: "cp -r",
  mv: "mv",
  chmod: "chmod +x",
  chown: "chown -R",
  tar: "tar -xzf",
  zip: "zip -r",
  unzip: "unzip",
  brew: "brew install",
  apt: "apt install -y",
  yum: "yum install -y",
  systemctl: "systemctl status",
  journalctl: "journalctl -fu",
  ps: "ps aux | grep",
  kill: "kill -9",
  top: "top -o cpu",
  htop: "htop",
  df: "df -h",
  du: "du -sh *",
  env: "env | grep",
  export: "export",
  source: "source",
  which: "which",
  man: "man",
  history: "history | grep",
  xargs: "xargs -I{}",
  tee: "tee -a",
  sort: "sort -u",
  uniq: "uniq -c",
  diff: "diff -u",
  patch: "patch -p1 <",
  jq: "jq '.'",
  yq: "yq '.'",
  terraform: "terraform plan",
  ansible: "ansible-playbook",
  helm: "helm install",
  az: "az login",
  aws: "aws s3 ls",
  gcloud: "gcloud auth login",
  gh: "gh pr list",
  heroku: "heroku logs --tail",
  fly: "fly deploy",
  vercel: "vercel deploy",
  netlify: "netlify deploy",
  prisma: "prisma migrate dev",
  drizzle: "drizzle-kit push",
  jest: "jest --watch",
  vitest: "vitest --run",
  pytest: "pytest -v",
  rspec: "rspec --format doc",
  eslint: "eslint --fix .",
  prettier: "prettier --write .",
  biome: "biome check --fix .",
  tsc: "tsc --noEmit",
  esbuild: "esbuild --bundle",
  vite: "vite build",
  webpack: "webpack --mode production",
  turbo: "turbo run build",
  nx: "nx run-many --target=build",
  elixir: "elixir -e",
  iex: "iex -S mix",
  rustup: "rustup update",
  rustc: "rustc --edition 2024",
  wasm: "wasm-pack build",
  swift: "swift build",
  dotnet: "dotnet run",
  mvn: "mvn clean install",
  gradle: "gradle build",
  rake: "rake db:migrate",
  rails: "rails server",
  django: "django-admin startproject",
  flask: "flask run",
  uvicorn: "uvicorn main:app --reload",
  pg_dump: "pg_dump -Fc",
  psql: "psql -U postgres",
  mysql: "mysql -u root -p",
  redis: "redis-cli ping",
  mongosh: "mongosh",
  sqlite3: "sqlite3",
  ffmpeg: "ffmpeg -i",
  convert: "convert -resize",
  openssl: "openssl req -x509",
  ssh_keygen: "ssh-keygen -t ed25519",
  claude: "claude --dangerously-skip-permissions",
  aider: "aider --model claude-3-5-sonnet",
  codex: "codex --dangerously-bypass-approvals-and-sandbox",
  gemini: "gemini --model gemini-2.0-pro",
  opencode: "opencode --model anthropic/claude-sonnet-4-5",
};

const SUBCOMMAND_HINTS: Record<string, Record<string, string>> = {
  git: {
    "git c": 'git commit -m ""',
    "git co": "git checkout",
    "git ch": "git checkout -b",
    "git s": "git status",
    "git st": "git stash",
    "git sta": "git stash pop",
    "git p": "git push",
    "git pu": "git pull --rebase",
    "git l": "git log --oneline -20",
    "git lo": "git log --oneline --graph",
    "git d": "git diff",
    "git di": "git diff --staged",
    "git b": "git branch",
    "git br": "git branch -D",
    "git a": "git add -A",
    "git r": "git rebase",
    "git re": "git reset --soft HEAD~1",
    "git m": "git merge",
    "git f": "git fetch --all",
    "git cl": "git clone",
    "git t": "git tag",
    "git bl": "git blame",
    "git bi": "git bisect start",
    "git cherry": "git cherry-pick",
  },
  docker: {
    "docker b": "docker build -t",
    "docker r": "docker run -it --rm",
    "docker p": "docker ps -a",
    "docker s": "docker stop",
    "docker l": "docker logs -f",
    "docker e": "docker exec -it",
    "docker i": "docker images",
    "docker c": "docker compose up -d",
    "docker co": "docker compose down",
    "docker v": "docker volume ls",
    "docker n": "docker network ls",
    "docker pu": "docker push",
    "docker pull": "docker pull",
    "docker rm": "docker rm -f",
    "docker rmi": "docker rmi",
    "docker system": "docker system prune -af",
  },
  kubectl: {
    "kubectl g": "kubectl get pods",
    "kubectl ge": "kubectl get all -n",
    "kubectl d": "kubectl describe pod",
    "kubectl de": "kubectl delete pod",
    "kubectl l": "kubectl logs -f",
    "kubectl a": "kubectl apply -f",
    "kubectl e": "kubectl exec -it",
    "kubectl s": "kubectl scale deployment",
    "kubectl r": "kubectl rollout status",
    "kubectl p": "kubectl port-forward",
    "kubectl c": "kubectl config use-context",
    "kubectl n": "kubectl get nodes",
  },
  npm: {
    "npm i": "npm install",
    "npm r": "npm run",
    "npm t": "npm test",
    "npm s": "npm start",
    "npm b": "npm run build",
    "npm u": "npm update",
    "npm un": "npm uninstall",
    "npm ls": "npm ls --depth=0",
    "npm au": "npm audit fix",
    "npm ci": "npm ci",
    "npm p": "npm publish",
    "npm init": "npm init -y",
  },
  mix: {
    "mix t": "mix test",
    "mix d": "mix deps.get",
    "mix de": "mix deps.get",
    "mix c": "mix compile",
    "mix e": "mix ecto.migrate",
    "mix ec": "mix ecto.create",
    "mix em": "mix ecto.migrate",
    "mix er": "mix ecto.rollback",
    "mix p": "mix phx.server",
    "mix ph": "mix phx.gen.context",
    "mix f": "mix format",
    "mix r": "mix run",
    "mix s": "mix setup",
    "mix h": "mix hex.publish",
  },
  cargo: {
    "cargo b": "cargo build",
    "cargo r": "cargo run",
    "cargo t": "cargo test",
    "cargo c": "cargo check",
    "cargo cl": "cargo clippy",
    "cargo f": "cargo fmt",
    "cargo a": "cargo add",
    "cargo d": "cargo doc --open",
    "cargo u": "cargo update",
    "cargo p": "cargo publish",
    "cargo i": "cargo install",
    "cargo w": "cargo watch -x run",
  },
  gh: {
    "gh p": "gh pr list",
    "gh pr": "gh pr create --fill",
    "gh pr c": "gh pr checkout",
    "gh pr v": "gh pr view --web",
    "gh i": "gh issue list",
    "gh is": "gh issue create --title",
    "gh r": "gh repo clone",
    "gh re": "gh release create",
    "gh a": "gh api",
    "gh b": "gh browse",
    "gh s": "gh status",
    "gh co": "gh copilot suggest",
  },
  claude: {
    "claude --a": "claude --add-dir",
    "claude --ad": "claude --add-dir",
    "claude --ag": "claude --agent",
    "claude --all": "claude --allowed-tools",
    "claude --allowed": "claude --allowed-tools",
    "claude --app": "claude --append-system-prompt",
    "claude --append": "claude --append-system-prompt",
    "claude --b": "claude --bare",
    "claude --br": "claude --brief",
    "claude -c": "claude --continue",
    "claude --c": "claude --continue",
    "claude --ch": "claude --chrome",
    "claude --cont": "claude --continue",
    "claude -d": "claude --debug",
    "claude --d": "claude --dangerously-skip-permissions",
    "claude --da": "claude --dangerously-skip-permissions",
    "claude --dan": "claude --dangerously-skip-permissions",
    "claude --dang": "claude --dangerously-skip-permissions",
    "claude --danger": "claude --dangerously-skip-permissions",
    "claude --debug": "claude --debug",
    "claude --debug-f": "claude --debug-file",
    "claude --dis": "claude --disallowed-tools",
    "claude --eff": "claude --effort high",
    "claude --fallback": "claude --fallback-model sonnet",
    "claude --file": "claude --file",
    "claude --fork": "claude --fork-session",
    "claude --from": "claude --from-pr",
    "claude --ide": "claude --ide",
    "claude --input": "claude --input-format stream-json",
    "claude --json": "claude --json-schema",
    "claude --max": "claude --max-budget-usd",
    "claude --mcp": "claude --mcp-config",
    "claude --mcp-d": "claude --mcp-debug",
    "claude -m": "claude --model sonnet",
    "claude --m": "claude --model sonnet",
    "claude --mo": "claude --model sonnet",
    "claude --model": "claude --model sonnet",
    "claude -n": "claude --name",
    "claude --name": "claude --name",
    "claude --no-c": "claude --no-chrome",
    "claude --no-s": "claude --no-session-persistence",
    "claude --out": "claude --output-format stream-json",
    "claude --output": "claude --output-format stream-json",
    "claude --perm": "claude --permission-mode bypassPermissions",
    "claude --permission": "claude --permission-mode bypassPermissions",
    "claude -p": "claude --print",
    "claude --p": "claude --print",
    "claude --pl": "claude --plugin-dir",
    "claude --print": "claude --print",
    "claude -r": "claude --resume",
    "claude --r": "claude --resume",
    "claude --re": "claude --resume",
    "claude --resume": "claude --resume",
    "claude --session": "claude --session-id",
    "claude --setting": "claude --setting-sources",
    "claude --settings": "claude --settings",
    "claude --strict": "claude --strict-mcp-config",
    "claude --sys": "claude --system-prompt",
    "claude --system": "claude --system-prompt",
    "claude --tm": "claude --tmux",
    "claude --tmux": "claude --tmux",
    "claude --tools": "claude --tools",
    "claude --v": "claude --verbose",
    "claude -w": "claude --worktree",
    "claude --w": "claude --worktree",
    "claude --work": "claude --worktree",
    "claude agents": "claude agents",
    "claude auth": "claude auth",
    "claude doctor": "claude doctor",
    "claude mcp": "claude mcp",
    "claude plugin": "claude plugin",
    "claude plugins": "claude plugins",
    "claude project": "claude project",
    "claude update": "claude update",
    "claude upgrade": "claude upgrade",
    "claude ultr": "claude ultrareview",
  },
  codex: {
    "codex e": "codex exec",
    "codex ex": "codex exec",
    "codex exec": "codex exec",
    "codex r": "codex review",
    "codex re": "codex review",
    "codex res": "codex resume",
    "codex resume": "codex resume --last",
    "codex f": "codex fork",
    "codex fo": "codex fork",
    "codex fork": "codex fork --last",
    "codex l": "codex login",
    "codex lo": "codex login",
    "codex log": "codex logout",
    "codex m": "codex mcp",
    "codex mc": "codex mcp",
    "codex plugin": "codex plugin",
    "codex apply": "codex apply",
    "codex app": "codex app",
    "codex cloud": "codex cloud",
    "codex sandbox": "codex sandbox",
    "codex features": "codex features",
    "codex -m": "codex --model o3",
    "codex --m": "codex --model o3",
    "codex --model": "codex --model o3",
    "codex -c": "codex --config",
    "codex --c": "codex --config",
    "codex --config": "codex --config model=\"o3\"",
    "codex --en": "codex --enable",
    "codex --dis": "codex --disable",
    "codex --rem": "codex --remote",
    "codex -i": "codex --image",
    "codex --im": "codex --image",
    "codex --oss": "codex --oss",
    "codex --local": "codex --local-provider ollama",
    "codex -p": "codex --profile",
    "codex --p": "codex --profile",
    "codex -s": "codex --sandbox workspace-write",
    "codex --s": "codex --sandbox workspace-write",
    "codex --sandbox": "codex --sandbox workspace-write",
    "codex --d": "codex --dangerously-bypass-approvals-and-sandbox",
    "codex --da": "codex --dangerously-bypass-approvals-and-sandbox",
    "codex --dan": "codex --dangerously-bypass-approvals-and-sandbox",
    "codex --danger": "codex --dangerously-bypass-approvals-and-sandbox",
    "codex --dangerously": "codex --dangerously-bypass-approvals-and-sandbox",
    "codex -C": "codex --cd",
    "codex --cd": "codex --cd",
    "codex --add": "codex --add-dir",
    "codex -a": "codex --ask-for-approval never",
    "codex --ask": "codex --ask-for-approval never",
    "codex --search": "codex --search",
    "codex --no": "codex --no-alt-screen",
  },
  gemini: {
    "gemini -m": "gemini --model gemini-2.0-pro",
    "gemini --m": "gemini --model gemini-2.0-pro",
    "gemini --model": "gemini --model gemini-2.0-pro",
    "gemini -p": "gemini --prompt",
    "gemini --p": "gemini --prompt",
    "gemini --prompt": "gemini --prompt",
    "gemini -d": "gemini --debug",
    "gemini --debug": "gemini --debug",
    "gemini auth": "gemini auth",
    "gemini mcp": "gemini mcp",
  },
  opencode: {
    "opencode r": "opencode run",
    "opencode ru": "opencode run",
    "opencode run": "opencode run",
    "opencode a": "opencode agent",
    "opencode ac": "opencode acp",
    "opencode attach": "opencode attach",
    "opencode auth": "opencode providers",
    "opencode db": "opencode db",
    "opencode debug": "opencode debug",
    "opencode export": "opencode export",
    "opencode github": "opencode github",
    "opencode import": "opencode import",
    "opencode mcp": "opencode mcp",
    "opencode models": "opencode models",
    "opencode plugin": "opencode plugin",
    "opencode pr": "opencode pr",
    "opencode providers": "opencode providers",
    "opencode serve": "opencode serve",
    "opencode session": "opencode session",
    "opencode stats": "opencode stats",
    "opencode web": "opencode web",
    "opencode -m": "opencode --model anthropic/claude-sonnet-4-5",
    "opencode --m": "opencode --model anthropic/claude-sonnet-4-5",
    "opencode --model": "opencode --model anthropic/claude-sonnet-4-5",
    "opencode -c": "opencode --continue",
    "opencode --c": "opencode --continue",
    "opencode --cont": "opencode --continue",
    "opencode -s": "opencode --session",
    "opencode --s": "opencode --session",
    "opencode --session": "opencode --session",
    "opencode --f": "opencode --fork",
    "opencode --fork": "opencode --fork",
    "opencode --prompt": "opencode --prompt",
    "opencode --agent": "opencode --agent",
    "opencode --port": "opencode --port",
    "opencode --host": "opencode --hostname",
    "opencode --pure": "opencode --pure",
    "opencode --log": "opencode --log-level DEBUG",
  },
  aider: {
    "aider -m": "aider --model claude-3-5-sonnet",
    "aider --m": "aider --model claude-3-5-sonnet",
    "aider --model": "aider --model claude-3-5-sonnet",
    "aider --yes": "aider --yes",
    "aider --watch": "aider --watch-files",
  },
};

// ── Core resolver ─────────────────────────────────────────────────────────────

function editDistance(a: string, b: string): number {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => {
    const row = Array<number>(b.length + 1).fill(0);
    row[0] = i;
    return row;
  });
  for (let j = 0; j <= b.length; j += 1) dp[0][j] = j;
  for (let i = 1; i <= a.length; i += 1) {
    for (let j = 1; j <= b.length; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost,
      );
    }
  }
  return dp[a.length][b.length];
}

function fuzzyRuntimeHint(firstToken: string, lower: string, trimmed: string): string | null {
  const hints = SUBCOMMAND_HINTS[firstToken];
  if (!hints || !lower.includes(' --')) return null;

  const typedFlag = lower.slice(lower.lastIndexOf(' --') + 1);
  if (typedFlag.length < 4) return null;

  const candidates = [...new Set(Object.values(hints))]
    .filter((hint) => hint.startsWith(`${firstToken} --`) && hint.length > trimmed.length)
    .map((hint) => {
      const flag = hint.slice(firstToken.length + 1).split(/\s+/)[0].toLowerCase();
      const distance = editDistance(typedFlag, flag.slice(0, Math.max(typedFlag.length, 4)));
      const prefixBonus = flag.startsWith(typedFlag) ? -4 : 0;
      return { hint, score: distance + prefixBonus };
    })
    .sort((a, b) => a.score - b.score || a.hint.length - b.hint.length);

  const best = candidates[0];
  return best && best.score <= 2 ? best.hint : null;
}

function resolve(draft: string): GhostSuggestion | null {
  const trimmed = draft.trimStart();
  if (trimmed.length === 0) return null;

  // 1. Slash commands
  if (trimmed.startsWith("/")) {
    const lower = trimmed.toLowerCase();
    const match = FALLBACK_BUILTINS.find(
      (cmd) => cmd.name.startsWith(lower) && cmd.name !== lower,
    );
    if (match) {
      return {
        text: match.name,
        suffix: match.name.slice(trimmed.length),
        source: "slash",
      };
    }
    return null;
  }

  // 2. Recent commands — prefix match
  const recent = getRecentCommands();
  const recentMatch = recent.find(
    (cmd) =>
      cmd.toLowerCase().startsWith(trimmed.toLowerCase()) &&
      cmd.length > trimmed.length,
  );
  if (recentMatch) {
    return {
      text: recentMatch,
      suffix: recentMatch.slice(trimmed.length),
      source: "recent",
    };
  }

  // 3. Shell builtins — subcommand hints first, then base hints
  if (looksLikeShellCommand(trimmed)) {
    const firstToken = trimmed.split(/\s/)[0];
    const lower = trimmed.toLowerCase();

    // 3a. Subcommand match — "git c" → "git commit -m """
    if (firstToken && SUBCOMMAND_HINTS[firstToken]) {
      const subs = SUBCOMMAND_HINTS[firstToken];
      const subKey = Object.keys(subs)
        .sort((a, b) => b.length - a.length)
        .find((k) => lower.startsWith(k) && subs[k].length > trimmed.length);
      if (subKey) {
        const hint = subs[subKey];
        return {
          text: hint,
          suffix: hint.slice(trimmed.length),
          source: "shell",
        };
      }
      const fuzzyHint = fuzzyRuntimeHint(firstToken, lower, trimmed);
      if (fuzzyHint) {
        return {
          text: fuzzyHint,
          suffix: fuzzyHint.slice(trimmed.length),
          source: "shell",
        };
      }
    }

    // 3b. Exact base command — "git" → "git commit -m """
    if (firstToken && trimmed === firstToken && SHELL_HINTS[firstToken]) {
      const hint = SHELL_HINTS[firstToken];
      return {
        text: hint,
        suffix: hint.slice(trimmed.length),
        source: "shell",
      };
    }

    // 3c. Partial token — "gi" → "git commit -m """
    const partialKey = Object.keys(SHELL_HINTS).find(
      (key) => key.startsWith(lower) && SHELL_COMMANDS.has(key),
    );
    if (partialKey) {
      const hint = SHELL_HINTS[partialKey];
      return {
        text: hint,
        suffix: hint.slice(trimmed.length),
        source: "shell",
      };
    }
  }

  return null;
}

// ── Reactive hook (Svelte 5 rune-based) ──────────────────────────────────────

/**
 * Returns a reactive object with a `suggestion` property.
 * Pass a getter function returning the current draft string.
 *
 * @example
 * const ghost = useGhostSuggestion(() => draft);
 * // ghost.suggestion — GhostSuggestion | null
 */
export function useGhostSuggestion(getDraft: () => string): {
  suggestion: GhostSuggestion | null;
} {
  let suggestion = $state<GhostSuggestion | null>(null);
  let timer: ReturnType<typeof setTimeout> | null = null;

  $effect(() => {
    const draft = getDraft();

    // Clear immediately when draft changes so stale ghost vanishes at once
    suggestion = null;

    if (timer !== null) clearTimeout(timer);
    if (draft.trim().length === 0) return;

    timer = setTimeout(() => {
      suggestion = resolve(draft);
    }, 100);

    return () => {
      if (timer !== null) clearTimeout(timer);
    };
  });

  return {
    get suggestion() {
      return suggestion;
    },
  };
}
