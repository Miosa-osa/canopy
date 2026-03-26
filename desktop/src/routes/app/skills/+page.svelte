<!-- src/routes/app/skills/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { skillsStore } from '$lib/stores/skills.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId;
    void skillsStore.fetchSkills(wsId ?? undefined);
  });
</script>

<PageShell
  title="Skills"
  subtitle="{skillsStore.enabledCount} of {skillsStore.totalCount} enabled"
>
  {#snippet actions()}
    <input
      class="sk-search"
      type="text"
      placeholder="Search skills…"
      bind:value={skillsStore.searchQuery}
      aria-label="Search skills by name"
    />
  {/snippet}

  {#if skillsStore.loading && skillsStore.skills.length === 0}
    <div class="sk-loading" role="status" aria-live="polite">
      <div class="sk-spinner" aria-hidden="true"></div>
      <span>Loading skills…</span>
    </div>
  {:else if skillsStore.error && skillsStore.skills.length === 0}
    <div class="sk-error" role="alert">
      <p>Failed to load skills: {skillsStore.error}</p>
      <button onclick={() => void skillsStore.fetchSkills()}>Retry</button>
    </div>
  {:else if skillsStore.filteredSkills.length === 0}
    <div class="sk-empty" role="status">
      <p>{skillsStore.searchQuery ? 'No skills match your search.' : 'No skills configured.'}</p>
    </div>
  {:else}
    <div class="sk-list" role="list" aria-label="Skills">
      {#each skillsStore.filteredSkills as skill (skill.id)}
        <div class="sk-item" role="listitem">
          <div class="sk-info">
            <div class="sk-name">{skill.name}</div>
            <div class="sk-desc">{skill.description}</div>
            <div class="sk-meta">
              <span class="sk-badge sk-badge--{skill.category}">{skill.category}</span>
              <span class="sk-version">v{skill.version ?? '1.0'}</span>
            </div>
          </div>
          <button
            class="sk-toggle"
            class:sk-toggle--on={skill.enabled}
            onclick={() => void skillsStore.toggleSkill(skill.id)}
            aria-pressed={skill.enabled}
            aria-label="{skill.enabled ? 'Disable' : 'Enable'} {skill.name}"
            type="button"
          >
            {skill.enabled ? 'Enabled' : 'Disabled'}
          </button>
        </div>
      {/each}
    </div>
  {/if}
</PageShell>

<style>
  .sk-loading, .sk-empty, .sk-error {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 200px;
    color: var(--dt3); font-size: 13px;
  }
  .sk-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .sk-list { display: flex; flex-direction: column; gap: 8px; padding: 24px; }
  .sk-item {
    display: flex; align-items: center; gap: 16px;
    padding: 14px 16px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd);
  }
  .sk-info { flex: 1; }
  .sk-name { font-size: 14px; font-weight: 500; color: var(--dt); margin-bottom: 2px; }
  .sk-desc { font-size: 12px; color: var(--dt3); margin-bottom: 8px; }
  .sk-meta { display: flex; align-items: center; gap: 8px; }
  .sk-badge {
    font-size: 10px; font-weight: 500; padding: 2px 6px;
    border-radius: 4px; text-transform: uppercase; letter-spacing: 0.04em;
    background: var(--dbg3); color: var(--dt3);
  }
  .sk-version { font-size: 11px; color: var(--dt4); }
  .sk-toggle {
    padding: 6px 14px; border-radius: 6px; font-size: 12px; font-weight: 500;
    cursor: pointer; transition: all 120ms ease; border: 1px solid var(--dbd);
    background: transparent; color: var(--dt3);
  }
  .sk-toggle--on { background: color-mix(in srgb, #6366f1 15%, transparent); border-color: color-mix(in srgb, #6366f1 40%, transparent); color: #a5b4fc; }
  .sk-toggle:focus-visible { outline: 2px solid #6366f1; outline-offset: 2px; }
  .sk-search {
    height: 28px; padding: 0 10px; border-radius: 6px; font-size: 12px;
    background: var(--dbg3); border: 1px solid var(--dbd); color: var(--dt);
    width: 180px; box-sizing: border-box;
  }
  .sk-search:focus { outline: none; border-color: #6366f1; }
  .sk-search::placeholder { color: var(--dt4); }
</style>
