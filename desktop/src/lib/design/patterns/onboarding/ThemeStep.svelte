<script lang="ts">
/**
 * ThemeStep — step 5 of OnboardingWizard.
 * Richer mini-UI previews per theme. Click applies live.
 * CSS prefix: obw-ts-
 */
import { Check, Moon, Sun } from 'lucide-svelte';
import { themeRegistry, themes } from '$lib/stores/theme-registry.svelte.js';

interface Props {
  onNext: () => void;
  onBack: () => void;
  onSkip: () => void;
}

let { onNext, onBack, onSkip }: Props = $props();

let previewId = $state(themeRegistry.activeThemeId);

function pick(id: string): void {
  previewId = id;
  themeRegistry.setTheme(id);
}
</script>

<div class="obw-ts">
  <p class="obw-ts__hint">
    Choose your color scheme. The app updates live as you click.
  </p>

  <div class="obw-ts__grid" role="listbox" aria-label="Themes">
    {#each themes as theme (theme.id)}
      {@const active = previewId === theme.id}
      <button
        class="obw-ts__card"
        class:obw-ts__card--active={active}
        onclick={() => pick(theme.id)}
        role="option"
        aria-selected={active}
        aria-label="{theme.name} ({theme.variant})"
      >
        <!-- Mini UI mockup using actual theme colors -->
        <div
          class="obw-ts__preview"
          style="
            background: {theme.colors.bg};
            border-color: {theme.colors.border};
          "
        >
          <!-- Sidebar mock -->
          <div class="obw-ts__sidebar" style="background: {theme.colors.bgElevated ?? theme.colors.bg}; border-color: {theme.colors.border};">
            <div class="obw-ts__dot" style="background: {theme.colors.accent};"></div>
            <div class="obw-ts__line" style="background: {theme.colors.fgMuted}; width: 70%;"></div>
            <div class="obw-ts__line" style="background: {theme.colors.fgSubtle}; width: 50%;"></div>
            <div class="obw-ts__line" style="background: {theme.colors.fgSubtle}; width: 60%;"></div>
          </div>
          <!-- Main area mock -->
          <div class="obw-ts__main">
            <div class="obw-ts__topbar" style="border-color: {theme.colors.border};">
              <div class="obw-ts__tab" style="background: {theme.colors.accent}; width: 28px;"></div>
              <div class="obw-ts__tab" style="background: {theme.colors.fgSubtle}; width: 22px;"></div>
            </div>
            <div class="obw-ts__content">
              <div class="obw-ts__block" style="background: {theme.colors.fgMuted}; width: 80%;"></div>
              <div class="obw-ts__block" style="background: {theme.colors.fgSubtle}; width: 60%;"></div>
              <div class="obw-ts__block" style="background: {theme.colors.accent}; width: 45%; opacity: 0.6;"></div>
            </div>
            <div class="obw-ts__composer" style="border-color: {theme.colors.border};">
              <div class="obw-ts__input-mock" style="background: {theme.colors.fgSubtle}; width: 65%;"></div>
            </div>
          </div>
        </div>

        <div class="obw-ts__meta">
          <span class="obw-ts__name">{theme.name}</span>
          <span class="obw-ts__variant">
            {#if theme.variant === 'dark'}
              <Moon size={10} /> Dark
            {:else}
              <Sun size={10} /> Light
            {/if}
          </span>
        </div>

        {#if active}
          <span class="obw-ts__check"><Check size={14} strokeWidth={2.5} /></span>
        {/if}
      </button>
    {/each}
  </div>

  <div class="obw-nav">
    <button class="obw-btn-ghost" onclick={onBack}>← Back</button>
    <div class="obw-nav__right">
      <button class="obw-btn-ghost obw-btn-skip" onclick={onSkip}>Skip</button>
      <button class="obw-btn-primary" onclick={onNext}>Next →</button>
    </div>
  </div>
</div>

<style>
  .obw-ts {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .obw-ts__hint {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-muted);
    line-height: 1.6;
  }

  .obw-ts__grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
  }

  .obw-ts__card {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 0;
    border: 2px solid var(--border);
    border-radius: 10px;
    background: var(--bg-elevated, var(--bg));
    cursor: pointer;
    overflow: hidden;
    position: relative;
    transition: border-color 150ms, box-shadow 150ms;
  }

  .obw-ts__card:hover { border-color: var(--fg-subtle); }

  .obw-ts__card--active {
    border-color: var(--cnp-accent, #6366f1);
    box-shadow: 0 0 0 3px color-mix(in oklch, var(--cnp-accent, #6366f1) 15%, transparent);
  }

  .obw-ts__preview {
    display: flex;
    height: 72px;
    border: 1px solid;
    border-radius: 8px 8px 0 0;
    overflow: hidden;
    margin: 6px 6px 0;
    border-radius: 6px;
  }

  .obw-ts__sidebar {
    width: 28%;
    display: flex;
    flex-direction: column;
    gap: 3px;
    padding: 6px 4px;
    border-right: 1px solid;
  }

  .obw-ts__dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    margin-bottom: 2px;
  }

  .obw-ts__line {
    height: 2px;
    border-radius: 1px;
    opacity: 0.5;
  }

  .obw-ts__main {
    flex: 1;
    display: flex;
    flex-direction: column;
  }

  .obw-ts__topbar {
    display: flex;
    gap: 3px;
    padding: 4px 5px;
    border-bottom: 1px solid;
  }

  .obw-ts__tab {
    height: 3px;
    border-radius: 1px;
  }

  .obw-ts__content {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 3px;
    padding: 6px 5px;
  }

  .obw-ts__block {
    height: 2px;
    border-radius: 1px;
    opacity: 0.4;
  }

  .obw-ts__composer {
    padding: 4px 5px;
    border-top: 1px solid;
  }

  .obw-ts__input-mock {
    height: 3px;
    border-radius: 1px;
    opacity: 0.3;
  }

  .obw-ts__meta {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
    padding: 0 8px 10px;
  }

  .obw-ts__name {
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 600;
    color: var(--fg);
  }

  .obw-ts__variant {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    display: inline-flex;
    align-items: center;
    gap: 3px;
  }

  .obw-ts__check {
    position: absolute;
    top: 8px;
    right: 8px;
    color: var(--cnp-accent, #6366f1);
    background: var(--bg);
    border-radius: 50%;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 1px 3px rgba(0,0,0,0.2);
  }

  .obw-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: 16px;
    border-top: 1px solid var(--border);
    margin-top: auto;
  }

  .obw-nav__right { display: flex; gap: 12px; align-items: center; }

  .obw-btn-ghost {
    background: none;
    border: none;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: 13px;
    cursor: pointer;
    padding: 6px 8px;
    border-radius: 6px;
  }

  .obw-btn-ghost:hover { color: var(--fg); }
  .obw-btn-skip { font-size: 12px; }

  .obw-btn-primary {
    padding: 8px 20px;
    border-radius: 999px;
    border: none;
    background: var(--cnp-accent, #6366f1);
    color: #fff;
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }

  .obw-btn-primary:hover { opacity: 0.88; }
</style>
