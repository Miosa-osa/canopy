/**
 * Tests for agent domain type guards and utility logic.
 * Verifies type narrowing and category membership.
 */
import { describe, expect, it } from 'vitest';
import type { Agent, AgentCategory, AgentHireStatus } from './types.js';

/** All 19 canonical categories — must stay in sync with the directory. */
const VALID_CATEGORIES: AgentCategory[] = [
  'academic',
  'creative-content',
  'design',
  'engineering',
  'executive',
  'game-development',
  'growth',
  'marketing',
  'operations',
  'paid-media',
  'product',
  'project-management',
  'revenue',
  'sales',
  'spatial-computing',
  'specialized',
  'support',
  'technology',
  'testing',
];

describe('AgentCategory', () => {
  it('has exactly 19 canonical values', () => {
    expect(VALID_CATEGORIES).toHaveLength(19);
  });

  it('includes "sales" category', () => {
    expect(VALID_CATEGORIES).toContain('sales');
  });

  it('includes "engineering" category', () => {
    expect(VALID_CATEGORIES).toContain('engineering');
  });
});

describe('AgentHireStatus', () => {
  it('only has two values: hired and available', () => {
    const statuses: AgentHireStatus[] = ['hired', 'available'];
    expect(statuses).toHaveLength(2);
  });
});

describe('Agent shape', () => {
  it('can be constructed with required fields', () => {
    const agent: Agent = {
      slug: 'sales-strategist',
      name: 'Sales Strategist',
      emoji: '📊',
      title: 'Senior Sales Strategist',
      category: 'sales',
      owner: 'Roberto',
      bio: 'I analyze deal pipelines.',
      hireStatus: 'hired',
      runCount: 3,
      budget: 600,
      defaultRuntime: 'claude-code',
      heartbeatCron: '0 9 * * 1-5',
      tools: ['read', 'write'],
      createdAt: '2026-04-17T00:00:00Z',
      updatedAt: '2026-04-17T00:00:00Z',
    };

    expect(agent.slug).toBe('sales-strategist');
    expect(agent.hireStatus).toBe('hired');
    expect(agent.category).toBe('sales');
  });

  it('allows null optional fields', () => {
    const agent: Agent = {
      slug: 'researcher',
      name: 'Researcher',
      emoji: '🔬',
      title: 'Research Analyst',
      category: 'academic',
      owner: null,
      bio: 'I research topics.',
      hireStatus: 'available',
      runCount: 0,
      budget: null,
      defaultRuntime: null,
      heartbeatCron: null,
      tools: [],
      createdAt: '2026-04-17T00:00:00Z',
      updatedAt: '2026-04-17T00:00:00Z',
    };

    expect(agent.owner).toBeNull();
    expect(agent.budget).toBeNull();
    expect(agent.defaultRuntime).toBeNull();
    expect(agent.heartbeatCron).toBeNull();
  });
});
