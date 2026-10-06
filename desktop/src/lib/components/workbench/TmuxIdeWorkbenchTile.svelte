<script lang="ts">
  import { Braces, CheckCircle2, PanelsTopLeft, Send, TerminalSquare } from "lucide-svelte";

  const panes = [
    { title: "Lead", role: "lead", command: "claude", status: "focused" },
    { title: "Frontend", role: "teammate", command: "claude", status: "ready" },
    { title: "Backend", role: "teammate", command: "claude", status: "ready" },
    { title: "Dev Server", role: "process", command: "npm run dev", status: "watching" },
    { title: "Tests", role: "process", command: "npm test", status: "idle" },
  ];
</script>

<div class="tmux-tile">
  <div class="tmux-summary">
    <div>
      <span class="tmux-kicker">tmux-ide layout</span>
      <h3>Agent terminal team</h3>
    </div>
    <span class="tmux-status">MIT clean-room port target</span>
  </div>

  <div class="tmux-grid" aria-label="Tmux pane plan">
    {#each panes as pane (pane.title)}
      <section class="tmux-pane">
        <header>
          <span>{pane.title}</span>
          <small>{pane.status}</small>
        </header>
        <div class="tmux-pane-body">
          <span class="tmux-role">{pane.role}</span>
          <code>{pane.command}</code>
        </div>
      </section>
    {/each}
  </div>

  <div class="tmux-flow">
    <span><Braces size={13} aria-hidden="true" /> ide.yml</span>
    <span><PanelsTopLeft size={13} aria-hidden="true" /> rows/panes</span>
    <span><TerminalSquare size={13} aria-hidden="true" /> tmux session</span>
    <span><Send size={13} aria-hidden="true" /> send task</span>
    <span><CheckCircle2 size={13} aria-hidden="true" /> inspect status</span>
  </div>
</div>

<style>
  .tmux-tile {
    display: flex;
    height: 100%;
    min-height: 0;
    flex-direction: column;
    background: #08090b;
  }

  .tmux-summary {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 12px;
    padding: 14px;
    border-bottom: 1px solid var(--border-default);
  }

  .tmux-kicker {
    color: var(--text-tertiary);
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  h3 {
    margin: 5px 0 0;
    color: var(--text-primary);
    font-size: 14px;
    font-weight: 650;
  }

  .tmux-status {
    flex-shrink: 0;
    padding: 3px 7px;
    border: 1px solid rgba(34, 197, 94, 0.26);
    border-radius: 999px;
    color: #86efac;
    background: rgba(34, 197, 94, 0.08);
    font-size: 10px;
    font-weight: 700;
  }

  .tmux-grid {
    display: grid;
    flex: 1;
    min-height: 0;
    grid-template-columns: 1.2fr 1fr 1fr;
    grid-auto-rows: minmax(96px, 1fr);
    gap: 8px;
    padding: 12px;
  }

  .tmux-pane {
    display: flex;
    min-width: 0;
    min-height: 0;
    flex-direction: column;
    overflow: hidden;
    border: 1px solid rgba(148, 163, 184, 0.18);
    border-radius: 7px;
    background: rgba(15, 23, 42, 0.72);
  }

  .tmux-pane:first-child {
    grid-row: span 2;
  }

  .tmux-pane header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    padding: 8px 9px;
    border-bottom: 1px solid rgba(148, 163, 184, 0.14);
    color: var(--text-primary);
    font-size: 12px;
    font-weight: 650;
  }

  .tmux-pane small {
    color: var(--text-tertiary);
    font-size: 10px;
    font-weight: 600;
  }

  .tmux-pane-body {
    display: flex;
    min-height: 0;
    flex: 1;
    flex-direction: column;
    justify-content: flex-end;
    gap: 8px;
    padding: 9px;
  }

  .tmux-role {
    width: fit-content;
    padding: 2px 6px;
    border-radius: 5px;
    background: rgba(59, 130, 246, 0.12);
    color: #93c5fd;
    font-size: 10px;
    font-weight: 700;
  }

  code {
    overflow: hidden;
    color: #e5e7eb;
    font-family: var(--font-mono);
    font-size: 11px;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .tmux-flow {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    padding: 9px 10px;
    border-top: 1px solid var(--border-default);
    color: var(--text-tertiary);
    font-size: 11px;
  }

  .tmux-flow span {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
</style>
