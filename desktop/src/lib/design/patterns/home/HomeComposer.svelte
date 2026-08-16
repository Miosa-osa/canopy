<script lang="ts">
import { onMount } from 'svelte';
import { createQuery, createMutation, useQueryClient } from '@tanstack/svelte-query';
import { goto } from '$app/navigation';
import { ArrowUp, Bot, ChevronDown, Cpu, Paperclip, X, FileIcon } from 'lucide-svelte';
import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
import { createSessionMutation } from '$lib/api/queries/sessions.js';
import { uploadFileMutation } from '$lib/api/queries/files.js';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';
import { mosaicLayout } from '$lib/stores/mosaic-layout.svelte.js';
import { PROVIDERS, type ProviderConfig } from '$lib/domain/runtimes/providers.js';
import type { Agent } from '$lib/domain/agents/types.js';

interface Props {
  onSubmitPrompt?: (prompt: string) => void;
}

let { onSubmitPrompt }: Props = $props();

const qc = useQueryClient();
const agentsQ = createQuery(hiredAgentsQuery());
const createMut = createMutation(createSessionMutation());
const uploadMut = createMutation(uploadFileMutation());

const agents = $derived(($agentsQ.data ?? []) as Agent[]);
let selectedSlug = $state('');
let selectedRuntime = $state(PROVIDERS[0].id);
let prompt = $state('');
let textareaEl = $state<HTMLTextAreaElement | null>(null);
let fileInputEl = $state<HTMLInputElement | null>(null);
let submitting = $state(false);
let focused = $state(false);
let dragging = $state(false);

interface Attachment {
  id: string;
  name: string;
  size: number;
  type: string;
  preview?: string;
  uploading: boolean;
  fileId?: string;
}

let attachments = $state<Attachment[]>([]);

const activeProvider = $derived<ProviderConfig>(
  PROVIDERS.find((p) => p.id === selectedRuntime) ?? PROVIDERS[0],
);
const canSend = $derived(!submitting && (prompt.trim().length > 0 || attachments.length > 0));

$effect(() => {
  if (!selectedSlug && agents.length > 0) {
    selectedSlug = agents[0].slug;
  }
});

onMount(() => { textareaEl?.focus(); });

function autogrow(): void {
  if (!textareaEl) return;
  textareaEl.style.height = 'auto';
  textareaEl.style.height = `${Math.min(textareaEl.scrollHeight, 200)}px`;
}

function isImageType(type: string): boolean {
  return type.startsWith('image/');
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

async function addFiles(files: FileList | File[]): Promise<void> {
  for (const file of Array.from(files)) {
    const tempId = crypto.randomUUID();
    const preview = isImageType(file.type) ? URL.createObjectURL(file) : undefined;

    attachments = [...attachments, {
      id: tempId, name: file.name, size: file.size, type: file.type,
      preview, uploading: true,
    }];

    const slug = activeWorkspace.slug;
    if (slug) {
      try {
        const result = await $uploadMut.mutateAsync({
          workspaceSlug: slug,
          path: `attachments/${file.name}`,
          file,
        });
        attachments = attachments.map((a) =>
          a.id === tempId ? { ...a, uploading: false, fileId: result.id } : a,
        );
      } catch {
        attachments = attachments.map((a) =>
          a.id === tempId ? { ...a, uploading: false } : a,
        );
      }
    } else {
      attachments = attachments.map((a) =>
        a.id === tempId ? { ...a, uploading: false } : a,
      );
    }
  }
}

function removeAttachment(id: string): void {
  const att = attachments.find((a) => a.id === id);
  if (att?.preview) URL.revokeObjectURL(att.preview);
  attachments = attachments.filter((a) => a.id !== id);
}

function handleDragEnter(e: DragEvent): void { e.preventDefault(); dragging = true; }
function handleDragOver(e: DragEvent): void { e.preventDefault(); dragging = true; }

function handleDragLeave(e: DragEvent): void {
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
  const { clientX: x, clientY: y } = e;
  if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) dragging = false;
}

function handleDrop(e: DragEvent): void {
  e.preventDefault();
  dragging = false;
  if (e.dataTransfer?.files?.length) void addFiles(e.dataTransfer.files);
}

