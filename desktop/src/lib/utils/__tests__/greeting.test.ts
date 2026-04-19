/**
 * Unit tests for greetingFor(hour).
 * Covers all 5 period boundaries and representative mid-range values.
 */
import { describe, expect, it } from "vitest";
import { greetingFor } from "../greeting.js";

describe("greetingFor()", () => {
  // Late night: 0–4
  it('returns "Late night" at hour 0', () => {
    expect(greetingFor(0)).toBe("Late night");
  });
  it('returns "Late night" at hour 4', () => {
    expect(greetingFor(4)).toBe("Late night");
  });

  // Good morning: 5–11
  it('returns "Good morning" at hour 5 (boundary)', () => {
    expect(greetingFor(5)).toBe("Good morning");
  });
  it('returns "Good morning" at hour 9', () => {
    expect(greetingFor(9)).toBe("Good morning");
  });
  it('returns "Good morning" at hour 11', () => {
    expect(greetingFor(11)).toBe("Good morning");
  });

  // Good afternoon: 12–16
  it('returns "Good afternoon" at hour 12 (boundary)', () => {
    expect(greetingFor(12)).toBe("Good afternoon");
  });
  it('returns "Good afternoon" at hour 14', () => {
    expect(greetingFor(14)).toBe("Good afternoon");
  });
  it('returns "Good afternoon" at hour 16', () => {
    expect(greetingFor(16)).toBe("Good afternoon");
  });

  // Good evening: 17–20
  it('returns "Good evening" at hour 17 (boundary)', () => {
    expect(greetingFor(17)).toBe("Good evening");
  });
  it('returns "Good evening" at hour 19', () => {
    expect(greetingFor(19)).toBe("Good evening");
  });
  it('returns "Good evening" at hour 20', () => {
    expect(greetingFor(20)).toBe("Good evening");
  });

  // Good night: 21–23
  it('returns "Good night" at hour 21 (boundary)', () => {
    expect(greetingFor(21)).toBe("Good night");
  });
  it('returns "Good night" at hour 23', () => {
    expect(greetingFor(23)).toBe("Good night");
  });
});
