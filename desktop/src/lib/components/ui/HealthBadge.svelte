<script lang="ts">
  interface Props { health: string; }
  let { health }: Props = $props();
  const colorMap: Record<string, string> = { green: '#22c55e', yellow: '#eab308', red: '#ef4444' };
  let color = $derived(colorMap[health] ?? '#6b7280');
</script>
<span class="hb" style="--c: {color}">{health}</span>
<style>
  .hb { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 99px; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; background: color-mix(in srgb, var(--c) 15%, transparent); color: var(--c); border: 1px solid color-mix(in srgb, var(--c) 30%, transparent); }
</style>
