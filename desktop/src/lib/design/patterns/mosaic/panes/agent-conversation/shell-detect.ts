/**
 * shell-detect — pure helper that decides whether a composer input
 * looks like a shell command rather than an agent prompt.
 *
 * Heuristic: first whitespace-bounded token matches a known POSIX /
 * project-tooling command. Conservative on purpose — false positives are
 * worse than false negatives because the user can still ⌘| to override.
 *
 * Exported as a pure module so it can be unit-tested without booting the
 * Svelte compiler / TanStack Query (mirrors save-state.svelte.ts split).
 */

/**
 * Allowed shell-like first tokens. Kept short and explicit — adding new
 * commands here is a deliberate widening of the heuristic.
 */
export const SHELL_COMMANDS: ReadonlySet<string> = new Set([
  // POSIX core
  'cd',
  'ls',
  'll',
  'la',
  'cat',
  'less',
  'tail',
  'head',
  'grep',
  'rg',
  'find',
  'echo',
  'pwd',
  'mkdir',
  'rmdir',
  'rm',
  'cp',
  'mv',
  'touch',
  'chmod',
  'chown',
  'ln',
  'ps',
  'kill',
  'which',
  'where',
  'whoami',
  'date',
  'df',
  'du',
  'env',
  'export',
  'source',
  'history',
  'clear',
  'exit',
  'open',
  // Network
  'curl',
  'wget',
  'ssh',
  'scp',
  'rsync',
  'ping',
  'nslookup',
  // VCS
  'git',
  'gh',
  'hg',
  // JS / TS toolchain
  'node',
  'npm',
  'pnpm',
  'yarn',
  'bun',
  'npx',
  'tsc',
  'vite',
  'vitest',
  'biome',
  // Elixir / BEAM
  'mix',
  'iex',
  'elixir',
  'rebar3',
  // Python
  'python',
  'python3',
  'pip',
  'pip3',
  'pytest',
  'uv',
  // Rust
  'cargo',
  'rustc',
  'rustup',
  // Go
  'go',
  // Containers / infra
  'docker',
  'podman',
  'kubectl',
  'helm',
  'terraform',
  'make',
  // Misc dev
  'tmux',
  'screen',
  'vim',
  'nvim',
  'code',
  'claude',
  'codex',
  'gemini',
  'opencode',
  'aider',
  'tauri',
]);

/**
 * Returns true iff the trimmed input begins with a known shell command
 * followed by whitespace, end-of-string, or a typical shell punctuation
 * char (`;`, `|`, `&`, `>`, `<`, `(`).
 *
 * Examples:
 *   `git status`        → true
 *   `cd ~/code`         → true
 *   `ls`                → true
 *   `lsof`              → false  (lsof not in set)
 *   `git`               → true
 *   `git;`              → true
 *   `please run git`    → false
 *   ``                  → false
 *   `/agent foo`        → false  (slash command, owned elsewhere)
 */
export function looksLikeShellCommand(input: string): boolean {
  const trimmed = input.trimStart();
  if (trimmed.length === 0) return false;
  // Slash commands are routed through SlashCommands, not the shell.
  if (trimmed.startsWith('/')) return false;
  // Match the leading word (alphanumerics + a few legal command chars).
  const m = /^([a-zA-Z][a-zA-Z0-9._-]*)([\s;|&><()]|$)/.exec(trimmed);
  if (!m) return false;
  return SHELL_COMMANDS.has(m[1]);
}
