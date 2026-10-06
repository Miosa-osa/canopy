<script lang="ts">
  interface Crumb { label: string; href?: string; }
  interface Props { crumbs: Crumb[]; }
  let { crumbs }: Props = $props();
</script>

<nav class="bc" aria-label="Breadcrumb">
  <ol class="bc-list">
    {#each crumbs as crumb, i}
      <li class="bc-item">
        {#if crumb.href && i < crumbs.length - 1}
          <a href={crumb.href} class="bc-link">{crumb.label}</a>
        {:else}
          <span class="bc-current" aria-current="page">{crumb.label}</span>
        {/if}
        {#if i < crumbs.length - 1}
          <span class="bc-sep" aria-hidden="true">/</span>
        {/if}
      </li>
    {/each}
  </ol>
</nav>

<style>
  .bc { padding: 8px 0; }
  .bc-list { display: flex; align-items: center; gap: 4px; list-style: none; margin: 0; padding: 0; }
  .bc-link { color: var(--dt3); text-decoration: none; font-size: 12px; }
  .bc-link:hover { color: var(--dt); }
  .bc-current { color: var(--dt2); font-size: 12px; }
  .bc-sep { color: var(--dt4); font-size: 11px; }
</style>
