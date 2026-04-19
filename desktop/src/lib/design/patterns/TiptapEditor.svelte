<script lang="ts">
  /**
   * TiptapEditor — rich-text editor for Docs.
   * CSS prefix: te- (TiptapEditor)
   *
   * Extensions: StarterKit (minus CodeBlock) + CodeBlockLowlight + Typography
   *   + Link + Image + Placeholder + Table/TableRow/TableCell/TableHeader
   *   + Mention (@ trigger for entities) + Mention (/ trigger for slash commands)
   *
   * Bubble menu: manual ProseMirror-selection-driven floating toolbar (no external dep).
   * Slash menu: suggestion plugin wired to "/" char, inlined.
   */

  import { onMount, onDestroy } from 'svelte';
  import { Editor } from '@tiptap/core';
  import StarterKit from '@tiptap/starter-kit';
  import Typography from '@tiptap/extension-typography';
  import Link from '@tiptap/extension-link';
  import Image from '@tiptap/extension-image';
  import Placeholder from '@tiptap/extension-placeholder';
  import { Table, TableRow, TableCell, TableHeader } from '@tiptap/extension-table';
  import { Mention } from '@tiptap/extension-mention';
  import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight';
  import { createLowlight, common } from 'lowlight';
  import { type CreateQueryOptions, createQuery } from '@tanstack/svelte-query';
  import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
  import { workspacesQuery } from '$lib/api/queries/workspaces.js';
  import { tasksQuery } from '$lib/api/queries/tasks.js';
  import { channelsQuery } from '$lib/api/queries/channels.js';
  import type { Agent } from '$lib/domain/agents/types.js';
  import type { Workspace } from '$lib/domain/workspaces/types.js';
  import type { Task } from '$lib/domain/tasks/types.js';
  import type { Channel } from '$lib/domain/channels/types.js';
  import type { ProseMirrorDoc } from '$lib/domain/docs/types.js';
  import { buildMentionResults, type MentionItem, type MentionCategory } from '$lib/utils/mention-suggestions.js';
  import StatusDot from './StatusDot.svelte';

  // ── Props ─────────────────────────────────────────────────────────────────────

  interface Props {
    initialJson?: ProseMirrorDoc | null;
    editable?: boolean;
    placeholder?: string;
    onChange?: (json: ProseMirrorDoc, text: string) => void;
    onSubmit?: () => void;
  }

  let {
    initialJson = null,
    editable = true,
    placeholder = 'Write your doc…',
    onChange,
    onSubmit,
  }: Props = $props();

  // ── Lowlight ──────────────────────────────────────────────────────────────────

  const lowlight = createLowlight(common);

  // ── Data queries ──────────────────────────────────────────────────────────────

  const agentsQ = createQuery<Agent[]>(hiredAgentsQuery() as CreateQueryOptions<Agent[]>);
  const workspacesQ = createQuery<Workspace[]>(workspacesQuery() as CreateQueryOptions<Workspace[]>);
  const openTasksQ = createQuery<Task[]>(tasksQuery({ status: 'todo' }) as CreateQueryOptions<Task[]>);
  const inProgressQ = createQuery<Task[]>(tasksQuery({ status: 'in_progress' }) as CreateQueryOptions<Task[]>);
  const channelsQ = createQuery<Channel[]>(channelsQuery() as CreateQueryOptions<Channel[]>);

  const allAgents = $derived(($agentsQ.data ?? []) as Agent[]);
  const allWorkspaces = $derived(($workspacesQ.data ?? []) as Workspace[]);
  const allTasks = $derived([...($openTasksQ.data ?? []), ...($inProgressQ.data ?? [])] as Task[]);
  const allChannels = $derived(($channelsQ.data ?? []) as Channel[]);

  // ── Slash command definitions ──────────────────────────────────────────────────

  interface SlashCommand {
    id: string;
    label: string;
    description: string;
    action: (ed: Editor) => void;
  }

  const SLASH_COMMANDS: SlashCommand[] = [
    {
      id: 'h1',
      label: 'Heading 1',
      description: 'Large section heading',
      action: (ed) => ed.chain().focus().toggleHeading({ level: 1 }).run(),
    },
    {
      id: 'h2',
      label: 'Heading 2',
      description: 'Medium section heading',
      action: (ed) => ed.chain().focus().toggleHeading({ level: 2 }).run(),
    },
    {
      id: 'h3',
      label: 'Heading 3',
      description: 'Small section heading',
      action: (ed) => ed.chain().focus().toggleHeading({ level: 3 }).run(),
    },
    {
      id: 'bullet',
      label: 'Bullet list',
      description: 'Unordered list',
      action: (ed) => ed.chain().focus().toggleBulletList().run(),
    },
    {
      id: 'numbered',
      label: 'Numbered list',
      description: 'Ordered list',
      action: (ed) => ed.chain().focus().toggleOrderedList().run(),
    },
    {
      id: 'code',
      label: 'Code block',
      description: 'Syntax-highlighted code',
      action: (ed) => ed.chain().focus().toggleCodeBlock().run(),
    },
    {
      id: 'quote',
      label: 'Blockquote',
      description: 'Indented quote block',
      action: (ed) => ed.chain().focus().toggleBlockquote().run(),
    },
    {
      id: 'table',
      label: 'Table',
      description: 'Insert 3×3 table',
      action: (ed) =>
        ed
          .chain()
          .focus()
          .insertTable({ rows: 3, cols: 3, withHeaderRow: true })
          .run(),
    },
    {
      id: 'divider',
      label: 'Divider',
      description: 'Horizontal rule',
      action: (ed) => ed.chain().focus().setHorizontalRule().run(),
    },
    {
      id: 'image',
      label: 'Image from URL',
      description: 'Embed an image by URL',
      action: (ed) => {
        const url = window.prompt('Image URL');
        if (url) ed.chain().focus().setImage({ src: url }).run();
      },
    },
    {
      id: 'link',
      label: 'Link',
      description: 'Add a hyperlink',
      action: (ed) => {
        const url = window.prompt('Link URL');
        if (url) ed.chain().focus().setLink({ href: url }).run();
      },
    },
  ];

  // ── Mention/slash dropdown state ──────────────────────────────────────────────

  // @mention state
  let mentionItems = $state<MentionItem[]>([]);
  let mentionActiveIdx = $state(0);
  let mentionProps = $state<{
    query: string;
    command: (props: { id: string; label: string }) => void;
  } | null>(null);
  let mentionX = $state(0);
  let mentionY = $state(0);
  let mentionOpen = $derived(mentionProps !== null && mentionItems.length > 0);

  // Slash command state
  let slashItems = $state<SlashCommand[]>([]);
  let slashActiveIdx = $state(0);
  let slashProps = $state<{
    query: string;
    command: (props: { id: string; label: string }) => void;
  } | null>(null);
  let slashX = $state(0);
  let slashY = $state(0);
  let slashOpen = $derived(slashProps !== null && slashItems.length > 0);

  // ── Bubble menu state ─────────────────────────────────────────────────────────

  let bubbleVisible = $state(false);
  let bubbleX = $state(0);
  let bubbleY = $state(0);
  let bubbleFormats = $state({
    bold: false,
    italic: false,
    strike: false,
    code: false,
    link: false,
  });

  // ── DOM refs ──────────────────────────────────────────────────────────────────

  let editorEl = $state<HTMLDivElement | null>(null);
  let editor = $state<Editor | null>(null);

  // ── Suggestion renderer factory ───────────────────────────────────────────────

  function positionFromClientRect(rect: DOMRect): { x: number; y: number } {
    return { x: rect.left, y: rect.bottom + 6 };
  }

  function makeMentionRenderer() {
    return () => ({
      onStart(props: {
        query: string;
        command: (p: { id: string; label: string }) => void;
        clientRect?: (() => DOMRect | null) | null;
      }) {
        const q = props.query ?? '';
        mentionItems = buildMentionResults(
          q,
          allAgents,
          allWorkspaces,
          allTasks,
          allChannels,
        );
        mentionActiveIdx = 0;
        mentionProps = { query: q, command: props.command };
        const rect = props.clientRect?.();
        if (rect) ({ x: mentionX, y: mentionY } = positionFromClientRect(rect));
      },
      onUpdate(props: {
        query: string;
        command: (p: { id: string; label: string }) => void;
        clientRect?: (() => DOMRect | null) | null;
      }) {
        const q = props.query ?? '';
        mentionItems = buildMentionResults(
          q,
          allAgents,
          allWorkspaces,
          allTasks,
          allChannels,
        );
        mentionActiveIdx = 0;
        mentionProps = { query: q, command: props.command };
        const rect = props.clientRect?.();
        if (rect) ({ x: mentionX, y: mentionY } = positionFromClientRect(rect));
      },
      onExit() {
        mentionProps = null;
        mentionItems = [];
      },
      onKeyDown({ event }: { event: KeyboardEvent }): boolean {
        if (event.key === 'ArrowDown') {
          mentionActiveIdx = Math.min(mentionActiveIdx + 1, mentionItems.length - 1);
          return true;
        }
        if (event.key === 'ArrowUp') {
          mentionActiveIdx = Math.max(mentionActiveIdx - 1, 0);
          return true;
        }
        if (event.key === 'Enter') {
          const item = mentionItems[mentionActiveIdx];
          if (item && mentionProps) {
            mentionProps.command({ id: item.slug, label: item.label });
            mentionProps = null;
            mentionItems = [];
          }
          return true;
        }
        if (event.key === 'Escape') {
          mentionProps = null;
          mentionItems = [];
          return true;
        }
        return false;
      },
    });
  }

  function makeSlashRenderer() {
    return () => ({
      onStart(props: {
        query: string;
        command: (p: { id: string; label: string }) => void;
        clientRect?: (() => DOMRect | null) | null;
      }) {
        const q = props.query ?? '';
        slashItems = filterSlashCommands(q);
        slashActiveIdx = 0;
        slashProps = { query: q, command: props.command };
        const rect = props.clientRect?.();
        if (rect) ({ x: slashX, y: slashY } = positionFromClientRect(rect));
      },
      onUpdate(props: {
        query: string;
        command: (p: { id: string; label: string }) => void;
        clientRect?: (() => DOMRect | null) | null;
      }) {
        const q = props.query ?? '';
        slashItems = filterSlashCommands(q);
        slashActiveIdx = 0;
        slashProps = { query: q, command: props.command };
        const rect = props.clientRect?.();
        if (rect) ({ x: slashX, y: slashY } = positionFromClientRect(rect));
      },
      onExit() {
        slashProps = null;
        slashItems = [];
      },
      onKeyDown({ event }: { event: KeyboardEvent }): boolean {
        if (event.key === 'ArrowDown') {
          slashActiveIdx = Math.min(slashActiveIdx + 1, slashItems.length - 1);
          return true;
        }
        if (event.key === 'ArrowUp') {
          slashActiveIdx = Math.max(slashActiveIdx - 1, 0);
          return true;
        }
        if (event.key === 'Enter') {
          execSlash(slashActiveIdx);
          return true;
        }
        if (event.key === 'Escape') {
          slashProps = null;
          slashItems = [];
          return true;
        }
        return false;
      },
    });
  }

  function filterSlashCommands(q: string): SlashCommand[] {
    if (!q) return SLASH_COMMANDS;
    const lower = q.toLowerCase();
    return SLASH_COMMANDS.filter(
      (c) =>
        c.label.toLowerCase().includes(lower) ||
        c.description.toLowerCase().includes(lower),
    );
  }

  function execSlash(idx: number): void {
    const cmd = slashItems[idx];
    if (!cmd || !slashProps || !editor) return;
    // Commit the slash node (clears the "/" text) then run the command
    slashProps.command({ id: cmd.id, label: cmd.label });
    slashProps = null;
    slashItems = [];
    // Run the actual formatting action after the mention node is removed
    setTimeout(() => {
      if (!editor) return;
      // Delete the inserted mention node (slash command acts as a trigger, not a node)
      editor.chain().focus().deleteSelection().run();
      cmd.action(editor);
    }, 0);
  }

  // ── Bubble menu helpers ───────────────────────────────────────────────────────

  function updateBubble(ed: Editor): void {
    const { state } = ed;
    const { selection } = state;
    const { from, to, empty } = selection;

    if (empty) {
      bubbleVisible = false;
      return;
    }

    bubbleFormats = {
      bold: ed.isActive('bold'),
      italic: ed.isActive('italic'),
      strike: ed.isActive('strike'),
      code: ed.isActive('code'),
      link: ed.isActive('link'),
    };

    // Position bubble above the selection midpoint
    const view = ed.view;
    const start = view.coordsAtPos(from);
    const end = view.coordsAtPos(to);
    bubbleX = (start.left + end.left) / 2;
    bubbleY = start.top - 8; // above the selection
    bubbleVisible = true;
  }

  // ── Editor init ───────────────────────────────────────────────────────────────

  onMount(() => {
    if (!editorEl) return;

    editor = new Editor({
      element: editorEl,
      editable,
      content: initialJson ?? undefined,
      extensions: [
        StarterKit.configure({
          codeBlock: false, // replaced by CodeBlockLowlight
        }),
        Typography,
        CodeBlockLowlight.configure({ lowlight }),
        Placeholder.configure({ placeholder }),
        Link.configure({
          openOnClick: false,
          HTMLAttributes: { rel: 'noopener noreferrer', target: '_blank' },
        }),
        Image,
        Table.configure({ resizable: false }),
        TableRow,
        TableCell,
        TableHeader,
        // @mention — entity autocomplete
        Mention.configure({
          HTMLAttributes: { class: 'te-mention' },
          suggestion: {
            char: '@',
            allowSpaces: false,
            render: makeMentionRenderer(),
            items: ({ query }: { query: string }) =>
              buildMentionResults(query, allAgents, allWorkspaces, allTasks, allChannels).map(
                (m) => ({ id: m.slug, label: m.label }),
              ),
          },
        }),
        // Slash commands — reuse Mention extension with "/" trigger
        Mention.extend({ name: 'slash-command' }).configure({
          HTMLAttributes: { class: 'te-slash-node' },
          suggestion: {
            char: '/',
            allowSpaces: false,
            render: makeSlashRenderer(),
            items: ({ query }: { query: string }) =>
              filterSlashCommands(query).map((c) => ({ id: c.id, label: c.label })),
          },
        }),
      ],
      onUpdate: ({ editor: ed }) => {
        const json = ed.getJSON() as ProseMirrorDoc;
        const text = ed.getText();
        onChange?.(json, text);
      },
      onSelectionUpdate: ({ editor: ed }) => {
        updateBubble(ed);
      },
      onBlur: () => {
        bubbleVisible = false;
      },
      onTransaction: ({ editor: ed }) => {
        // Keep bubble in sync on any transaction
        updateBubble(ed);
      },
    });

    // ⌘Enter → onSubmit
    editorEl.addEventListener('keydown', handleEditorKeydown);
  });

  onDestroy(() => {
    editorEl?.removeEventListener('keydown', handleEditorKeydown);
    editor?.destroy();
    editor = null;
  });

  // ── Keyboard: ⌘Enter ──────────────────────────────────────────────────────────

  function handleEditorKeydown(e: KeyboardEvent): void {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      onSubmit?.();
    }
    // ⌘K → link dialog
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      if (!editor) return;
      const url = window.prompt('Link URL', editor.getAttributes('link').href ?? '');
      if (url === null) return; // cancelled
      if (url === '') {
        editor.chain().focus().unsetLink().run();
      } else {
        editor.chain().focus().setLink({ href: url }).run();
      }
    }
  }

  // ── Bubble menu actions ────────────────────────────────────────────────────────

  function bubbleToggle(format: 'bold' | 'italic' | 'strike' | 'code'): void {
    if (!editor) return;
    const cmds: Record<string, () => boolean> = {
      bold: () => editor!.chain().focus().toggleBold().run(),
      italic: () => editor!.chain().focus().toggleItalic().run(),
      strike: () => editor!.chain().focus().toggleStrike().run(),
      code: () => editor!.chain().focus().toggleCode().run(),
    };
    cmds[format]?.();
  }

  function bubbleLink(): void {
    if (!editor) return;
    const current = editor.getAttributes('link').href as string | undefined;
    const url = window.prompt('Link URL', current ?? '');
    if (url === null) return;
    if (url === '') {
      editor.chain().focus().unsetLink().run();
    } else {
      editor.chain().focus().setLink({ href: url }).run();
    }
  }

  function bubbleClearFormatting(): void {
    editor?.chain().focus().unsetAllMarks().run();
  }

  // ── Mention selection (click) ─────────────────────────────────────────────────

  function selectMentionItem(item: MentionItem): void {
    if (!mentionProps) return;
    mentionProps.command({ id: item.slug, label: item.label });
    mentionProps = null;
    mentionItems = [];
  }

  // ── Category labels ───────────────────────────────────────────────────────────

  const CATEGORY_LABELS: Record<MentionCategory, string> = {
    agents: 'Agents',
    workspaces: 'Workspaces',
    tasks: 'Tasks',
    channels: 'Channels',
  };

  function taskDotColor(status: Task['status']): 'green' | 'amber' | 'grey' | 'red' {
    if (status === 'in_progress') return 'green';
    if (status === 'todo') return 'grey';
    if (status === 'done') return 'grey';
    return 'red';
  }

  const groupedMentions = $derived.by(() => {
    const map = new Map<MentionCategory, MentionItem[]>();
    for (const item of mentionItems) {
      const bucket = map.get(item.category) ?? [];
      bucket.push(item);
      map.set(item.category, bucket);
    }
    return map;
  });
