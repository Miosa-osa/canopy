/**
 * Tests for runtimes query factories.
 * Verifies query key shapes, enabled flags, and mutation key shapes.
 */
import { describe, expect, it } from 'vitest';
import {
  runtimeCredentialsQuery,
  runtimeDetailQuery,
  runtimeModelsQuery,
  runtimesQuery,
  saveRuntimeCredentialsMutation,
  testEnvironmentMutation,
} from './runtimes.js';

describe('runtimesQuery()', () => {
  it('returns query key ["runtimes"]', () => {
    const q = runtimesQuery();
    expect(q.queryKey).toEqual(['runtimes']);
  });

  it('has staleTime of 30_000', () => {
    expect(runtimesQuery().staleTime).toBe(30_000);
  });

  it('has a queryFn function', () => {
    expect(typeof runtimesQuery().queryFn).toBe('function');
  });
});

describe('runtimeDetailQuery()', () => {
  it('returns query key ["runtimes", type]', () => {
    const q = runtimeDetailQuery('claude-code');
    expect(q.queryKey).toEqual(['runtimes', 'claude-code']);
  });

  it('is disabled when type is empty', () => {
    expect(runtimeDetailQuery('').enabled).toBe(false);
  });

  it('is enabled when type is non-empty', () => {
    expect(runtimeDetailQuery('codex').enabled).toBe(true);
  });
});

describe('runtimeModelsQuery()', () => {
  it('returns query key ["runtimes", type, "models"]', () => {
    const q = runtimeModelsQuery('gemini');
    expect(q.queryKey).toEqual(['runtimes', 'gemini', 'models']);
  });

  it('has staleTime of 60_000', () => {
    expect(runtimeModelsQuery('gemini').staleTime).toBe(60_000);
  });
});

describe('testEnvironmentMutation()', () => {
  it('returns mutationKey ["runtimes", type, "test"]', () => {
    const m = testEnvironmentMutation('claude-code');
    expect(m.mutationKey).toEqual(['runtimes', 'claude-code', 'test']);
  });

  it('has a mutationFn function', () => {
    expect(typeof testEnvironmentMutation('claude-code').mutationFn).toBe('function');
  });
});

describe('saveRuntimeCredentialsMutation()', () => {
  it('returns mutationKey ["runtimes", type, "credentials"]', () => {
    const m = saveRuntimeCredentialsMutation('claude-code');
    expect(m.mutationKey).toEqual(['runtimes', 'claude-code', 'credentials']);
  });

  it('has a mutationFn function', () => {
    expect(typeof saveRuntimeCredentialsMutation('claude-code').mutationFn).toBe('function');
  });
});

describe('runtimeCredentialsQuery()', () => {
  it('returns query key ["runtimes", type, "credentials"]', () => {
    const q = runtimeCredentialsQuery('claude-code');
    expect(q.queryKey).toEqual(['runtimes', 'claude-code', 'credentials']);
  });

  it('is disabled when type is empty', () => {
    expect(runtimeCredentialsQuery('').enabled).toBe(false);
  });

  it('is enabled when type is non-empty', () => {
    expect(runtimeCredentialsQuery('claude-code').enabled).toBe(true);
  });

  it('has staleTime of 60_000', () => {
    expect(runtimeCredentialsQuery('claude-code').staleTime).toBe(60_000);
  });
});
