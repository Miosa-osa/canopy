import { afterEach, describe, expect, it, vi } from 'vitest';
import { workspacePinsQuery } from './pins.js';

afterEach(() => vi.unstubAllGlobals());

describe('workspace pins API boundary', () => {
  it.each([
    [],
    [
      {
        id: 'pin-1',
        workspace_slug: 'test',
        item_type: 'file',
        item_ref: 'README.md',
        position: 0,
      },
    ],
  ])('returns pins from a wrapped backend response', async (...args) => {
    const pins = args;
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => Response.json({ data: pins }))
    );
    const result = await workspacePinsQuery('test').queryFn();
    expect(Array.isArray(result)).toBe(true);
    expect(result).toHaveLength(pins.length);
    if (pins.length > 0)
      expect(result[0]).toMatchObject({ workspaceSlug: 'test', itemRef: 'README.md' });
  });
});
