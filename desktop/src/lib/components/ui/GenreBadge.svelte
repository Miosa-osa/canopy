<script lang="ts">
  interface Props { genre: string; }
  let { genre }: Props = $props();
  const colors: Record<string, string> = { spec: '#3b82f6', brief: '#8b5cf6', transcript: '#06b6d4', note: '#6b7280', plan: '#10b981', decision: '#f59e0b' };
  let color = $derived(colors[genre] ?? '#6b7280');
</script>
<span class="gb" style="--c: {color}">{genre}</span>
<style>
  .gb { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 4px; font-size: 11px; font-weight: 500; background: color-mix(in srgb, var(--c) 12%, transparent); color: var(--c); }
</style>
