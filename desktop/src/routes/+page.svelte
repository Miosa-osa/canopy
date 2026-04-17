<script lang="ts">
// Home placeholder — Week 5 wires the Composer + recent sessions.
// For now: runtime scaffolding confirmation screen.
</script>

<div class="home">
  <h1 class="greeting">Canopy is ready.</h1>
  <p class="caption">Runtime scaffolding complete. Week 1 begins.</p>
</div>

<style>
  .home {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-8);
  }

  .greeting {
    font-family: var(--font-serif);
    font-size: var(--text-3xl);
    line-height: var(--lh-3xl);
    letter-spacing: var(--tracking-3xl);
    font-weight: 400;
    color: var(--fg);
    margin: 0;
    text-align: center;
  }

  .caption {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    line-height: var(--lh-sm);
    letter-spacing: var(--tracking-sm);
    color: var(--fg-subtle);
    margin: 0;
    text-align: center;
  }
</style>
