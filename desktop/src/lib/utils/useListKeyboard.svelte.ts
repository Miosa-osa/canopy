/**
 * useListKeyboard — reusable keyboard navigation for list views.
 * Contract (docs/02-frontend-design.md §8):
 *   j / ↓   next item
 *   k / ↑   previous item
 *   ↵       open selected (calls onSelect)
 *   r       refresh (calls onRefresh, if provided)
 *   ?       show shortcut help (calls onHelp, if provided)
 *   Esc     clear selection (sets selectedIndex to -1)
 *
 * Usage:
 *   const kb = useListKeyboard({ items, onSelect });
 *   <div onkeydown={kb.handleKeydown}>…</div>
 *   {#if kb.selectedIndex === i} class:active {/if}
 *
 * LOC target: ≤ 80.
 */

export interface UseListKeyboardOptions<T> {
  /** Reactive items array — pass as a getter so it stays in sync. */
  items: () => T[];
  /** Called when ↵ is pressed on selectedIndex ≥ 0. */
  onSelect: (item: T, index: number) => void;
  /** Called when `r` is pressed — typically invalidates TanStack Query. */
  onRefresh?: () => void;
  /** Called when `?` is pressed — show shortcut help overlay. */
  onHelp?: () => void;
}

export interface UseListKeyboardReturn {
  /** Currently highlighted index, -1 means no selection. */
  readonly selectedIndex: number;
  /** Attach to the container element's onkeydown. */
  handleKeydown: (e: KeyboardEvent) => void;
  /** Programmatically clear selection. */
  clearSelection: () => void;
}

export function useListKeyboard<T>(opts: UseListKeyboardOptions<T>): UseListKeyboardReturn {
  let selectedIndex = $state(-1);

  function handleKeydown(e: KeyboardEvent): void {
    // Skip if a modifier is held (except Shift for ? on some keyboards)
    if (e.metaKey || e.ctrlKey || e.altKey) return;

    // Skip if focus is inside a text input/textarea
    const target = e.target as HTMLElement;
    if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA' || target.isContentEditable) {
      return;
    }

    const items = opts.items();
    const len = items.length;
    if (len === 0) return;

    switch (e.key) {
      case 'ArrowDown':
      case 'j':
        e.preventDefault();
        selectedIndex = selectedIndex < len - 1 ? selectedIndex + 1 : 0;
        break;

      case 'ArrowUp':
      case 'k':
        e.preventDefault();
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : len - 1;
        break;

      case 'Enter':
        if (selectedIndex >= 0 && selectedIndex < len) {
          e.preventDefault();
          opts.onSelect(items[selectedIndex], selectedIndex);
        }
        break;

      case 'r':
        e.preventDefault();
        opts.onRefresh?.();
        break;

      case '?':
        e.preventDefault();
        opts.onHelp?.();
        break;

      case 'Escape':
        e.preventDefault();
        selectedIndex = -1;
        break;

      default:
        break;
    }
  }

  function clearSelection(): void {
    selectedIndex = -1;
  }

  return {
    get selectedIndex() {
      return selectedIndex;
    },
    handleKeydown,
    clearSelection,
  };
}
