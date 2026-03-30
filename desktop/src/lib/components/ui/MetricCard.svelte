<script lang="ts">
  interface Props { label: string; value: string | number; delta?: string; trend?: 'up' | 'down' | 'flat'; }
  let { label, value, delta, trend }: Props = $props();
  let trendColor = $derived(trend === 'up' ? '#22c55e' : trend === 'down' ? '#ef4444' : '#6b7280');
</script>
<div class="mc">
  <span class="mc-label">{label}</span>
  <span class="mc-value">{value}</span>
  {#if delta}
    <span class="mc-delta" style="color: {trendColor}">{delta}</span>
  {/if}
</div>
<style>
  .mc { padding: 16px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.08); }
  .mc-label { display: block; font-size: 11px; color: rgba(255,255,255,0.4); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px; }
  .mc-value { display: block; font-size: 24px; font-weight: 600; color: var(--text-primary, #e2e8f0); }
  .mc-delta { display: block; font-size: 12px; font-weight: 500; margin-top: 4px; }
</style>
