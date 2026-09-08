import { describe, expect, it, vi } from 'vitest';
import { chooseOnboardingFolder, hireStarterAgents } from './setup-actions.js';

const { isTauri, open, hireAgent } = vi.hoisted(() => ({
  isTauri: vi.fn(() => false),
  open: vi.fn(),
  hireAgent: vi.fn(),
}));
vi.mock('$lib/tauri/index.js', () => ({
  isTauri,
  getTauriDialog: async () => ({ open }),
}));
vi.mock('$lib/api/queries/agents.js', () => ({ hireAgent }));

describe('onboarding setup outcomes', () => {
  it('rejects browser folder selection without fabricating a path', async () => {
    await expect(chooseOnboardingFolder()).rejects.toThrow('requires the Canopy desktop app');
    expect(open).not.toHaveBeenCalled();
  });

  it('separates successful hires from failures so retry only repeats failed requests', async () => {
    hireAgent.mockImplementation(async (slug: string) => {
      if (slug === 'forge') throw new Error('Not found');
      return { slug };
    });
    expect(await hireStarterAgents(['iris', 'forge'])).toEqual({
      hired: ['iris'],
      failed: ['forge'],
    });
  });
});
