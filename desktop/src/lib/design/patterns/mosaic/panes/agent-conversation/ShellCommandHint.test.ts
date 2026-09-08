/**
 * ShellCommandHint — pure-logic tests for the shell-detection regex.
 *
 * The component itself uses Svelte 5 runes (compiler context required),
 * so we exercise the logic that drives `visible` via the pure helper
 * `looksLikeShellCommand`. Same convention as save-state.test.ts.
 */
import { describe, expect, it } from 'vitest';
import { looksLikeShellCommand, SHELL_COMMANDS } from './shell-detect.js';

describe('looksLikeShellCommand()', () => {
  it('returns false for empty / whitespace-only input', () => {
    expect(looksLikeShellCommand('')).toBe(false);
    expect(looksLikeShellCommand('   ')).toBe(false);
    expect(looksLikeShellCommand('\n\t')).toBe(false);
  });

  it('returns true for known POSIX commands followed by space', () => {
    expect(looksLikeShellCommand('ls -la')).toBe(true);
    expect(looksLikeShellCommand('cd ~/code')).toBe(true);
    expect(looksLikeShellCommand('cat README.md')).toBe(true);
    expect(looksLikeShellCommand('grep -r foo .')).toBe(true);
  });

  it('returns true for known commands with no arguments', () => {
    expect(looksLikeShellCommand('ls')).toBe(true);
    expect(looksLikeShellCommand('pwd')).toBe(true);
    expect(looksLikeShellCommand('git')).toBe(true);
  });

  it('returns true for VCS / package-manager commands', () => {
    expect(looksLikeShellCommand('git status')).toBe(true);
    expect(looksLikeShellCommand('gh pr list')).toBe(true);
    expect(looksLikeShellCommand('npm install')).toBe(true);
    expect(looksLikeShellCommand('pnpm dev')).toBe(true);
    expect(looksLikeShellCommand('cargo build')).toBe(true);
    expect(looksLikeShellCommand('mix test')).toBe(true);
  });

  it('trims leading whitespace before matching', () => {
    expect(looksLikeShellCommand('   git status')).toBe(true);
    expect(looksLikeShellCommand('\tcd /tmp')).toBe(true);
  });

  it('returns false for natural-language prompts that start with a verb', () => {
    expect(looksLikeShellCommand('please run git status')).toBe(false);
    expect(looksLikeShellCommand('can you list the files')).toBe(false);
    expect(looksLikeShellCommand('describe the test failure')).toBe(false);
  });

  it('returns false for slash commands (those route through SlashCommands)', () => {
    expect(looksLikeShellCommand('/agent')).toBe(false);
    expect(looksLikeShellCommand('/model claude-opus')).toBe(false);
  });

  it('does not greedy-match unknown commands that share a prefix', () => {
    // `lsof` is not in the allowlist even though `ls` is.
    expect(looksLikeShellCommand('lsof -i')).toBe(false);
    // `cdr` is not a known command.
    expect(looksLikeShellCommand('cdr foo')).toBe(false);
    // `gitlab-runner` shouldn't match `git`.
    expect(looksLikeShellCommand('gitlab-runner exec')).toBe(false);
  });

  it('matches when followed by a shell punctuation char', () => {
    expect(looksLikeShellCommand('git;')).toBe(true);
    expect(looksLikeShellCommand('ls|wc -l')).toBe(true);
    expect(looksLikeShellCommand('ls&')).toBe(true);
    expect(looksLikeShellCommand('cat>foo')).toBe(true);
  });

  it('rejects commands with embedded spaces in the head token', () => {
    // "ls -" is fine, but " ls" with a stray separator inside is not a
    // valid token — handled by the regex bounds.
    expect(looksLikeShellCommand('l s')).toBe(false);
  });

  it('treats common dev commands as shell-y', () => {
    expect(looksLikeShellCommand('docker ps')).toBe(true);
    expect(looksLikeShellCommand('kubectl get pods')).toBe(true);
    expect(looksLikeShellCommand('make test')).toBe(true);
    expect(looksLikeShellCommand('python -V')).toBe(true);
  });

  it('is case-sensitive (real shell commands are lowercase)', () => {
    expect(looksLikeShellCommand('LS')).toBe(false);
    expect(looksLikeShellCommand('Git status')).toBe(false);
  });
});

describe('SHELL_COMMANDS allowlist', () => {
  it('includes the core POSIX trio', () => {
    expect(SHELL_COMMANDS.has('cd')).toBe(true);
    expect(SHELL_COMMANDS.has('ls')).toBe(true);
    expect(SHELL_COMMANDS.has('cat')).toBe(true);
  });

  it('includes BEAM tooling so `mix` / `iex` are detected', () => {
    expect(SHELL_COMMANDS.has('mix')).toBe(true);
    expect(SHELL_COMMANDS.has('iex')).toBe(true);
    expect(SHELL_COMMANDS.has('elixir')).toBe(true);
  });

  it('includes JS toolchain commands', () => {
    for (const cmd of ['npm', 'pnpm', 'yarn', 'bun', 'npx']) {
      expect(SHELL_COMMANDS.has(cmd)).toBe(true);
    }
  });

  it('does NOT include ambiguous prose words', () => {
    for (const word of ['please', 'can', 'the', 'list', 'show', 'explain']) {
      expect(SHELL_COMMANDS.has(word)).toBe(false);
    }
  });
});
