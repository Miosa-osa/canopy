/**
 * Tests for agents query factories.
 * Verifies query key shapes and filter URL construction.
 */
import { describe, expect, it } from 'vitest';
import { agentDetailQuery, agentsQuery, fireAgentMutation, hireAgentMutation } from './agents.js';

describe('agentsQuery()', () => {
  it('returns query key ["agents", {}] with no filters', () => {
    const q = agentsQuery();
    expect(q.queryKey).toEqual(['agents', {}]);
  });

  it('returns query key with filters object when filters provided', () => {
    const q = agentsQuery({ category: 'sales' });
    expect(q.queryKey).toEqual(['agents', { category: 'sales' }]);
  });

  it('has staleTime of 30_000', () => {
    const q = agentsQuery();
    expect(q.staleTime).toBe(30_000);
  });

  it('has a queryFn function', () => {
    const q = agentsQuery();
    expect(typeof q.queryFn).toBe('function');
  });
});

describe('agentDetailQuery()', () => {
  it('returns query key ["agents", slug]', () => {
    const q = agentDetailQuery('sales-strategist');
    expect(q.queryKey).toEqual(['agents', 'sales-strategist']);
  });

  it('is disabled when slug is empty string', () => {
    const q = agentDetailQuery('');
    expect(q.enabled).toBe(false);
  });

  it('is enabled when slug is non-empty', () => {
    const q = agentDetailQuery('architect');
    expect(q.enabled).toBe(true);
  });

  it('has staleTime of 30_000', () => {
    const q = agentDetailQuery('architect');
    expect(q.staleTime).toBe(30_000);
  });
});

describe('hireAgentMutation()', () => {
  it('returns mutationKey ["agents", "hire"]', () => {
    const m = hireAgentMutation();
    expect(m.mutationKey).toEqual(['agents', 'hire']);
  });

  it('has a mutationFn function', () => {
    const m = hireAgentMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});

describe('fireAgentMutation()', () => {
  it('returns mutationKey ["agents", "fire"]', () => {
    const m = fireAgentMutation();
    expect(m.mutationKey).toEqual(['agents', 'fire']);
  });

  it('has a mutationFn function', () => {
    const m = fireAgentMutation();
    expect(typeof m.mutationFn).toBe('function');
  });
});
