import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

// Re-export bits-ui utility types that shadcn-svelte primitives import from $lib/utils
export type { WithElementRef, WithoutChildrenOrChild } from 'bits-ui';

/**
 * Merges class names using clsx + tailwind-merge.
 * Used by shadcn-svelte primitives and all Canopy components.
 */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

/**
 * Branded type helper — narrows a string to a specific semantic type.
 * Usage: type SessionId = Branded<string, 'SessionId'>
 */
export type Branded<T, B> = T & { readonly __brand: B };
