<script lang="ts">
  /**
   * BuildSideRail — left rail inside the /build route.
   * CSS prefix: brl- (build-rail).
   *
   * Layout:
   *   ┌─┬───────────────────┐
   *   │ │                   │
   *   │ │  active section   │  40px icon column + 280px panel (when expanded)
   *   │ │                   │
   *   └─┴───────────────────┘
   *
   * Active section + expanded state are persisted by buildRail (svelte 5 runes
   * store). The 5 sections are individual components; this shell just switches.
   *
   * Keyboard:
   *   Esc                      collapse
   *   ⌘1   open Conversations  (primary — agent_conversation transcripts)
   *   ⌘2   open Tabs
   *   ⌘3   open Project Explorer
   *   ⌘4   open Search
   *   ⌘5   open Drive
   *
   * LOC target: ≤ 220.
   */
  import {
    Bot,
    Database,
    FolderTree,
    LayoutPanelLeft,
    Search,
  } from "lucide-svelte";
  import {
    buildRail,
    RAIL_SECTIONS,
    type RailSection,
  } from "$lib/stores/build-rail.svelte.js";
  import { Tooltip } from "$lib/design/foundation/index.js";
  import AgentConversationsSection from "./sections/AgentConversationsSection.svelte";
  import TabsSection from "./sections/TabsSection.svelte";
  import ProjectExplorerSection from "./sections/ProjectExplorerSection.svelte";
  import SearchSection from "./sections/SearchSection.svelte";
  import DriveSection from "./sections/DriveSection.svelte";

  interface Props {
    /** The active workspace slug — required to power Explorer + Search + Conversations. */
    workspaceSlug: string;
  }

  let { workspaceSlug }: Props = $props();

  const ICONS: Record<RailSection, typeof LayoutPanelLeft> = {
    conversations: Bot as unknown as typeof LayoutPanelLeft,
    tabs: LayoutPanelLeft,
    explorer: FolderTree as unknown as typeof LayoutPanelLeft,
    search: Search as unknown as typeof LayoutPanelLeft,
    drive: Database as unknown as typeof LayoutPanelLeft,
  };

  const LABELS: Record<RailSection, string> = {
    conversations: "Conversations",
    tabs: "Tabs",
    explorer: "Project Explorer",
    search: "Search",
    drive: "Drive",
  };

  // Cmd-1/2/3/4/5 → switch section, Esc → collapse.
  function handleKeyDown(ev: KeyboardEvent): void {
    if (ev.key === "Escape" && buildRail.isExpanded) {
      ev.preventDefault();
      buildRail.collapse();
      return;
    }
    if ((ev.metaKey || ev.ctrlKey) && !ev.altKey && !ev.shiftKey) {
      const map: Record<string, RailSection> = {
        "1": "conversations",
        "2": "tabs",
        "3": "explorer",
        "4": "search",
        "5": "drive",
      };
      const target = map[ev.key];
      if (target) {
        ev.preventDefault();
        buildRail.open(target);
      }
    }
  }
</script>

<svelte:window onkeydown={handleKeyDown} />

<div
  class="brl"
  class:brl--expanded={buildRail.isExpanded}
  data-section={buildRail.activeSection ?? "none"}
>
  <!-- Icon column -->
  <nav class="brl__column" aria-label="Build rail sections">
    {#each RAIL_SECTIONS as section (section)}
      {@const Icon = ICONS[section]}
      {@const isActive = buildRail.activeSection === section}
      <Tooltip content={LABELS[section]} side="right">
        <button
          type="button"
          class="brl__icon-btn"
          class:brl__icon-btn--active={isActive}
          aria-label={LABELS[section]}
          aria-pressed={isActive}
          onclick={() => buildRail.toggle(section)}
        >
          <!-- svelte-ignore svelte_component_deprecated -->
          <svelte:component this={Icon} size={18} aria-hidden="true" />
        </button>
      </Tooltip>
    {/each}
  </nav>

  <!-- Expanded panel -->
  {#if buildRail.isExpanded}
    <section
      class="brl__panel"
      aria-label={buildRail.activeSection
        ? LABELS[buildRail.activeSection]
        : undefined}
    >
      {#if buildRail.activeSection === "conversations"}
        <AgentConversationsSection {workspaceSlug} />
      {:else if buildRail.activeSection === "tabs"}
        <TabsSection />
      {:else if buildRail.activeSection === "explorer"}
        <ProjectExplorerSection {workspaceSlug} />
      {:else if buildRail.activeSection === "search"}
        <SearchSection {workspaceSlug} />
      {:else if buildRail.activeSection === "drive"}
        <DriveSection />
      {/if}
    </section>
  {/if}
</div>

<style>
  .brl {
    display: flex;
    height: 100%;
    background: var(--bg, #ffffff);
    border-right: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    overflow: hidden;
  }

  .brl__column {
    flex-shrink: 0;
    width: 40px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-1, 4px);
    padding: var(--space-2) 0;
    border-right: 1px solid var(--border, rgba(0, 0, 0, 0.06));
    background: var(--bg-inset, rgba(0, 0, 0, 0.02));
  }

  .brl__icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    border: none;
    background: transparent;
    color: var(--fg-muted);
    border-radius: var(--radius-sm, 6px);
    cursor: pointer;
    transition: background 80ms ease-out, color 80ms ease-out;
  }

  .brl__icon-btn:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl__icon-btn--active {
    background: color-mix(in oklch, var(--cnp-accent, #1e96eb) 14%, transparent 86%);
    color: var(--fg);
    box-shadow: inset 2px 0 0 var(--cnp-accent, #1e96eb);
  }

  .brl__icon-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, #1e96eb);
    outline-offset: 1px;
  }

  .brl__panel {
    flex-shrink: 0;
    width: 280px;
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--bg, #ffffff);
    overflow: hidden;
  }

  :global(.dark) .brl {
    background: #1e1e1e;
    border-color: rgba(255, 255, 255, 0.08);
  }

  :global(.dark) .brl__column {
    background: #181818;
    border-color: rgba(255, 255, 255, 0.06);
  }

  :global(.dark) .brl__panel {
    background: #1e1e1e;
  }
</style>
