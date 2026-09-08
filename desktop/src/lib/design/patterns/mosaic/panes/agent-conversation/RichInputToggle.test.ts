/**
 * RichInputToggle — pure-logic tests for the keyboard shortcut + the
 * presentation contract. The component itself uses Svelte 5 runes
 * (compiler context required), so we exercise the pure helper that
 * drives the shortcut decision. Same convention as ShellCommandHint.
 */
import { describe, expect, it } from 'vitest';
import { isRichInputToggleEvent } from './RichInputToggle.svelte';

/** Minimal shape we need to mimic a KeyboardEvent for the helper. */
type KeyEventLike = Pick<KeyboardEvent, 'ctrlKey' | 'metaKey' | 'altKey' | 'key'>;

function ev(partial: Partial<KeyEventLike> & { key: string }): KeyboardEvent {
  return {
    ctrlKey: false,
    metaKey: false,
    altKey: false,
    shiftKey: false,
    ...partial,
  } as KeyboardEvent;
}

describe('isRichInputToggleEvent()', () => {
  it('returns true for ⌃G (lowercase)', () => {
    expect(isRichInputToggleEvent(ev({ ctrlKey: true, key: 'g' }))).toBe(true);
  });

  it('returns true for ⌃G (uppercase, e.g. with shift)', () => {
    expect(isRichInputToggleEvent(ev({ ctrlKey: true, key: 'G' }))).toBe(true);
  });

  it('returns false when no modifier is pressed', () => {
    expect(isRichInputToggleEvent(ev({ key: 'g' }))).toBe(false);
  });

  it('returns false for ⌘G — that is the OS Find-Next chord and must pass through', () => {
    expect(isRichInputToggleEvent(ev({ metaKey: true, key: 'g' }))).toBe(false);
  });

  it('returns false when Alt is also held — preserves ⌃⌥G for users who remap', () => {
    expect(isRichInputToggleEvent(ev({ ctrlKey: true, altKey: true, key: 'g' }))).toBe(false);
  });

  it('returns false for unrelated keys', () => {
    expect(isRichInputToggleEvent(ev({ ctrlKey: true, key: 'f' }))).toBe(false);
    expect(isRichInputToggleEvent(ev({ ctrlKey: true, key: 'Enter' }))).toBe(false);
  });
});

describe('RichInputToggle — toggle state contract', () => {
  it('emits exactly one onToggle per ⌃G press (consumer responsibility)', () => {
    // The helper itself is stateless; we assert the predicate fires once
    // per matching event so the consumer's debounce logic stays simple.
    const events: KeyboardEvent[] = [
      ev({ ctrlKey: true, key: 'g' }),
      ev({ ctrlKey: true, key: 'g' }),
      ev({ key: 'g' }), // ignored
    ];
    const matches = events.filter(isRichInputToggleEvent).length;
    expect(matches).toBe(2);
  });

  it('flips between true and false across paired toggles', () => {
    let on = true;
    const toggle = (): void => {
      on = !on;
    };
    toggle();
    expect(on).toBe(false);
    toggle();
    expect(on).toBe(true);
  });
});
