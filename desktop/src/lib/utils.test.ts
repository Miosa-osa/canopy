import { describe, expect, it } from 'vitest';
import { cn } from './utils.js';

describe('cn()', () => {
  it('should merge class names and resolve Tailwind conflicts', () => {
    const result = cn('px-2 py-1', 'px-4');
    // tailwind-merge resolves px conflict: last one wins
    expect(result).toBe('py-1 px-4');
  });

  it('should handle conditional classes via clsx', () => {
    const active = true;
    const result = cn('base-class', active && 'active', !active && 'inactive');
    expect(result).toBe('base-class active');
  });

  it('should strip falsy values', () => {
    const result = cn('a', undefined, null, false, 'b');
    expect(result).toBe('a b');
  });
});
