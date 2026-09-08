import { describe, expect, it } from 'vitest';
import type { SandboxState, SandboxStateRow } from '$lib/domain/sandboxes_ng/types.js';
import { activeSandboxes } from './SandboxQuickActions.svelte';

function row(state: SandboxState): SandboxStateRow {
  return {
    sandboxId: state,
    state,
    priorState: null,
    ts: '2026-09-08T12:00:00Z',
    ownerAgentId: null,
    workspaceSlug: 'default',
    reason: null,
    payload: {},
  };
}

describe('active sandbox picker', () => {
  it('does not offer archived, destroyed, or errored sandboxes', () => {
    const rows = [
      'running',
      'paused',
      'provisioning',
      'resizing',
      'snapshotting',
      'archived',
      'destroyed',
      'error',
    ].map((state) => row(state as SandboxState));
    expect(activeSandboxes(rows).map(({ state }) => state)).toEqual([
      'running',
      'paused',
      'provisioning',
      'resizing',
      'snapshotting',
    ]);
  });
});
