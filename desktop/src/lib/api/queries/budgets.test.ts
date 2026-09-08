/**
 * Tests for budgets query factories.
 * Verifies query key shapes, enabled flags, and mutation key shapes.
 */
import { describe, expect, it } from 'vitest';
import {
  budgetQuery,
  budgetSpendQuery,
  budgetsQuery,
  checkBudgetMutation,
  createBudgetMutation,
  deleteBudgetMutation,
  updateBudgetMutation,
} from './budgets.js';

describe('budgetsQuery()', () => {
  it('returns query key ["budgets"]', () => {
    expect(budgetsQuery().queryKey).toEqual(['budgets']);
  });

  it('has staleTime of 30_000', () => {
    expect(budgetsQuery().staleTime).toBe(30_000);
  });

  it('has a queryFn function', () => {
    expect(typeof budgetsQuery().queryFn).toBe('function');
  });
});

describe('budgetQuery()', () => {
  it('returns query key ["budgets", id]', () => {
    expect(budgetQuery('abc').queryKey).toEqual(['budgets', 'abc']);
  });

  it('is disabled when id is empty', () => {
    expect(budgetQuery('').enabled).toBe(false);
  });

  it('is enabled when id is non-empty', () => {
    expect(budgetQuery('abc').enabled).toBe(true);
  });

  it('has staleTime of 30_000', () => {
    expect(budgetQuery('abc').staleTime).toBe(30_000);
  });
});

describe('createBudgetMutation()', () => {
  it('returns mutationKey ["budgets", "create"]', () => {
    expect(createBudgetMutation().mutationKey).toEqual(['budgets', 'create']);
  });

  it('has a mutationFn function', () => {
    expect(typeof createBudgetMutation().mutationFn).toBe('function');
  });
});

describe('updateBudgetMutation()', () => {
  it('returns mutationKey ["budgets", id, "update"]', () => {
    expect(updateBudgetMutation('abc').mutationKey).toEqual(['budgets', 'abc', 'update']);
  });

  it('has a mutationFn function', () => {
    expect(typeof updateBudgetMutation('abc').mutationFn).toBe('function');
  });
});

describe('deleteBudgetMutation()', () => {
  it('returns mutationKey ["budgets", id, "delete"]', () => {
    expect(deleteBudgetMutation('abc').mutationKey).toEqual(['budgets', 'abc', 'delete']);
  });

  it('has a mutationFn function', () => {
    expect(typeof deleteBudgetMutation('abc').mutationFn).toBe('function');
  });
});

describe('budgetSpendQuery()', () => {
  it('returns query key ["budgets", id, "spend"]', () => {
    expect(budgetSpendQuery('abc').queryKey).toEqual(['budgets', 'abc', 'spend']);
  });

  it('is disabled when id is empty', () => {
    expect(budgetSpendQuery('').enabled).toBe(false);
  });

  it('is enabled when id is non-empty', () => {
    expect(budgetSpendQuery('abc').enabled).toBe(true);
  });

  it('has staleTime of 15_000', () => {
    expect(budgetSpendQuery('abc').staleTime).toBe(15_000);
  });
});

describe('checkBudgetMutation()', () => {
  it('returns mutationKey ["budgets", id, "check"]', () => {
    expect(checkBudgetMutation('abc').mutationKey).toEqual(['budgets', 'abc', 'check']);
  });

  it('has a mutationFn function', () => {
    expect(typeof checkBudgetMutation('abc').mutationFn).toBe('function');
  });
});
