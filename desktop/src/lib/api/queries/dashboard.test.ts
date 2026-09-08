/**
 * Tests for the dashboard query factory.
 * Verifies query key shape, staleTime, refetchOnWindowFocus flag, and queryFn presence.
 */
import { describe, expect, it } from 'vitest';
import { dashboardSummaryQuery } from './dashboard.js';

describe('dashboardSummaryQuery()', () => {
  it('returns query key ["dashboard", "summary"]', () => {
    const q = dashboardSummaryQuery();
    expect(q.queryKey).toEqual(['dashboard', 'summary']);
  });

  it('has staleTime of 30_000', () => {
    const q = dashboardSummaryQuery();
    expect(q.staleTime).toBe(30_000);
  });

  it('has refetchOnWindowFocus set to true', () => {
    const q = dashboardSummaryQuery();
    expect(q.refetchOnWindowFocus).toBe(true);
  });

  it('has a queryFn function', () => {
    const q = dashboardSummaryQuery();
    expect(typeof q.queryFn).toBe('function');
  });

  it('query key is a readonly tuple', () => {
    const q = dashboardSummaryQuery();
    expect(Array.isArray(q.queryKey)).toBe(true);
    expect(q.queryKey[0]).toBe('dashboard');
    expect(q.queryKey[1]).toBe('summary');
  });
});
