<script lang="ts">
  import { Terminal, Search, History } from "lucide-svelte";
</script>

<div class="term-tile">
  <div class="term-screen" role="log" aria-label="Terminal preview">
    <div class="term-line">
      <span class="term-prompt">canopy</span>
      <span class="term-path"> ~/workspace</span>
      <span class="term-cmd">$ npm run dev</span>
    </div>
    <div class="term-output">Workbench terminal runtime is ready for Tauri PTY wiring.</div>
    <div class="term-line">
      <span class="term-prompt">canopy</span>
      <span class="term-path"> ~/workspace</span>
      <span class="term-cmd">$ </span>
      <span class="term-cursor" aria-hidden="true"></span>
    </div>
  </div>

  <div class="term-actions" aria-label="Terminal capabilities">
    <span><Terminal size={13} aria-hidden="true" /> PTY</span>
    <span><History size={13} aria-hidden="true" /> Blocks</span>
    <span><Search size={13} aria-hidden="true" /> Find</span>
  </div>
</div>

<style>
  .term-tile {
    display: flex;
    height: 100%;
    min-height: 0;
    flex-direction: column;
    background: #08090b;
  }

  .term-screen {
    flex: 1;
    min-height: 0;
    padding: 14px;
    overflow: auto;
    font-family: var(--font-mono);
    font-size: 12px;
    line-height: 1.6;
  }

  .term-line {
    display: flex;
    align-items: center;
    gap: 6px;
    color: var(--text-secondary);
    white-space: nowrap;
  }

  .term-prompt {
    color: #7dd3fc;
  }

  .term-path {
    color: #a7f3d0;
  }

  .term-cmd {
    color: var(--text-primary);
  }

  .term-output {
    margin: 8px 0 12px;
    color: var(--text-tertiary);
  }

  .term-cursor {
    width: 7px;
    height: 14px;
    background: var(--text-primary);
    animation: term-blink 1.1s step-end infinite;
  }

  .term-actions {
    display: flex;
    gap: 8px;
    padding: 8px 10px;
    border-top: 1px solid var(--border-default);
    background: var(--bg-primary);
    color: var(--text-tertiary);
    font-size: 11px;
  }

  .term-actions span {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }

  @keyframes term-blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0; }
  }
</style>

