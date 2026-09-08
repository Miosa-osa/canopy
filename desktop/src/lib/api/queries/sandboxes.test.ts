/**
 * Tests for sandboxes query factories.
 * Verifies query key shapes, enabled flags, and mutation key shapes.
 */
import { describe, expect, it } from 'vitest';
import { deleteSandboxMutation, sandboxesQuery, sandboxQuery } from './sandboxes.js';

describe('sandboxesQuery()', () => {
  it('returns query key ["sandboxes"]', () => {
    expect(sandboxesQuery().queryKey).toEqual(['sandboxes']);
  });

  it('has staleTime of 15_000', () => {
    expect(sandboxesQuery().staleTime).toBe(15_000);
  });

  it('has a queryFn function', () => {
    expect(typeof sandboxesQuery().queryFn).toBe('function');
  });
});

describe('sandboxQuery()', () => {
  it('returns query key ["sandboxes", id]', () => {
    expect(sandboxQuery('sbx-123').queryKey).toEqual(['sandboxes', 'sbx-123']);
  });

  it('is disabled when id is empty', () => {
    expect(sandboxQuery('').enabled).toBe(false);
  });

  it('is enabled when id is non-empty', () => {
    expect(sandboxQuery('sbx-abc').enabled).toBe(true);
  });

  it('has staleTime of 15_000', () => {
    expect(sandboxQuery('sbx-abc').staleTime).toBe(15_000);
  });

  it('has a queryFn function', () => {
    expect(typeof sandboxQuery('sbx-abc').queryFn).toBe('function');
  });
});

describe('deleteSandboxMutation()', () => {
  it('returns mutationKey ["sandboxes", "delete"]', () => {
    expect(deleteSandboxMutation().mutationKey).toEqual(['sandboxes', 'delete']);
  });

  it('has a mutationFn function', () => {
    expect(typeof deleteSandboxMutation().mutationFn).toBe('function');
  });
});
