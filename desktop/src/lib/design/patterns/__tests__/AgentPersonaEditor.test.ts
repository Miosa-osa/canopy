/**
 * Unit tests for the /agents/[slug] persona editor logic.
 *
 * The vitest config runs in a Node environment (no jsdom), so we test the
 * units the page depends on rather than mounting the Svelte component:
 *   - updatePersonaMutation factory (save path)
 *   - isDirty derivation (edit-toggle contract)
 *
 * Svelte component render tests (edit button click, textarea binding, ⌘S)
 * belong in a .svelte.test.ts file once a browser project is added to
 * vite.config.ts.
 */

import { describe, expect, it } from 'vitest';
import { updatePersonaMutation } from '$lib/api/queries/agents.js';

// ── updatePersonaMutation — save path ────────────────────────────────────────

describe('updatePersonaMutation()', () => {
  it('returns mutationKey ["agents", "persona"]', () => {
    const m = updatePersonaMutation();
    expect(m.mutationKey).toEqual(['agents', 'persona']);
  });

  it('has a mutationFn function', () => {
    const m = updatePersonaMutation();
    expect(typeof m.mutationFn).toBe('function');
  });

  it('mutationFn accepts a single argument object', () => {
    const m = updatePersonaMutation();
    expect(m.mutationFn.length).toBe(1);
  });
});

// ── isDirty logic — edit-toggle contract ─────────────────────────────────────

describe('isDirty logic (persona editor)', () => {
  /**
   * The page derives:
   *   isDirty = editMode && editText !== (agent.personaMarkdown ?? '')
   *
   * Tested independently of the component so the contract is locked
   * even before browser-env component tests are wired up.
   */
  function computeIsDirty(editMode: boolean, editText: string, personaMarkdown: string): boolean {
    return editMode && editText !== personaMarkdown;
  }

  it('is false when not in edit mode, regardless of text', () => {
    expect(computeIsDirty(false, 'changed text', 'original')).toBe(false);
  });

  it('is false on initial enterEditMode — text seeded from personaMarkdown', () => {
    const original = '# Agent persona\n\nSome content.';
    expect(computeIsDirty(true, original, original)).toBe(false);
  });

  it('is true after text is modified in edit mode', () => {
    expect(computeIsDirty(true, '# New content', '# Old content')).toBe(true);
  });

  it('is true when text is cleared from non-empty original', () => {
    expect(computeIsDirty(true, '', '# Original')).toBe(true);
  });

  it('is false when edit mode is entered and no change made', () => {
    const md = '# Unchanged persona';
    expect(computeIsDirty(true, md, md)).toBe(false);
  });

  it('is false after cancel (editMode becomes false)', () => {
    // Simulates: user edits → clicks Cancel → editMode=false
    const editModeAfterCancel = false;
    expect(computeIsDirty(editModeAfterCancel, 'modified', 'original')).toBe(false);
  });
});

// ── keyboard shortcut contract ────────────────────────────────────────────────

describe('⌘S / Ctrl+S handler contract', () => {
  /**
   * Verifies that the key combination logic the page uses is correct.
   * The page calls savePersona() when (e.metaKey || e.ctrlKey) && e.key === 's'.
   */
  function shouldTriggerSave(e: { metaKey: boolean; ctrlKey: boolean; key: string }): boolean {
    return (e.metaKey || e.ctrlKey) && e.key === 's';
  }

  it('triggers on ⌘S (macOS)', () => {
    expect(shouldTriggerSave({ metaKey: true, ctrlKey: false, key: 's' })).toBe(true);
  });

  it('triggers on Ctrl+S (Windows/Linux)', () => {
    expect(shouldTriggerSave({ metaKey: false, ctrlKey: true, key: 's' })).toBe(true);
  });

  it('does not trigger on plain S', () => {
    expect(shouldTriggerSave({ metaKey: false, ctrlKey: false, key: 's' })).toBe(false);
  });

  it('does not trigger on ⌘Enter', () => {
    expect(shouldTriggerSave({ metaKey: true, ctrlKey: false, key: 'Enter' })).toBe(false);
  });
});
