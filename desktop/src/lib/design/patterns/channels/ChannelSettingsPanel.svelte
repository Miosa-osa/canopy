<script lang="ts">
  /**
   * ChannelSettingsPanel — right slide-out panel for channel config.
   * CSS prefix: csp- (ChannelSettingsPanel)
   * LOC target: ≤280
   */
  import { X, Trash2, UserMinus, UserPlus, Lock, Hash } from 'lucide-svelte';
  import {
    updateChannel,
    deleteChannel,
    listMembers,
    addMember,
    removeMember,
  } from '$lib/api/queries/channels.js';
  import type { Channel, ChannelMember, ActorType } from '$lib/domain/channels/types.js';

  interface Props {
    channel: Channel;
    open: boolean;
    onClose: () => void;
    onUpdated: () => void;
    onDeleted: () => void;
  }

  let { channel, open, onClose, onUpdated, onDeleted }: Props = $props();

  // ── Details form state ────────────────────────────────────────────────────
  // Initialized empty; $effect below populates and re-syncs when channel changes.
  let editName = $state('');
  let editDesc = $state('');
  let editVisibility = $state<'public' | 'private'>('public');
  let saving = $state(false);
  let saveError = $state<string | null>(null);

  // Sync form values when channel prop changes (e.g. after invalidation)
  $effect(() => {
    editName = channel.name;
    editDesc = channel.description ?? '';
    editVisibility = channel.visibility;
  });

  async function handleSave(): Promise<void> {
    if (!editName.trim()) return;
    saving = true;
    saveError = null;
    try {
      await updateChannel(channel.id, {
        name: editName.trim(),
        description: editDesc.trim() || null,
        visibility: editVisibility,
      });
      onUpdated();
    } catch (e) {
      saveError = e instanceof Error ? e.message : 'Save failed';
    } finally {
      saving = false;
    }
  }

  // ── Members ───────────────────────────────────────────────────────────────
  let members = $state<ChannelMember[]>([]);
  let membersLoading = $state(false);
  let membersError = $state<string | null>(null);
  let addSlug = $state('');
  let addActorType = $state<ActorType>('agent');
  let adding = $state(false);
  let addError = $state<string | null>(null);

  async function loadMembers(): Promise<void> {
    membersLoading = true;
    membersError = null;
    try {
      members = await listMembers(channel.id);
    } catch (e) {
      membersError = e instanceof Error ? e.message : 'Failed to load members';
    } finally {
      membersLoading = false;
    }
  }

  $effect(() => {
    if (open) void loadMembers();
  });

  async function handleAddMember(): Promise<void> {
    const slug = addSlug.trim();
    if (!slug) return;
    adding = true;
    addError = null;
    try {
      await addMember(channel.id, { actorType: addActorType, actorId: slug });
      addSlug = '';
      await loadMembers();
    } catch (e) {
      addError = e instanceof Error ? e.message : 'Failed to add member';
    } finally {
      adding = false;
    }
  }

  async function handleRemoveMember(m: ChannelMember): Promise<void> {
    try {
      await removeMember(channel.id, m.actorType, m.actorId);
      await loadMembers();
    } catch {
      // silently fail — member list refresh will show truth
    }
  }

  // ── Danger zone ───────────────────────────────────────────────────────────
  let confirmDelete = $state(false);
  let deleting = $state(false);

  async function handleDelete(): Promise<void> {
    deleting = true;
    try {
      await deleteChannel(channel.id);
      onDeleted();
    } catch {
      deleting = false;
      confirmDelete = false;
    }
  }

  function handleOverlayClick(e: MouseEvent): void {
    if (e.target === e.currentTarget) onClose();
  }
</script>

