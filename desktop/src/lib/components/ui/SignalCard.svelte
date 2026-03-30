<script lang="ts">
  import GenreBadge from './GenreBadge.svelte';
  interface Props {
    signal: { id: string; title: string; nodeId: string; genre: string; date: string; };
    onclick?: () => void;
  }
  let { signal, onclick }: Props = $props();
</script>
<button class="sc" onclick={onclick} type="button">
  <div class="sc-header">
    <span class="sc-title">{signal.title}</span>
    <GenreBadge genre={signal.genre} />
  </div>
  <div class="sc-meta">
    <span class="sc-node">{signal.nodeId}</span>
    <span class="sc-date">{signal.date}</span>
  </div>
</button>
<style>
  .sc { all: unset; display: block; width: 100%; padding: 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.08); cursor: pointer; transition: background 150ms; text-align: left; }
  .sc:hover { background: rgba(255,255,255,0.04); }
  .sc-header { display: flex; align-items: center; gap: 8px; }
  .sc-title { flex: 1; font-weight: 500; font-size: 13px; color: var(--text-primary, #e2e8f0); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sc-meta { display: flex; gap: 8px; margin-top: 6px; font-size: 11px; color: rgba(255,255,255,0.4); }
</style>
