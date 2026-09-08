import { render } from 'svelte/server';
import { describe, expect, it, vi } from 'vitest';
import CompleteStep from './CompleteStep.svelte';

vi.mock('$app/navigation', () => ({ goto: vi.fn() }));
vi.mock('$lib/stores/profile.svelte.js', () => ({ profile: { displayName: 'Roberto' } }));

describe('onboarding completion without verified setup', () => {
  it('offers setup guidance without claiming skipped steps succeeded', () => {
    const { body } = render(CompleteStep, {
      props: { onComplete: vi.fn(), onBack: vi.fn() },
    });

    expect(body).toContain('You can finish setup');
    expect(body).toContain('Open Build');
    expect(body).not.toContain('configured and ready');
    expect(body).not.toContain('agents are standing by');
    for (const claim of [
      'Workspace configured',
      'Runtimes detected',
      'Agents hired',
      'Theme selected',
    ]) {
      expect(body).not.toContain(claim);
    }
  });
});