{#if open}
  <!-- Overlay -->
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="csp-overlay" onclick={handleOverlayClick} aria-hidden="true"></div>

  <!-- Panel -->
  <aside class="csp-panel" aria-label="Channel settings">
    <!-- Header -->
    <div class="csp-header">
      <div class="csp-header-title">
        {#if channel.visibility === 'private'}
          <Lock size={13} aria-hidden="true" class="csp-header-icon" />
        {:else}
          <Hash size={13} aria-hidden="true" class="csp-header-icon" />
        {/if}
        <span class="csp-title-text">{channel.name}</span>
      </div>
      <button class="csp-close" onclick={onClose} aria-label="Close settings">
        <X size={14} />
      </button>
    </div>

    <div class="csp-body">
      <!-- ── Details section ─────────────────────────────────────── -->
      <section class="csp-section">
        <h2 class="csp-section-heading">Details</h2>

        <label class="csp-label" for="csp-name">Name</label>
        <input
          id="csp-name"
          class="csp-input"
          type="text"
          bind:value={editName}
          maxlength={80}
          autocomplete="off"
          spellcheck={false}
          aria-label="Channel name"
        />

        <label class="csp-label" for="csp-desc">Description</label>
        <textarea
          id="csp-desc"
          class="csp-textarea"
          bind:value={editDesc}
          rows={3}
          maxlength={500}
          aria-label="Channel description"
          placeholder="What's this channel for?"
        ></textarea>

        <div class="csp-visibility-row">
          <span class="csp-label csp-label--inline">Visibility</span>
          <button
            class="csp-vis-toggle"
            class:csp-vis-toggle--private={editVisibility === 'private'}
            onclick={() => (editVisibility = editVisibility === 'public' ? 'private' : 'public')}
            aria-pressed={editVisibility === 'private'}
            title="Toggle public/private"
          >
            {#if editVisibility === 'private'}
              <Lock size={11} aria-hidden="true" /> Private
            {:else}
              <Hash size={11} aria-hidden="true" /> Public
            {/if}
          </button>
        </div>

        {#if saveError}
          <p class="csp-error" role="alert">{saveError}</p>
        {/if}

        <button
          class="csp-btn csp-btn--primary"
          onclick={handleSave}
          disabled={saving || !editName.trim()}
          aria-busy={saving}
        >
          {saving ? 'Saving…' : 'Save changes'}
        </button>
      </section>

      <div class="csp-divider" role="separator"></div>

      <!-- ── Members section ────────────────────────────────────── -->
      <section class="csp-section">
        <h2 class="csp-section-heading">Members</h2>

        {#if membersLoading}
          <div class="csp-members-loading" aria-label="Loading members">
            {#each { length: 3 } as _, i (i)}
              <div class="csp-member-skeleton"></div>
            {/each}
          </div>
        {:else if membersError}
          <p class="csp-error" role="alert">{membersError}</p>
        {:else if members.length === 0}
          <p class="csp-empty">No members yet.</p>
        {:else}
          <ul class="csp-member-list" aria-label="Channel members">
            {#each members as m (m.id)}
              <li class="csp-member-row">
                <div class="csp-member-info">
                  <span class="csp-member-id">{m.actorId}</span>
                  <span class="csp-role-badge csp-role-badge--{m.role}">{m.role}</span>
                  <span class="csp-actor-badge">{m.actorType}</span>
                </div>
                <button
                  class="csp-icon-btn"
                  onclick={() => handleRemoveMember(m)}
                  aria-label="Remove {m.actorId}"
                  title="Remove member"
                >
                  <UserMinus size={12} />
                </button>
              </li>
            {/each}
          </ul>
        {/if}

        <!-- Add member -->
        <div class="csp-add-row">
          <select
            class="csp-select"
            bind:value={addActorType}
            aria-label="Member type"
          >
            <option value="agent">Agent</option>
            <option value="user">User</option>
          </select>
          <input
            class="csp-input csp-input--grow"
            type="text"
            bind:value={addSlug}
            placeholder="ID or slug"
            aria-label="Member ID or slug"
            spellcheck={false}
            autocomplete="off"
            onkeydown={(e) => { if (e.key === 'Enter') void handleAddMember(); }}
          />
          <button
            class="csp-icon-btn csp-icon-btn--add"
            onclick={handleAddMember}
            disabled={adding || !addSlug.trim()}
            aria-label="Add member"
            title="Add member"
          >
            <UserPlus size={12} />
          </button>
        </div>
        {#if addError}
          <p class="csp-error" role="alert">{addError}</p>
        {/if}
      </section>

      <div class="csp-divider" role="separator"></div>

      <!-- ── Danger zone ────────────────────────────────────────── -->
      <section class="csp-section csp-section--danger">
        <h2 class="csp-section-heading csp-section-heading--danger">Danger zone</h2>

        {#if !confirmDelete}
          <button
            class="csp-btn csp-btn--danger"
            onclick={() => (confirmDelete = true)}
          >
            <Trash2 size={12} aria-hidden="true" />
            Delete channel
          </button>
        {:else}
          <p class="csp-confirm-text">
            Delete <strong>#{channel.name}</strong>? This cannot be undone.
          </p>
          <div class="csp-confirm-row">
            <button
              class="csp-btn csp-btn--danger"
              onclick={handleDelete}
              disabled={deleting}
              aria-busy={deleting}
            >
              {deleting ? 'Deleting…' : 'Yes, delete'}
            </button>
            <button
              class="csp-btn csp-btn--ghost"
              onclick={() => (confirmDelete = false)}
              disabled={deleting}
            >
              Cancel
            </button>
          </div>
        {/if}
      </section>
    </div>
  </aside>
{/if}

<style>
  /* ── Overlay ────────────────────────────────────────────────── */
  .csp-overlay {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 20%, transparent);
    z-index: 49;
    animation: csp-fade-in 120ms var(--ease-out) both;
  }

  /* ── Panel ──────────────────────────────────────────────────── */
  .csp-panel {
    position: fixed;
    top: 0;
    right: 0;
    width: 340px;
    height: 100%;
    background: var(--bg-inset);
    border-left: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    z-index: 50;
    animation: csp-slide-in 160ms var(--ease-out) both;
  }

  @keyframes csp-slide-in {
    from { transform: translateX(100%); opacity: 0; }
    to   { transform: translateX(0);   opacity: 1; }
  }

  @keyframes csp-fade-in {
    from { opacity: 0; }
    to   { opacity: 1; }
  }

  /* ── Header ─────────────────────────────────────────────────── */
  .csp-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 var(--space-4);
    height: 44px;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    gap: var(--space-2);
  }

  .csp-header-title {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
  }

  :global(.csp-header-icon) {
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .csp-title-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .csp-close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    padding: 4px;
    cursor: pointer;
    color: var(--fg-muted);
    flex-shrink: 0;
    transition: color var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out);
  }

  .csp-close:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  /* ── Body ───────────────────────────────────────────────────── */
  .csp-body {
    flex: 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* ── Sections ───────────────────────────────────────────────── */
  .csp-section {
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .csp-section--danger {
    gap: var(--space-3);
  }

  .csp-divider {
    height: 1px;
    background: var(--border);
    flex-shrink: 0;
  }

  .csp-section-heading {
    margin: 0 0 var(--space-1);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
  }

  .csp-section-heading--danger {
    color: var(--color-danger, #e05252);
  }

  /* ── Form controls ──────────────────────────────────────────── */
  .csp-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    margin-top: var(--space-1);
  }

  .csp-label--inline {
    margin-top: 0;
  }

  .csp-input {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 5px var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
    width: 100%;
    box-sizing: border-box;
  }

  .csp-input--grow {
    flex: 1;
    width: auto;
  }

  .csp-input:focus {
    border-color: var(--color-accent, #4f8ef7);
  }

  .csp-textarea {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 5px var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    resize: vertical;
    transition: border-color var(--dur-instant) var(--ease-out);
    width: 100%;
    box-sizing: border-box;
    min-height: 64px;
  }

  .csp-textarea:focus {
    border-color: var(--color-accent, #4f8ef7);
  }

  .csp-select {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 5px var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    outline: none;
    cursor: pointer;
    flex-shrink: 0;
  }

  /* ── Visibility toggle ──────────────────────────────────────── */
  .csp-visibility-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
  }

  .csp-vis-toggle {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 4px var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    cursor: pointer;
    transition: color var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out);
  }

  .csp-vis-toggle--private {
    background: color-mix(in oklch, var(--color-accent, #4f8ef7) 12%, transparent);
    border-color: color-mix(in oklch, var(--color-accent, #4f8ef7) 40%, transparent);
    color: var(--color-accent, #4f8ef7);
  }

  /* ── Buttons ────────────────────────────────────────────────── */
  .csp-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-1);
    border: none;
    border-radius: var(--radius-sm);
    padding: 6px var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    cursor: pointer;
    transition: opacity var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out);
    width: 100%;
  }

  .csp-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .csp-btn--primary {
    background: var(--color-accent, #4f8ef7);
    color: #fff;
  }

  .csp-btn--primary:hover:not(:disabled) {
    opacity: 0.88;
  }

  .csp-btn--danger {
    background: color-mix(in oklch, var(--color-danger, #e05252) 14%, transparent);
    border: 1px solid color-mix(in oklch, var(--color-danger, #e05252) 35%, transparent);
    color: var(--color-danger, #e05252);
  }

  .csp-btn--danger:hover:not(:disabled) {
    background: color-mix(in oklch, var(--color-danger, #e05252) 22%, transparent);
  }

  .csp-btn--ghost {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    border: 1px solid var(--border);
    color: var(--fg-muted);
  }

  .csp-btn--ghost:hover:not(:disabled) {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
  }

  .csp-icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    padding: 4px;
    cursor: pointer;
    color: var(--fg-muted);
    flex-shrink: 0;
    transition: color var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out);
  }

  .csp-icon-btn:hover:not(:disabled) {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
  }

  .csp-icon-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .csp-icon-btn--add {
    color: var(--color-accent, #4f8ef7);
  }

  .csp-icon-btn--add:hover:not(:disabled) {
    color: var(--color-accent, #4f8ef7);
    background: color-mix(in oklch, var(--color-accent, #4f8ef7) 12%, transparent);
  }

  /* ── Members list ───────────────────────────────────────────── */
  .csp-member-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .csp-member-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 5px var(--space-2);
    border-radius: var(--radius-sm);
    gap: var(--space-2);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .csp-member-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .csp-member-info {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
    flex: 1;
  }

  .csp-member-id {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex: 1;
    min-width: 0;
  }

  .csp-role-badge {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 1px 5px;
    border-radius: 3px;
    flex-shrink: 0;
  }

  .csp-role-badge--admin {
    background: color-mix(in oklch, var(--color-accent, #4f8ef7) 14%, transparent);
    color: var(--color-accent, #4f8ef7);
  }

  .csp-role-badge--member {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg-muted);
  }

  .csp-actor-badge {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  /* ── Add member row ─────────────────────────────────────────── */
  .csp-add-row {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    margin-top: var(--space-1);
  }

  /* ── Loading / empty / error ────────────────────────────────── */
  .csp-members-loading {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .csp-member-skeleton {
    height: 28px;
    border-radius: var(--radius-sm);
    background: var(--border);
    animation: csp-pulse 1.5s ease-in-out infinite;
  }

  @keyframes csp-pulse {
    0%, 100% { opacity: 0.3; }
    50%       { opacity: 0.6; }
  }

  .csp-empty {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
    margin: 0;
  }

  .csp-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--color-danger, #e05252);
    margin: 0;
  }

  /* ── Danger confirm ─────────────────────────────────────────── */
  .csp-confirm-text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    margin: 0;
    line-height: 1.5;
  }

  .csp-confirm-row {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }
</style>
