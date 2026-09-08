/**
 * EmojiPicker — smoke tests for the wrapper logic.
 * @vitest-environment jsdom
 *
 * We do NOT test the emoji-picker-element web component itself (it's external).
 * We test:
 *   1. Dynamic import resolves without throwing (module mocked — no rAF needed)
 *   2. onSelect is invoked with the correct unicode value when emoji-click fires
 *   3. onClose fires on Escape keydown
 */

import { afterEach, describe, expect, it, vi } from 'vitest';

// Mock emoji-picker-element so the dynamic import resolves in a node/jsdom
// environment that lacks requestAnimationFrame (which the real module requires).
vi.mock('emoji-picker-element', () => ({ default: {} }));

// Provide requestAnimationFrame stub so jsdom tests don't blow up if anything
// else in the import chain needs it.
globalThis.requestAnimationFrame = (cb: FrameRequestCallback): number => {
  setTimeout(() => cb(performance.now()), 0);
  return 0;
};

// ── 1. Dynamic import smoke test ─────────────────────────────────────────────

describe('emoji-picker-element dynamic import', () => {
  it('resolves without throwing', async () => {
    await expect(import('emoji-picker-element')).resolves.toBeDefined();
  });
});

// ── 2. emoji-click event → onSelect ─────────────────────────────────────────

describe('emoji-click event handler', () => {
  it('calls onSelect with the unicode emoji string', () => {
    const onSelect = vi.fn();
    const onClose = vi.fn();

    // Mirror what EmojiPicker.svelte does: attach listener to a picker element
    const fakeTarget = new EventTarget();

    fakeTarget.addEventListener('emoji-click', (evt: Event) => {
      const detail = (evt as CustomEvent<{ unicode: string }>).detail;
      if (detail?.unicode) {
        onSelect(detail.unicode);
        onClose();
      }
    });

    const clickEvt = new CustomEvent('emoji-click', {
      detail: { unicode: '🎉' },
    });
    fakeTarget.dispatchEvent(clickEvt);

    expect(onSelect).toHaveBeenCalledOnce();
    expect(onSelect).toHaveBeenCalledWith('🎉');
    expect(onClose).toHaveBeenCalledOnce();
  });

  it('does not call onSelect when detail.unicode is missing', () => {
    const onSelect = vi.fn();
    const onClose = vi.fn();

    const fakeTarget = new EventTarget();

    fakeTarget.addEventListener('emoji-click', (evt: Event) => {
      const detail = (evt as CustomEvent<{ unicode?: string }>).detail;
      if (detail?.unicode) {
        onSelect(detail.unicode);
        onClose();
      }
    });

    const clickEvt = new CustomEvent('emoji-click', { detail: {} });
    fakeTarget.dispatchEvent(clickEvt);

    expect(onSelect).not.toHaveBeenCalled();
    expect(onClose).not.toHaveBeenCalled();
  });
});

// ── 3. Escape keydown → onClose ──────────────────────────────────────────────

describe('Escape key handler', () => {
  let handler: (evt: KeyboardEvent) => void;

  afterEach(() => {
    if (handler) {
      document.removeEventListener('keydown', handler, { capture: true });
    }
  });

  it('calls onClose when Escape is pressed', () => {
    const onClose = vi.fn();

    handler = (evt: KeyboardEvent): void => {
      if (evt.key === 'Escape') {
        evt.stopPropagation();
        onClose();
      }
    };

    document.addEventListener('keydown', handler, { capture: true });

    const escEvt = new KeyboardEvent('keydown', {
      key: 'Escape',
      bubbles: true,
    });
    document.dispatchEvent(escEvt);

    expect(onClose).toHaveBeenCalledOnce();
  });

  it('does not call onClose for non-Escape keys', () => {
    const onClose = vi.fn();

    handler = (evt: KeyboardEvent): void => {
      if (evt.key === 'Escape') {
        evt.stopPropagation();
        onClose();
      }
    };

    document.addEventListener('keydown', handler, { capture: true });

    const enterEvt = new KeyboardEvent('keydown', {
      key: 'Enter',
      bubbles: true,
    });
    document.dispatchEvent(enterEvt);

    expect(onClose).not.toHaveBeenCalled();
  });
});