function handleFileInput(e: Event): void {
  const input = e.target as HTMLInputElement;
  if (input.files?.length) { void addFiles(input.files); input.value = ''; }
}

function handlePaste(e: ClipboardEvent): void {
  const items = e.clipboardData?.items;
  if (!items) return;
  const files: File[] = [];
  for (const item of items) {
    if (item.kind === 'file') { const f = item.getAsFile(); if (f) files.push(f); }
  }
  if (files.length > 0) { e.preventDefault(); void addFiles(files); }
}

async function handleSubmit(): Promise<void> {
  const text = prompt.trim();
  const hasAttachments = attachments.length > 0;
  if ((!text && !hasAttachments) || submitting) return;

  submitting = true;
  try {
    const fileRefs = attachments.filter((a) => a.fileId).map((a) => a.fileId!);

    let fullPrompt = text;
    if (fileRefs.length > 0) {
      const fileList = attachments
        .filter((a) => a.fileId)
        .map((a) => `[${a.name}](file://${a.fileId})`)
        .join('\n');
      fullPrompt = fullPrompt
        ? `${fullPrompt}\n\nAttached files:\n${fileList}`
        : `Attached files:\n${fileList}`;
    }

    const session = await $createMut.mutateAsync({
      runtimeType: selectedRuntime,
      workspaceSlug: activeWorkspace.slug ?? undefined,
      cwd: activeWorkspace.rootPath ?? '~',
      agentSlug: selectedSlug || undefined,
      prompt: fullPrompt || undefined,
    });

    await qc.invalidateQueries({ queryKey: ['sessions'] });

    mosaicLayout.openPane({
      id: session.id,
      kind: 'session',
      ref: session.id,
      title: (text || attachments[0]?.name || 'New session').slice(0, 40),
      config: {
        sessionId: session.id,
        cwd: activeWorkspace.rootPath ?? '~',
        fileIds: fileRefs.length > 0 ? fileRefs : undefined,
      },
    });

    prompt = '';
    attachments.forEach((a) => { if (a.preview) URL.revokeObjectURL(a.preview); });
    attachments = [];
    onSubmitPrompt?.(fullPrompt);
    await goto('/build');
  } finally {
    submitting = false;
  }
}

function handleKeydown(e: KeyboardEvent): void {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    void handleSubmit();
  }
}

export function submitPrompt(text: string): void {
  prompt = text;
  void handleSubmit();
}
</script>

<div
  class="hc-card"
  class:hc-card--focused={focused}
  class:hc-card--dragging={dragging}
  role="region"
  aria-label="Prompt composer"
  ondragenter={handleDragEnter}
  ondragover={handleDragOver}
  ondragleave={handleDragLeave}
  ondrop={handleDrop}
