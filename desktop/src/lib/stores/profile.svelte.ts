/**
 * profile.svelte.ts — Local user profile store.
 * Persists display name + email to localStorage until multi-user auth ships.
 * Read by GreetingHeadline and anywhere else that needs the user's name.
 */

const LS_KEY = 'canopy:profile';

interface ProfileData {
  displayName: string;
  email: string;
}

function loadFromStorage(): ProfileData {
  if (typeof localStorage === 'undefined') return { displayName: '', email: '' };
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return { displayName: '', email: '' };
    const parsed = JSON.parse(raw) as Partial<ProfileData>;
    return {
      displayName: parsed.displayName ?? '',
      email: parsed.email ?? '',
    };
  } catch {
    return { displayName: '', email: '' };
  }
}

class ProfileStore {
  #data = $state<ProfileData>(loadFromStorage());

  get displayName(): string {
    return this.#data.displayName;
  }

  get email(): string {
    return this.#data.email;
  }

  setDisplayName(name: string): void {
    this.#data = { ...this.#data, displayName: name };
    this.#persist();
  }

  setEmail(email: string): void {
    this.#data = { ...this.#data, email };
    this.#persist();
  }

  #persist(): void {
    if (typeof localStorage === 'undefined') return;
    localStorage.setItem(LS_KEY, JSON.stringify(this.#data));
  }
}

export const profile = new ProfileStore();