</script>

<!-- ── Editor shell ──────────────────────────────────────────────────────────── -->
<div class="te-wrap" class:te-wrap--readonly={!editable}>
  <div class="te-editor" bind:this={editorEl}></div>
</div>

<!-- ── Bubble menu ────────────────────────────────────────────────────────────── -->
{#if bubbleVisible}
  <div
    class="te-bubble glass"
    style="left: {bubbleX}px; top: {bubbleY}px;"
    role="toolbar"
    aria-label="Text formatting"
  >
    <button
      class="te-bubble-btn"
      class:te-bubble-btn--active={bubbleFormats.bold}
      onclick={() => bubbleToggle('bold')}
      aria-label="Bold"
      aria-pressed={bubbleFormats.bold}
    >
      <strong>B</strong>
    </button>
    <button
      class="te-bubble-btn"
      class:te-bubble-btn--active={bubbleFormats.italic}
      onclick={() => bubbleToggle('italic')}
      aria-label="Italic"
      aria-pressed={bubbleFormats.italic}
    >
      <em>I</em>
    </button>
    <button
      class="te-bubble-btn"
      class:te-bubble-btn--active={bubbleFormats.strike}
      onclick={() => bubbleToggle('strike')}
      aria-label="Strikethrough"
      aria-pressed={bubbleFormats.strike}
    >
      <s>S</s>
    </button>
    <button
      class="te-bubble-btn"
      class:te-bubble-btn--active={bubbleFormats.code}
      onclick={() => bubbleToggle('code')}
      aria-label="Inline code"
      aria-pressed={bubbleFormats.code}
    >
      <span class="te-bubble-mono">&lt;/&gt;</span>
    </button>
    <div class="te-bubble-sep" role="separator"></div>
    <button
      class="te-bubble-btn"
      class:te-bubble-btn--active={bubbleFormats.link}
      onclick={bubbleLink}
      aria-label="Link"
      aria-pressed={bubbleFormats.link}
    >
      ⌘K
    </button>
    <div class="te-bubble-sep" role="separator"></div>
    <button
      class="te-bubble-btn"
      onclick={bubbleClearFormatting}
      aria-label="Clear formatting"
    >
      ✕
    </button>
  </div>
{/if}

<!-- ── @mention dropdown ──────────────────────────────────────────────────────── -->
{#if mentionOpen}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="te-dropdown glass"
    style="left: {mentionX}px; top: {mentionY}px;"
    role="listbox"
    aria-label="Mention suggestions"
  >
    {#each [...groupedMentions.entries()] as [cat, items] (cat)}
      <div class="te-dropdown-category">
        <span class="te-dropdown-category__label">{CATEGORY_LABELS[cat]}</span>
        {#each items as item (item.id)}
          {@const globalIdx = mentionItems.indexOf(item)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <button
            class="te-dropdown-row"
            class:te-dropdown-row--active={globalIdx === mentionActiveIdx}
            role="option"
            aria-selected={globalIdx === mentionActiveIdx}
            onmousedown={(e) => { e.preventDefault(); selectMentionItem(item); }}
          >
            {#if item.category === 'tasks'}
              <StatusDot color={taskDotColor(item.taskStatus ?? 'todo')} />
            {:else if item.emoji}
              <span class="te-dropdown-emoji" aria-hidden="true">{item.emoji}</span>
            {:else}
              <span class="te-dropdown-icon" aria-hidden="true">#</span>
            {/if}
            <span class="te-dropdown-label">{item.label}</span>
            {#if item.sublabel}
              <span class="te-dropdown-sub">{item.sublabel}</span>
            {/if}
          </button>
        {/each}
      </div>
    {/each}
  </div>
{/if}

<!-- ── Slash command dropdown ─────────────────────────────────────────────────── -->
{#if slashOpen}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="te-dropdown glass"
    style="left: {slashX}px; top: {slashY}px;"
    role="listbox"
    aria-label="Slash commands"
  >
    {#each slashItems as cmd, i (cmd.id)}
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <button
        class="te-dropdown-row te-dropdown-row--slash"
        class:te-dropdown-row--active={i === slashActiveIdx}
        role="option"
        aria-selected={i === slashActiveIdx}
        onmousedown={(e) => { e.preventDefault(); execSlash(i); }}
      >
        <span class="te-dropdown-label">{cmd.label}</span>
        <span class="te-dropdown-sub">{cmd.description}</span>
      </button>
    {/each}
  </div>
{/if}

<style>
  /* ── Shell ──────────────────────────────────────────────────────────────────── */

  .te-wrap {
    position: relative;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    transition: border-color var(--dur-instant) var(--ease-out),
      outline var(--dur-instant) var(--ease-out);
  }

  .te-wrap:focus-within {
    outline: 2px solid var(--cnp-accent);
    outline-offset: -1px;
    border-color: transparent;
  }

  .te-wrap--readonly {
    background: var(--bg-inset);
  }

  /* ── ProseMirror editor content ─────────────────────────────────────────────── */

  .te-editor {
    padding: var(--space-4);
    min-height: 400px;
    cursor: text;
  }

  :global(.te-editor .ProseMirror) {
    outline: none;
    font-family: var(--font-sans);
    font-size: 15px;
    line-height: 1.65;
    color: var(--fg);
    word-break: break-word;
  }

  /* Placeholder */
  :global(.te-editor .ProseMirror p.is-editor-empty:first-child::before) {
    content: attr(data-placeholder);
    float: left;
    color: var(--fg-subtle);
    pointer-events: none;
    height: 0;
  }

  /* Paragraph */
  :global(.te-editor .ProseMirror p) {
    margin: 0 0 0.6em;
  }

  :global(.te-editor .ProseMirror p:last-child) {
    margin-bottom: 0;
  }

  /* Headings */
  :global(.te-editor .ProseMirror h1) {
    font-family: var(--font-sans);
    font-size: 24px;
    font-weight: 700;
    line-height: 1.2;
    color: var(--fg);
    letter-spacing: -0.02em;
    margin: 1.4em 0 0.4em;
  }

  :global(.te-editor .ProseMirror h1:first-child) {
    margin-top: 0;
  }

  :global(.te-editor .ProseMirror h2) {
    font-family: var(--font-sans);
    font-size: 19px;
    font-weight: 600;
    line-height: 1.25;
    color: var(--fg);
    letter-spacing: -0.01em;
    margin: 1.2em 0 0.35em;
  }

  :global(.te-editor .ProseMirror h3) {
    font-family: var(--font-sans);
    font-size: 16px;
    font-weight: 600;
    line-height: 1.3;
    color: var(--fg);
    margin: 1em 0 0.3em;
  }

  /* Lists */
  :global(.te-editor .ProseMirror ul),
  :global(.te-editor .ProseMirror ol) {
    padding-left: 1.4em;
    margin: 0.4em 0 0.6em;
  }

  :global(.te-editor .ProseMirror li) {
    margin: 0.15em 0;
    line-height: 1.6;
  }

  /* Blockquote */
  :global(.te-editor .ProseMirror blockquote) {
    border-left: 3px solid var(--border-strong);
    margin: 0.6em 0;
    padding: 0.2em 0 0.2em 0.85em;
    color: var(--fg-muted);
    font-style: italic;
  }

  /* Horizontal rule */
  :global(.te-editor .ProseMirror hr) {
    border: none;
    border-top: 1px solid var(--border);
    margin: 1.2em 0;
  }

  /* Inline code */
  :global(.te-editor .ProseMirror code) {
    font-family: var(--font-mono);
    font-size: 13px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 4px;
    color: var(--fg-muted);
  }

  /* Code block */
  :global(.te-editor .ProseMirror pre) {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3) var(--space-4);
    overflow-x: auto;
    margin: 0.6em 0;
  }

  :global(.te-editor .ProseMirror pre code) {
    font-family: var(--font-mono);
    font-size: 13px;
    background: none;
    border: none;
    padding: 0;
    border-radius: 0;
    color: var(--fg-muted);
    line-height: 1.6;
  }

  /* Links */
  :global(.te-editor .ProseMirror a) {
    color: var(--cnp-accent);
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  /* Images */
  :global(.te-editor .ProseMirror img) {
    max-width: 100%;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    display: block;
    margin: 0.6em 0;
  }

  /* Tables */
  :global(.te-editor .ProseMirror table) {
    border-collapse: collapse;
    width: 100%;
    margin: 0.6em 0;
    font-size: 14px;
  }

  :global(.te-editor .ProseMirror th),
  :global(.te-editor .ProseMirror td) {
    border: 1px solid var(--border);
    padding: var(--space-2) var(--space-3);
    text-align: left;
    vertical-align: top;
    min-width: 60px;
  }

  :global(.te-editor .ProseMirror th) {
    font-weight: 600;
    color: var(--fg);
    background: var(--bg-inset);
  }

  :global(.te-editor .ProseMirror td) {
    color: var(--fg-muted);
  }

  /* Selected table cell */
  :global(.te-editor .ProseMirror .selectedCell) {
    background: color-mix(in oklch, var(--cnp-accent) 10%, transparent 90%);
  }

  /* Mention node */
  :global(.te-editor .ProseMirror .te-mention) {
    font-family: var(--font-mono);
    font-size: 13px;
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent 88%);
    color: var(--cnp-accent);
    border-radius: var(--radius-sm);
    padding: 1px 4px;
  }

  /* Slash node — invisible, gets deleted immediately after command runs */
  :global(.te-editor .ProseMirror .te-slash-node) {
    display: none;
  }

  /* ── Bubble menu ──────────────────────────────────────────────────────────── */

  .te-bubble {
    position: fixed;
    z-index: 200;
    display: flex;
    align-items: center;
    gap: 1px;
    padding: 3px 4px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    transform: translate(-50%, -100%);
    white-space: nowrap;
    pointer-events: all;
  }

  .te-bubble-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 28px;
    height: 26px;
    padding: 0 6px;
    border: none;
    background: transparent;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-muted);
    transition: background var(--dur-instant) var(--ease-out), color var(--dur-instant) var(--ease-out);
  }

  .te-bubble-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .te-bubble-btn--active {
    background: color-mix(in oklch, var(--cnp-accent) 15%, transparent 85%);
    color: var(--cnp-accent);
  }

  .te-bubble-mono {
    font-family: var(--font-mono);
    font-size: 11px;
  }

  .te-bubble-sep {
    width: 1px;
    height: 16px;
    background: var(--border);
    margin: 0 2px;
    flex-shrink: 0;
  }

  /* ── Shared dropdown (mention + slash) ──────────────────────────────────────── */

  .te-dropdown {
    position: fixed;
    z-index: 150;
    width: 280px;
    max-height: 320px;
    overflow-y: auto;
    border-radius: var(--radius-lg);
    padding: var(--space-1);
    display: flex;
    flex-direction: column;
    gap: 2px;
    border: 1px solid var(--border);
  }

  .te-dropdown-category {
    display: flex;
    flex-direction: column;
    gap: 1px;
    margin-bottom: var(--space-1);
  }

  .te-dropdown-category:last-child {
    margin-bottom: 0;
  }

  .te-dropdown-category__label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    padding: var(--space-1) var(--space-3);
    user-select: none;
  }

  .te-dropdown-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-align: left;
    width: 100%;
    transition: background var(--dur-instant) var(--ease-out);
    min-height: 32px;
  }

  .te-dropdown-row:hover,
  .te-dropdown-row--active {
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent 88%);
    color: var(--fg);
  }

  .te-dropdown-row--slash {
    padding: var(--space-2) var(--space-3);
  }

  .te-dropdown-emoji {
    font-size: 14px;
    line-height: 1;
    flex-shrink: 0;
    width: 16px;
    text-align: center;
  }

  .te-dropdown-icon {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    flex-shrink: 0;
    width: 16px;
    text-align: center;
  }

  .te-dropdown-label {
    font-weight: 500;
    flex-shrink: 0;
    max-width: 120px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .te-dropdown-sub {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin-left: auto;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 130px;
  }
</style>
