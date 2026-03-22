<!-- src/routes/app/users/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { usersStore } from '$lib/stores/users.svelte';
  import type { UserRole } from '$api/types';

  onMount(() => {
    void usersStore.fetchUsers();
  });

  const ROLE_FILTERS: { value: UserRole | 'all'; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'admin', label: 'Admin' },
    { value: 'member', label: 'Member' },
    { value: 'viewer', label: 'Viewer' },
  ];

  function roleClass(role: UserRole): string {
    return { admin: 'usr-role--admin', member: 'usr-role--member', viewer: 'usr-role--viewer' }[role];
  }

  function initials(name: string): string {
    return name.split(' ').slice(0, 2).map((w) => w[0]).join('').toUpperCase();
  }
</script>

<PageShell
  title="Users"
  subtitle="{usersStore.adminCount} admin"
  badge={usersStore.totalCount > 0 ? usersStore.totalCount : undefined}
>
  {#snippet actions()}
    <div class="usr-filter-group" role="group" aria-label="Filter by role">
      {#each ROLE_FILTERS as opt (opt.value)}
        <button
          class="usr-filter-btn"
          class:usr-filter-btn--active={usersStore.filterRole === opt.value}
          onclick={() => usersStore.setRoleFilter(opt.value)}
          aria-pressed={usersStore.filterRole === opt.value}
        >
          {opt.label}
        </button>
      {/each}
    </div>
    <input
      class="usr-search"
      type="search"
      placeholder="Search by name or email…"
      value={usersStore.searchQuery}
      oninput={(e) => usersStore.setSearch((e.target as HTMLInputElement).value)}
      aria-label="Search users"
    />
  {/snippet}

  {#if usersStore.loading && usersStore.users.length === 0}
    <div class="usr-loading" role="status" aria-live="polite">
      <div class="usr-spinner" aria-hidden="true"></div>
      <span>Loading users…</span>
    </div>
  {:else if usersStore.error && usersStore.users.length === 0}
    <div class="usr-empty" role="alert">
      <p>Failed to load users: {usersStore.error}</p>
      <button class="usr-retry-btn" onclick={() => void usersStore.fetchUsers()}>Retry</button>
    </div>
  {:else if usersStore.filteredUsers.length === 0}
    <div class="usr-empty" role="status">
      <p>{usersStore.searchQuery || usersStore.filterRole !== 'all'
        ? 'No users match the current filter.'
        : 'No users yet.'}</p>
    </div>
  {:else}
    <div class="usr-list" role="list" aria-label="Users">
      {#each usersStore.filteredUsers as user (user.id)}
        {@const joinDate = user.created_at || user.inserted_at || ''}
        <div
          class="usr-row"
          role="listitem"
          class:usr-row--selected={usersStore.selected?.id === user.id}
        >
          <button
            class="usr-avatar"
            onclick={() => usersStore.selectUser(usersStore.selected?.id === user.id ? null : user)}
            aria-label="View user {user.name}"
          >
            {#if user.avatar_url}
              <img src={user.avatar_url} alt={user.name} class="usr-avatar-img" />
            {:else}
              <span class="usr-avatar-initials">{initials(user.name)}</span>
            {/if}
          </button>
          <div class="usr-info">
            <div class="usr-name">{user.name}</div>
            <div class="usr-email">{user.email}</div>
          </div>
          <span class="usr-role {roleClass(user.role)}">{user.role}</span>
          <time class="usr-joined" datetime={joinDate}>
            Joined {joinDate ? new Date(joinDate).toLocaleDateString() : '—'}
          </time>
        </div>
      {/each}
    </div>
  {/if}
</PageShell>

<style>
  .usr-filter-group {
    display: flex; align-items: center; gap: 2px;
    background: var(--dbg2); border: 1px solid var(--dbd); border-radius: 8px; padding: 2px;
  }
  .usr-filter-btn {
    background: none; border: none; border-radius: 6px; color: var(--dt3);
    font-size: 12px; font-weight: 500; padding: 3px 10px; cursor: pointer;
    transition: background 120ms ease, color 120ms ease;
  }
  .usr-filter-btn:hover { color: var(--dt2); background: rgba(255,255,255,0.05); }
  .usr-filter-btn--active { background: var(--dbg3); color: var(--dt); border: 1px solid var(--dbd); }
  .usr-search {
    height: 28px; padding: 0 10px; border-radius: 6px; font-size: 12px;
    background: var(--dbg2); border: 1px solid var(--dbd); color: var(--dt); min-width: 220px;
  }
  .usr-search:focus { outline: none; border-color: #6366f1; }

  .usr-loading, .usr-empty {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 240px;
    color: var(--dt3); font-size: 13px;
  }
  .usr-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: usr-spin 0.8s linear infinite;
  }
  @keyframes usr-spin { to { transform: rotate(360deg); } }
  .usr-retry-btn {
    padding: 6px 14px; border-radius: 6px; font-size: 12px; cursor: pointer;
    border: 1px solid var(--dbd); background: var(--dbg2); color: var(--dt2);
  }

  .usr-list { display: flex; flex-direction: column; gap: 4px; }
  .usr-row {
    display: flex; align-items: center; gap: 14px;
    padding: 12px 16px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd);
    transition: background 120ms ease, border-color 120ms ease;
  }
  .usr-row:hover { background: var(--dbg3); }
  .usr-row--selected { border-color: #6366f1; background: color-mix(in srgb, #6366f1 6%, var(--dbg2)); }

  .usr-avatar {
    width: 36px; height: 36px; border-radius: 50%; flex-shrink: 0;
    background: var(--dbg3); border: 1px solid var(--dbd); cursor: pointer;
    overflow: hidden; display: flex; align-items: center; justify-content: center;
  }
  .usr-avatar-img { width: 100%; height: 100%; object-fit: cover; }
  .usr-avatar-initials { font-size: 12px; font-weight: 600; color: var(--dt2); }

  .usr-info { flex: 1; min-width: 0; }
  .usr-name { font-size: 14px; font-weight: 500; color: var(--dt); }
  .usr-email { font-size: 12px; color: var(--dt3); }

  .usr-role {
    font-size: 11px; font-weight: 500; padding: 2px 8px; border-radius: 4px; flex-shrink: 0;
    text-transform: capitalize;
  }
  .usr-role--admin { background: color-mix(in srgb, #ef4444 15%, transparent); color: #fca5a5; }
  .usr-role--member { background: color-mix(in srgb, #6366f1 15%, transparent); color: #a5b4fc; }
  .usr-role--viewer { background: var(--dbg3); color: var(--dt3); }

  .usr-joined { font-size: 11px; color: var(--dt4); flex-shrink: 0; }
</style>
