<script lang="ts">
  import { goto } from '$app/navigation';
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';
  import { auth, persistToken, resetInitPromise, ApiError } from '$api/client';
  import { isTauri } from '$lib/utils/platform';

  // ── State ─────────────────────────────────────────────────────────────────

  let mode = $state<'login' | 'register'>('login');
  let statusLoading = $state(true);

  // Form fields
  let name = $state('');
  let email = $state('');
  let password = $state('');
  let confirmPassword = $state('');

  // UI state
  let showPassword = $state(false);
  let showConfirmPassword = $state(false);
  let isSubmitting = $state(false);
  let errorMessage = $state('');
  let fieldErrors = $state<Record<string, string>>({});

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  onMount(async () => {
    if (!browser) return;

    // In local desktop mode (Tauri), auth is optional — only needed for
    // MiosaCloud sync. If the user lands here directly, redirect them to
    // the appropriate screen instead of showing the login form.
    if (isTauri()) {
      const dest = isOnboardingComplete() ? '/app' : '/onboarding';
      goto(dest, { replaceState: true });
      return;
    }

    // initializeAuth() is a singleton — safe to call multiple times.
    // It probes /health, reads /auth/status to set _firstRun, and restores
    // or verifies any saved token.
    const { initializeAuth, isMockEnabled, getToken, isFirstRun } = await import('$api/client');
    await initializeAuth();

    // If backend is unreachable, stay in mock mode → go to offline onboarding.
    if (isMockEnabled()) {
      goto('/onboarding', { replaceState: true });
      return;
    }

    // Dev auto-login may have already produced a valid token — skip auth UI.
    if (getToken()) {
      const onboardingDone = isOnboardingComplete();
      goto(onboardingDone ? '/app' : '/onboarding', { replaceState: true });
      return;
    }

    // Use the _firstRun flag set during initializeAuth() to pick the right form.
    mode = isFirstRun() ? 'register' : 'login';
    statusLoading = false;
  });

  /** Read both localStorage onboarding keys (handles legacy + new format). */
  function isOnboardingComplete(): boolean {
    if (typeof localStorage === 'undefined') return false;
    if (localStorage.getItem('canopy-onboarding-complete') === 'true') return true;
    try {
      const raw = localStorage.getItem('canopy-onboarding');
      return raw ? (JSON.parse(raw) as { completed?: boolean }).completed === true : false;
    } catch {
      return false;
    }
  }

  // ── Derived ───────────────────────────────────────────────────────────────

  const isRegisterMode = $derived(mode === 'register');
  const submitLabel = $derived(isRegisterMode ? 'Create account' : 'Sign in');
  const headingText = $derived(isRegisterMode ? 'Connect to MiosaCloud' : 'Sign in to MiosaCloud');
  const subheadingText = $derived(
    isRegisterMode
      ? 'Create an account to enable cloud sync, backups, and cross-device access'
      : 'Sign in to enable MiosaCloud sync — not required for local use'
  );

  // ── Validation ────────────────────────────────────────────────────────────

  function validate(): boolean {
    const errors: Record<string, string> = {};

    if (isRegisterMode && !name.trim()) {
      errors.name = 'Full name is required';
    }

    if (!email.trim()) {
      errors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      errors.email = 'Enter a valid email address';
    }

    if (!password) {
      errors.password = 'Password is required';
    } else if (isRegisterMode && password.length < 8) {
      errors.password = 'Password must be at least 8 characters';
    }

    if (isRegisterMode && password !== confirmPassword) {
      errors.confirmPassword = 'Passwords do not match';
    }

    fieldErrors = errors;
    return Object.keys(errors).length === 0;
  }

  // ── Error resolution ──────────────────────────────────────────────────────

  /**
   * Convert API errors (and network failures) into human-readable messages.
   * The backend returns `{error: "validation_failed", details: {email: [...], password: [...]}}`.
   * We decode `details` and pick the most actionable message.
   */
  function resolveErrorMessage(err: unknown, isRegister: boolean): string {
    // Network-level failure (fetch rejected — no response at all)
    if (!(err instanceof ApiError)) {
      return "Can't connect to server. Is the backend running?";
    }

    const body = err.body as Record<string, unknown> | null | undefined;
    const code = body && typeof body.error === 'string' ? body.error : err.message;
    const details = body && typeof body.details === 'object' && body.details !== null
      ? body.details as Record<string, unknown>
      : null;

    if (code === 'validation_failed') {
      // Email already taken
      if (details?.email) {
        const emailMsgs = Array.isArray(details.email) ? details.email : [details.email];
        if (emailMsgs.some((m: unknown) => String(m).includes('taken') || String(m).includes('already'))) {
          return 'This email is already registered. Try signing in instead.';
        }
        return `Email: ${emailMsgs[0]}`;
      }
      // Password too short
      if (details?.password) {
        const pwMsgs = Array.isArray(details.password) ? details.password : [details.password];
        if (pwMsgs.some((m: unknown) => String(m).includes('8') || String(m).includes('characters'))) {
          return 'Password must be at least 8 characters.';
        }
        return `Password: ${pwMsgs[0]}`;
      }
      return isRegister ? 'Registration failed. Check your details and try again.' : 'Validation failed.';
    }

    if (code === 'invalid_credentials') {
      return 'Wrong email or password.';
    }

    if (code === 'invalid_request') {
      return typeof body?.details === 'string' ? body.details : 'Invalid request.';
    }

    // Fallback: surface whatever message the server gave
    return err.message || (isRegister ? 'Registration failed.' : 'Sign in failed.');
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  async function handleSubmit(e: Event) {
    e.preventDefault();
    errorMessage = '';
    fieldErrors = {};

    if (!validate()) return;

    isSubmitting = true;
    try {
      if (isRegisterMode) {
        const result = await auth.register({
          name: name.trim(),
          email: email.trim(),
          password,
        });
        // Persist token and reset the init-promise cache so the /app layout
        // guard sees the fresh token on the next initializeAuth() call.
        await persistToken(result.token);
        resetInitPromise();

        // Store registration data for onboarding to pre-fill.
        // Workspace is NOT available at registration — it is created during onboarding.
        localStorage.setItem('canopy-display-name', result.user.name);
        localStorage.setItem('canopy-registered-name', result.user.name);

        // New account → always needs onboarding; do NOT mark it complete.
        goto('/onboarding', { replaceState: true });
      } else {
        const result = await auth.login({
          email: email.trim(),
          password,
        });
        await persistToken(result.token);
        resetInitPromise();

        localStorage.setItem('canopy-display-name', result.user.name);

        // Returning user: honour their existing onboarding state instead of
        // unconditionally marking onboarding complete.  If they haven't
        // finished onboarding for some reason, send them there first.
        const onboardingDone = isOnboardingComplete();
        goto(onboardingDone ? '/app' : '/onboarding', { replaceState: true });
      }
    } catch (err: unknown) {
      errorMessage = resolveErrorMessage(err, isRegisterMode);
    } finally {
      isSubmitting = false;
    }
  }

  // ── Mode toggle ───────────────────────────────────────────────────────────

  function toggleMode() {
    mode = mode === 'login' ? 'register' : 'login';
    errorMessage = '';
    fieldErrors = {};
  }
</script>

<div class="auth-root">
  <!-- Subtle background grid pattern -->
  <div class="auth-bg" aria-hidden="true"></div>

  <div class="auth-container">
    <!-- Logo / Branding -->
    <header class="auth-header">
      <div class="auth-logo" aria-label="Canopy logo">
        <!-- Tree / branching icon -->
        <svg viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg" width="32" height="32" aria-hidden="true">
          <rect width="32" height="32" rx="8" fill="rgba(59,130,246,0.15)"/>
          <path d="M16 6 L16 26 M16 26 L10 20 M16 26 L22 20 M16 16 L10 12 M16 16 L22 12" stroke="#3b82f6" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </div>
      <span class="auth-wordmark">Canopy</span>
    </header>

    <!-- Card -->
    <div class="auth-card">
      {#if statusLoading}
        <div class="auth-loading" role="status" aria-label="Loading">
          <div class="spinner" aria-hidden="true"></div>
          <span class="sr-only">Loading…</span>
        </div>
      {:else}
        <!-- Heading -->
        <div class="auth-card-header">
          <h1 class="auth-title">{headingText}</h1>
          <p class="auth-subtitle">{subheadingText}</p>
        </div>

        <!-- Form -->
        <form class="auth-form" onsubmit={handleSubmit} novalidate>
          <!-- Name field (register only) -->
          {#if isRegisterMode}
            <div class="field-group">
              <label class="field-label" for="name">Full name</label>
              <input
                id="name"
                type="text"
                class="field-input"
                class:field-input--error={!!fieldErrors.name}
                bind:value={name}
                placeholder="Ada Lovelace"
                autocomplete="name"
                aria-describedby={fieldErrors.name ? 'name-error' : undefined}
                aria-invalid={!!fieldErrors.name}
                disabled={isSubmitting}
              />
              {#if fieldErrors.name}
                <span id="name-error" class="field-error" role="alert">{fieldErrors.name}</span>
              {/if}
            </div>
          {/if}

          <!-- Email -->
          <div class="field-group">
            <label class="field-label" for="email">Email address</label>
            <input
              id="email"
              type="email"
              class="field-input"
              class:field-input--error={!!fieldErrors.email}
              bind:value={email}
              placeholder="ada@example.com"
              autocomplete="email"
              aria-describedby={fieldErrors.email ? 'email-error' : undefined}
              aria-invalid={!!fieldErrors.email}
              disabled={isSubmitting}
            />
            {#if fieldErrors.email}
              <span id="email-error" class="field-error" role="alert">{fieldErrors.email}</span>
            {/if}
          </div>

          <!-- Password -->
          <div class="field-group">
            <label class="field-label" for="password">Password</label>
            <div class="field-input-wrap">
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                class="field-input field-input--with-action"
                class:field-input--error={!!fieldErrors.password}
                bind:value={password}
                placeholder={isRegisterMode ? 'At least 8 characters' : '••••••••'}
                autocomplete={isRegisterMode ? 'new-password' : 'current-password'}
                aria-describedby={fieldErrors.password ? 'password-error' : undefined}
                aria-invalid={!!fieldErrors.password}
                disabled={isSubmitting}
              />
              <button
                type="button"
                class="field-eye"
                onclick={() => showPassword = !showPassword}
                aria-label={showPassword ? 'Hide password' : 'Show password'}
              >
                {#if showPassword}
                  <!-- Eye off icon -->
                  <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14" aria-hidden="true">
                    <path d="M2 2l12 12M6.5 6.6A2 2 0 0 0 9.4 9.5M4.2 4.3A7 7 0 0 0 1 8s2.5 4 7 4a6.8 6.8 0 0 0 3.8-1.2M6 3.1A6.8 6.8 0 0 1 8 3c4.5 0 7 4 7 4a12 12 0 0 1-1.6 2.3"/>
                  </svg>
                {:else}
                  <!-- Eye icon -->
                  <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14" aria-hidden="true">
                    <path d="M1 8s2.5-5 7-5 7 5 7 5-2.5 5-7 5-7-5-7-5z"/><circle cx="8" cy="8" r="2"/>
                  </svg>
                {/if}
              </button>
            </div>
            {#if fieldErrors.password}
              <span id="password-error" class="field-error" role="alert">{fieldErrors.password}</span>
            {/if}
          </div>

          <!-- Confirm password (register only) -->
          {#if isRegisterMode}
            <div class="field-group">
              <label class="field-label" for="confirm-password">Confirm password</label>
              <div class="field-input-wrap">
                <input
                  id="confirm-password"
                  type={showConfirmPassword ? 'text' : 'password'}
                  class="field-input field-input--with-action"
                  class:field-input--error={!!fieldErrors.confirmPassword}
                  bind:value={confirmPassword}
                  placeholder="••••••••"
                  autocomplete="new-password"
                  aria-describedby={fieldErrors.confirmPassword ? 'confirm-password-error' : undefined}
                  aria-invalid={!!fieldErrors.confirmPassword}
                  disabled={isSubmitting}
                />
                <button
                  type="button"
                  class="field-eye"
                  onclick={() => showConfirmPassword = !showConfirmPassword}
                  aria-label={showConfirmPassword ? 'Hide confirm password' : 'Show confirm password'}
                >
                  {#if showConfirmPassword}
                    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14" aria-hidden="true">
                      <path d="M2 2l12 12M6.5 6.6A2 2 0 0 0 9.4 9.5M4.2 4.3A7 7 0 0 0 1 8s2.5 4 7 4a6.8 6.8 0 0 0 3.8-1.2M6 3.1A6.8 6.8 0 0 1 8 3c4.5 0 7 4 7 4a12 12 0 0 1-1.6 2.3"/>
                    </svg>
                  {:else}
                    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14" aria-hidden="true">
                      <path d="M1 8s2.5-5 7-5 7 5 7 5-2.5 5-7 5-7-5-7-5z"/><circle cx="8" cy="8" r="2"/>
                    </svg>
                  {/if}
                </button>
              </div>
              {#if fieldErrors.confirmPassword}
                <span id="confirm-password-error" class="field-error" role="alert">{fieldErrors.confirmPassword}</span>
              {/if}
            </div>
          {/if}

          <!-- Global error -->
          {#if errorMessage}
            <div class="auth-error" role="alert" aria-live="polite">
              <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14" aria-hidden="true">
                <circle cx="8" cy="8" r="7"/><path d="M8 5v4M8 11v.5"/>
              </svg>
              <span>{errorMessage}</span>
            </div>
          {/if}

          <!-- Submit -->
          <button
            type="submit"
            class="auth-submit"
            disabled={isSubmitting}
            aria-busy={isSubmitting}
          >
            {#if isSubmitting}
              <div class="btn-spinner" aria-hidden="true"></div>
              <span>{isRegisterMode ? 'Creating account…' : 'Signing in…'}</span>
            {:else}
              <span>{submitLabel}</span>
              <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14" aria-hidden="true">
                <path d="M3 8h10M9 4l4 4-4 4"/>
              </svg>
            {/if}
          </button>
        </form>

        <!-- Toggle mode link -->
        <div class="auth-toggle">
          {#if isRegisterMode}
            <span>Already have an account?</span>
            <button type="button" class="auth-toggle-link" onclick={toggleMode}>
              Sign in
            </button>
          {:else}
            <span>No account yet?</span>
            <button type="button" class="auth-toggle-link" onclick={toggleMode}>
              Create one
            </button>
          {/if}
        </div>
      {/if}
    </div>

    <!-- Footer -->
    <footer class="auth-footer">
      <span>Canopy</span>
      <span aria-hidden="true">·</span>
      <span>AI agent orchestration</span>
    </footer>
  </div>
</div>

<style>
  /* ── Root ──────────────────────────────────────────────────────────────── */

  .auth-root {
    min-height: 100dvh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 2rem 1rem;
    background: var(--bg-primary, #0a0a0a);
    color: var(--text-primary, #ffffff);
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
    position: relative;
    overflow: hidden;
  }

  /* Subtle radial accent */
  .auth-root::before {
    content: '';
    position: fixed;
    inset: 0;
    background:
      radial-gradient(ellipse 80% 50% at 50% -10%, rgba(59, 130, 246, 0.08) 0%, transparent 70%),
      radial-gradient(ellipse 50% 30% at 80% 80%, rgba(59, 130, 246, 0.04) 0%, transparent 60%);
    pointer-events: none;
  }

  /* Grid pattern overlay */
  .auth-bg {
    position: fixed;
    inset: 0;
    pointer-events: none;
    background-image:
      linear-gradient(rgba(255,255,255,0.015) 1px, transparent 1px),
      linear-gradient(90deg, rgba(255,255,255,0.015) 1px, transparent 1px);
    background-size: 40px 40px;
    mask-image: radial-gradient(ellipse at center, black 30%, transparent 75%);
  }

  /* ── Container ────────────────────────────────────────────────────────── */

  .auth-container {
    position: relative;
    width: 100%;
    max-width: 400px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1.5rem;
  }

  /* ── Header / Logo ────────────────────────────────────────────────────── */

  .auth-header {
    display: flex;
    align-items: center;
    gap: 0.625rem;
  }

  .auth-logo {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border-radius: 8px;
    flex-shrink: 0;
  }

  .auth-wordmark {
    font-size: 1.125rem;
    font-weight: 600;
    letter-spacing: -0.02em;
    color: var(--text-primary, #ffffff);
  }

  /* ── Card ─────────────────────────────────────────────────────────────── */

  .auth-card {
    width: 100%;
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(24px);
    -webkit-backdrop-filter: blur(24px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 20px;
    box-shadow:
      0 8px 32px rgba(0, 0, 0, 0.25),
      0 2px 8px rgba(0, 0, 0, 0.15),
      inset 0 1px 0 rgba(255, 255, 255, 0.08);
    padding: 2rem;
    min-height: 200px;
    display: flex;
    flex-direction: column;
  }

  .auth-card-header {
    margin-bottom: 1.75rem;
  }

  .auth-title {
    font-size: 1.25rem;
    font-weight: 600;
    letter-spacing: -0.02em;
    color: var(--text-primary, #ffffff);
    margin: 0 0 0.375rem;
  }

  .auth-subtitle {
    font-size: 0.8125rem;
    color: var(--text-secondary, #a0a0a0);
    margin: 0;
    line-height: 1.5;
  }

  /* ── Loading ──────────────────────────────────────────────────────────── */

  .auth-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    flex: 1;
    min-height: 120px;
  }

  /* ── Form ─────────────────────────────────────────────────────────────── */

  .auth-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  /* ── Field ────────────────────────────────────────────────────────────── */

  .field-group {
    display: flex;
    flex-direction: column;
    gap: 0.375rem;
  }

  .field-label {
    font-size: 0.8125rem;
    font-weight: 500;
    color: var(--text-secondary, #a0a0a0);
    cursor: pointer;
  }

  .field-input-wrap {
    position: relative;
  }

  .field-input {
    width: 100%;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 10px;
    padding: 0.625rem 0.875rem;
    font-size: 0.875rem;
    color: var(--text-primary, #ffffff);
    outline: none;
    transition: border-color 150ms ease, background 150ms ease, box-shadow 150ms ease;
    box-sizing: border-box;
  }

  .field-input::placeholder {
    color: var(--text-tertiary, #666666);
  }

  .field-input:focus {
    border-color: rgba(59, 130, 246, 0.6);
    background: rgba(59, 130, 246, 0.04);
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
  }

  .field-input--error {
    border-color: rgba(239, 68, 68, 0.6) !important;
    background: rgba(239, 68, 68, 0.04) !important;
  }

  .field-input--error:focus {
    box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1) !important;
  }

  .field-input--with-action {
    padding-right: 2.5rem;
  }

  .field-input:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* Password visibility toggle */
  .field-eye {
    position: absolute;
    right: 0.625rem;
    top: 50%;
    transform: translateY(-50%);
    background: none;
    border: none;
    padding: 0.25rem;
    color: var(--text-tertiary, #666666);
    cursor: pointer;
    display: flex;
    align-items: center;
    border-radius: 4px;
    transition: color 150ms ease;
  }

  .field-eye:hover {
    color: var(--text-secondary, #a0a0a0);
  }

  /* Field error */
  .field-error {
    font-size: 0.75rem;
    color: var(--accent-error, #ef4444);
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  /* ── Global error banner ──────────────────────────────────────────────── */

  .auth-error {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    padding: 0.75rem;
    background: rgba(239, 68, 68, 0.08);
    border: 1px solid rgba(239, 68, 68, 0.2);
    border-radius: 10px;
    color: #fca5a5;
    font-size: 0.8125rem;
    line-height: 1.5;
  }

  .auth-error svg {
    flex-shrink: 0;
    margin-top: 1px;
  }

  /* ── Submit button ────────────────────────────────────────────────────── */

  .auth-submit {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0.75rem 1.25rem;
    background: linear-gradient(180deg, #1d4ed8 0%, #1e3a8a 100%);
    border: 1px solid rgba(59, 130, 246, 0.4);
    border-radius: 10px;
    color: #ffffff;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    transition: opacity 150ms ease, transform 150ms ease, box-shadow 150ms ease;
    box-shadow:
      0 1px 0 0 rgba(255, 255, 255, 0.1) inset,
      0 4px 16px 0 rgba(29, 78, 216, 0.3);
    margin-top: 0.5rem;
    position: relative;
    overflow: hidden;
  }

  .auth-submit::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 50%;
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.12) 0%, transparent 100%);
    border-radius: inherit;
    pointer-events: none;
  }

  .auth-submit:not(:disabled):hover {
    transform: translateY(-1px);
    box-shadow:
      0 1px 0 0 rgba(255, 255, 255, 0.15) inset,
      0 6px 24px 0 rgba(29, 78, 216, 0.4);
  }

  .auth-submit:not(:disabled):active {
    transform: translateY(0);
  }

  .auth-submit:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  /* ── Spinners ─────────────────────────────────────────────────────────── */

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .spinner,
  .btn-spinner {
    border-radius: 50%;
    animation: spin 700ms linear infinite;
    flex-shrink: 0;
  }

  .spinner {
    width: 24px;
    height: 24px;
    border: 2px solid rgba(255, 255, 255, 0.1);
    border-top-color: rgba(255, 255, 255, 0.6);
  }

  .btn-spinner {
    width: 14px;
    height: 14px;
    border: 2px solid rgba(255, 255, 255, 0.25);
    border-top-color: #ffffff;
  }

  /* ── Mode toggle ──────────────────────────────────────────────────────── */

  .auth-toggle {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.375rem;
    margin-top: 1.25rem;
    padding-top: 1.25rem;
    border-top: 1px solid rgba(255, 255, 255, 0.06);
    font-size: 0.8125rem;
    color: var(--text-tertiary, #666666);
  }

  .auth-toggle-link {
    background: none;
    border: none;
    padding: 0;
    color: var(--accent-primary, #3b82f6);
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    transition: color 150ms ease;
    text-decoration: none;
  }

  .auth-toggle-link:hover {
    color: #60a5fa;
    text-decoration: underline;
  }

  /* ── Footer ───────────────────────────────────────────────────────────── */

  .auth-footer {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.75rem;
    color: var(--text-muted, #404040);
  }

  /* ── Screen reader only ───────────────────────────────────────────────── */

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border-width: 0;
  }

  /* ── Responsive ───────────────────────────────────────────────────────── */

  @media (max-width: 480px) {
    .auth-card {
      padding: 1.5rem;
      border-radius: 16px;
    }
  }
</style>
