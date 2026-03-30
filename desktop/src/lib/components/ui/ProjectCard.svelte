<script lang="ts">
  interface Props {
    project: { id: string; name: string; status: string; progress: number; owner: string; description?: string; };
    onclick?: () => void;
  }
  let { project, onclick }: Props = $props();
  let statusColor = $derived(project.status === 'active' ? '#22c55e' : project.status === 'blocked' ? '#ef4444' : '#6b7280');
</script>
<button class="proj" onclick={onclick} type="button">
  <div class="proj-header">
    <span class="proj-name">{project.name}</span>
    <span class="proj-status" style="color: {statusColor}">{project.status}</span>
  </div>
  <div class="proj-bar">
    <div class="proj-fill" style="width: {project.progress}%"></div>
  </div>
  <div class="proj-meta">
    <span>{project.owner}</span>
    <span>{project.progress}%</span>
  </div>
</button>
<style>
  .proj { all: unset; display: block; width: 100%; padding: 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.08); cursor: pointer; transition: background 150ms; text-align: left; }
  .proj:hover { background: rgba(255,255,255,0.04); }
  .proj-header { display: flex; align-items: center; justify-content: space-between; }
  .proj-name { font-weight: 500; font-size: 13px; color: var(--text-primary, #e2e8f0); }
  .proj-status { font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
  .proj-bar { height: 4px; background: rgba(255,255,255,0.08); border-radius: 2px; margin-top: 8px; overflow: hidden; }
  .proj-fill { height: 100%; background: var(--accent-primary, #3b82f6); border-radius: 2px; transition: width 300ms; }
  .proj-meta { display: flex; justify-content: space-between; margin-top: 6px; font-size: 11px; color: rgba(255,255,255,0.4); }
</style>
