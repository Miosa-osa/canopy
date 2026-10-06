<script lang="ts">
  import { FileText, Folder, GitBranch } from "lucide-svelte";
  import { workspaceStore } from "$lib/stores/workspace.svelte";

  const workspacePath = $derived(workspaceStore.activeWorkspace?.path ?? "No workspace selected");
  const protocolItems = [
    { icon: Folder, label: "agents", detail: "Agent definitions" },
    { icon: Folder, label: "projects", detail: "Project folders" },
    { icon: Folder, label: "skills", detail: "Runtime skills" },
    { icon: FileText, label: "SYSTEM.md", detail: "Workspace brain" },
    { icon: GitBranch, label: "git status", detail: "Diff tile wiring next" },
  ];
</script>

<div class="files-tile">
  <div class="files-root" title={workspacePath}>
    <Folder size={14} aria-hidden="true" />
    <span>{workspacePath}</span>
  </div>

  <div class="files-list" role="list" aria-label="Workbench file modules">
    {#each protocolItems as item (item.label)}
      {@const Icon = item.icon}
      <button class="files-item" type="button">
        <Icon size={15} aria-hidden="true" />
        <span>
          <strong>{item.label}</strong>
          <small>{item.detail}</small>
        </span>
      </button>
    {/each}
  </div>
</div>

<style>
  .files-tile {
    display: flex;
    height: 100%;
    min-height: 0;
    flex-direction: column;
    background: var(--bg-primary);
  }

  .files-root {
    display: flex;
    align-items: center;
    gap: 8px;
    min-height: 36px;
    padding: 0 12px;
    border-bottom: 1px solid var(--border-default);
    color: var(--text-secondary);
    font-size: 11px;
  }

  .files-root span {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .files-list {
    display: flex;
    flex: 1;
    min-height: 0;
    flex-direction: column;
    gap: 4px;
    overflow-y: auto;
    padding: 8px;
  }

  .files-item {
    display: flex;
    width: 100%;
    align-items: center;
    gap: 9px;
    padding: 8px;
    border: 1px solid transparent;
    border-radius: 6px;
    background: transparent;
    color: var(--text-secondary);
    cursor: pointer;
    text-align: left;
  }

  .files-item:hover {
    border-color: var(--border-default);
    background: var(--bg-surface);
    color: var(--text-primary);
  }

  .files-item span {
    display: flex;
    min-width: 0;
    flex-direction: column;
    gap: 2px;
  }

  .files-item strong {
    color: var(--text-primary);
    font-size: 12px;
    font-weight: 500;
  }

  .files-item small {
    color: var(--text-tertiary);
    font-size: 11px;
  }
</style>