>
  {#if dragging}
    <div class="hc-drop-overlay" aria-hidden="true">
      <Paperclip size={20} aria-hidden="true" />
      <span>Drop files to attach</span>
    </div>
  {/if}

  <textarea
    bind:this={textareaEl}
    bind:value={prompt}
    class="hc-textarea"
    placeholder="Ask anything..."
    rows="3"
    disabled={submitting}
    oninput={autogrow}
    onkeydown={handleKeydown}
    onfocus={() => focused = true}
    onblur={() => focused = false}
    onpaste={handlePaste}
    aria-label="Prompt input"
    autocomplete="off"
    spellcheck="true"
  ></textarea>

  {#if attachments.length > 0}
    <div class="hc-attachments" role="list" aria-label="Attached files">
      {#each attachments as att (att.id)}
        <div class="hc-att" class:hc-att--uploading={att.uploading} role="listitem">
          {#if att.preview}
            <img src={att.preview} alt={att.name} class="hc-att__preview" />
          {:else}
            <span class="hc-att__icon"><FileIcon size={14} aria-hidden="true" /></span>
          {/if}
          <span class="hc-att__name">{att.name}</span>
          <span class="hc-att__size">{formatSize(att.size)}</span>
          {#if att.uploading}
            <span class="hc-att__spinner" aria-label="Uploading"></span>
          {:else}
            <button class="hc-att__remove" onclick={() => removeAttachment(att.id)} aria-label="Remove {att.name}">
              <X size={12} aria-hidden="true" />
            </button>
          {/if}
        </div>
      {/each}
    </div>
  {/if}

  <div class="hc-bar">
    <div class="hc-bar__left">
      <button
        class="hc-attach-btn"
        onclick={() => fileInputEl?.click()}
        disabled={submitting}
        aria-label="Attach files"
        title="Attach files"
      >
        <Paperclip size={14} aria-hidden="true" />
      </button>
      <input
        bind:this={fileInputEl}
        type="file"
        multiple
        class="hc-file-input"
        onchange={handleFileInput}
        accept="image/*,.pdf,.md,.txt,.json,.csv,.ts,.tsx,.js,.jsx,.svelte,.py,.go,.rs,.ex,.exs,.sql,.yaml,.yml,.toml,.html,.css"
        aria-hidden="true"
        tabindex="-1"
      />

      <span class="hc-sep" aria-hidden="true"></span>

      {#if agents.length > 0}
        <button class="hc-control" aria-label="Select agent" disabled={submitting}>
          <Bot size={13} aria-hidden="true" />
          <select
            class="hc-control__select"
            bind:value={selectedSlug}
            disabled={submitting}
            aria-label="Select agent"
          >
            {#each agents as agent (agent.slug)}
              <option value={agent.slug}>{agent.name}</option>
            {/each}
          </select>
          <ChevronDown size={10} aria-hidden="true" />
        </button>
      {/if}

      <button class="hc-control" aria-label="Select runtime" disabled={submitting}>
        <Cpu size={13} aria-hidden="true" />
        <select
          class="hc-control__select"
          bind:value={selectedRuntime}
          disabled={submitting}
          aria-label="Select runtime"
        >
          {#each PROVIDERS as provider (provider.id)}
            <option value={provider.id}>{provider.name}</option>
          {/each}
        </select>
        <ChevronDown size={10} aria-hidden="true" />
      </button>
    </div>

    <div class="hc-bar__right">
      <span class="hc-keys">
        <kbd class="hc-kbd">Return</kbd> send
        <kbd class="hc-kbd">Shift+Return</kbd> newline
      </span>
      <button
        class="hc-send"
        class:hc-send--active={canSend}
        onclick={() => void handleSubmit()}
        disabled={!canSend}
        aria-label="Send prompt"
      >
        {#if submitting}
          <span class="hc-spinner" aria-hidden="true"></span>
        {:else}
          <ArrowUp size={16} strokeWidth={2.5} aria-hidden="true" />
        {/if}
      </button>
    </div>
  </div>
</div>

<style>
  .hc-card {
    position: relative;
    background: var(--bg-elevated, var(--bg));
    border: 1px solid var(--border);
    border-radius: var(--radius-lg, 12px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    transition: border-color 150ms ease-out, box-shadow 150ms ease-out;
  }

  .hc-card--focused {
    border-color: color-mix(in oklch, var(--cnp-accent, #6366f1) 50%, var(--border));
    box-shadow: 0 0 0 3px color-mix(in oklch, var(--cnp-accent, #6366f1) 10%, transparent);
  }

  .hc-card--dragging {
    border-color: var(--cnp-accent, #6366f1);
    box-shadow: 0 0 0 3px color-mix(in oklch, var(--cnp-accent, #6366f1) 15%, transparent);
  }

  .hc-drop-overlay {
    position: absolute;
    inset: 0;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    background: color-mix(in oklch, var(--bg) 92%, var(--cnp-accent, #6366f1));
    border-radius: inherit;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--cnp-accent, #6366f1);
    font-weight: 500;
    pointer-events: none;
  }

  .hc-textarea {
    font-family: var(--font-sans);
    font-size: 14px;
    line-height: 1.6;
    color: var(--fg);
    background: transparent;
    border: none;
    outline: none;
    resize: none;
    padding: 16px 16px 8px;
    min-height: 72px;
    max-height: 200px;
    width: 100%;
    box-sizing: border-box;
  }

  .hc-textarea::placeholder { color: var(--fg-subtle); }
  .hc-textarea:disabled { opacity: 0.5; cursor: not-allowed; }

  .hc-attachments {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    padding: 0 12px 8px;
  }

  .hc-att {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 3px 8px;
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 6px);
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
    max-width: 200px;
  }

  .hc-att--uploading { opacity: 0.6; }

  .hc-att__preview {
    width: 22px;
    height: 22px;
    border-radius: 3px;
    object-fit: cover;
    flex-shrink: 0;
  }

  .hc-att__icon {
    display: inline-flex;
    flex-shrink: 0;
    color: var(--fg-subtle);
  }

  .hc-att__name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
    min-width: 0;
  }

  .hc-att__size {
    font-family: var(--font-mono);
    font-size: 9px;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .hc-att__remove {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    border: none;
    background: none;
    color: var(--fg-subtle);
    cursor: pointer;
    border-radius: 50%;
    padding: 0;
    flex-shrink: 0;
    transition: color 80ms, background 80ms;
  }

  .hc-att__remove:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
  }

  .hc-att__spinner {
    display: inline-block;
    width: 10px;
    height: 10px;
    border: 1.5px solid var(--fg-subtle);
    border-top-color: transparent;
    border-radius: 50%;
    animation: hc-spin 0.7s linear infinite;
    flex-shrink: 0;
  }

  .hc-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
    border-top: 1px solid color-mix(in oklch, var(--border) 60%, transparent);
    gap: 8px;
    flex-wrap: wrap;
  }

  .hc-bar__left {
    display: flex;
    align-items: center;
    gap: 4px;
    flex-wrap: wrap;
  }

  .hc-bar__right {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-left: auto;
  }

  .hc-file-input {
    position: absolute;
    width: 0;
    height: 0;
    opacity: 0;
    pointer-events: none;
  }

  .hc-attach-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 6px);
    background: transparent;
    color: var(--fg-muted);
    cursor: pointer;
    transition: border-color 100ms, color 100ms, background 100ms;
    flex-shrink: 0;
  }

  .hc-attach-btn:hover:not(:disabled) {
    border-color: var(--fg-subtle);
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .hc-attach-btn:disabled { opacity: 0.4; cursor: not-allowed; }

  .hc-sep {
    width: 1px;
    height: 16px;
    background: var(--border);
    flex-shrink: 0;
  }

  .hc-control {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 6px);
    padding: 3px 6px 3px 7px;
    cursor: pointer;
    transition: border-color 120ms, background 120ms;
    white-space: nowrap;
  }

  .hc-control:hover:not(:disabled) {
    border-color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .hc-control:disabled { opacity: 0.4; cursor: not-allowed; }

  .hc-control__select {
    position: absolute;
    inset: 0;
    opacity: 0;
    cursor: pointer;
    font-size: 13px;
  }

  .hc-control__select:disabled { cursor: not-allowed; }

  .hc-keys {
    display: flex;
    align-items: center;
    gap: 4px;
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
  }

  .hc-kbd {
    font-family: var(--font-mono);
    font-size: 9px;
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border: 1px solid color-mix(in oklch, var(--border) 80%, transparent);
    border-radius: 3px;
    padding: 1px 4px;
    line-height: 1.3;
  }

  .hc-send {
    width: 30px;
    height: 30px;
    border-radius: 50%;
    border: none;
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    color: var(--fg-subtle);
    cursor: not-allowed;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    transition: background 120ms, color 120ms, transform 80ms;
    flex-shrink: 0;
  }

  .hc-send--active {
    background: var(--fg);
    color: var(--bg);
    cursor: pointer;
  }

  .hc-send--active:hover { transform: scale(1.06); }
  .hc-send:disabled:not(.hc-send--active) { opacity: 0.5; }

  .hc-spinner {
    display: inline-block;
    width: 14px;
    height: 14px;
    border: 2px solid currentColor;
    border-top-color: transparent;
    border-radius: 50%;
    animation: hc-spin 0.7s linear infinite;
  }

  @keyframes hc-spin { to { transform: rotate(360deg); } }

  @media (prefers-reduced-motion: reduce) {
    .hc-spinner { animation-duration: 1.5s; }
    .hc-att__spinner { animation-duration: 1.5s; }
  }
</style>
