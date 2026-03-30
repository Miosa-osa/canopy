<script lang="ts">
  import HealthBadge from './HealthBadge.svelte';
  interface Props {
    node: { id: string; name: string; type: string; health: string; owner: string; signalCount: number; };
    onclick?: () => void;
  }
  let { node, onclick }: Props = $props();
</script>
<button class="nc" onclick={onclick} type="button">
  <div class="nc-header">
    <span class="nc-id">{node.id.slice(0, 2)}</span>
    <span class="nc-name">{node.name}</span>
    <HealthBadge health={node.health} />
  </div>
  <div class="nc-meta">
    <span>{node.type}</span>
    <span>{node.owner}</span>
    <span>{node.signalCount} signals</span>
  </div>
</button>
<style>
  .nc { all: unset; display: block; width: 100%; padding: 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.08); cursor: pointer; transition: background 150ms; text-align: left; }
  .nc:hover { background: rgba(255,255,255,0.04); }
  .nc-header { display: flex; align-items: center; gap: 8px; }
  .nc-id { width: 24px; height: 24px; border-radius: 4px; background: rgba(255,255,255,0.08); display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 700; flex-shrink: 0; color: rgba(255,255,255,0.4); }
  .nc-name { flex: 1; font-weight: 500; font-size: 13px; color: var(--text-primary, #e2e8f0); }
  .nc-meta { display: flex; gap: 8px; margin-top: 6px; font-size: 11px; color: rgba(255,255,255,0.4); }
</style>
