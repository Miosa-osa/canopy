/**
 * Greeting utility — returns a time-aware salutation string.
 *
 * Hour ranges (local time):
 *   0–4   → "Late night"
 *   5–11  → "Good morning"
 *   12–16 → "Good afternoon"
 *   17–20 → "Good evening"
 *   21–23 → "Good night"
 */

export type GreetingPeriod =
  | 'Late night'
  | 'Good morning'
  | 'Good afternoon'
  | 'Good evening'
  | 'Good night';

export function greetingFor(hour: number): GreetingPeriod {
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 21) return 'Good evening';
  if (hour >= 21) return 'Good night';
  return 'Late night'; // 0–4
}
