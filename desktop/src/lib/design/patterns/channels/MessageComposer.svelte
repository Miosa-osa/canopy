<script lang="ts">
/**
 * MessageComposer — fixed bottom message input.
 * Shift+Enter = newline. Enter = send.
 * CSS prefix: mc- (MessageComposer)
 * LOC target: ≤100
 */
import { Paperclip, Send } from 'lucide-svelte';

interface Props {
  placeholder?: string;
  disabled?: boolean;
  onSend: (body: string) => void | Promise<void>;
}

let { placeholder = 'Message…', disabled = false, onSend }: Props = $props();

let body = $state('');
let sending = $state(false);
let textareaEl = $state<HTMLTextAreaElement | null>(null);

function autoResize() {
  if (!textareaEl) return;
  textareaEl.style.height = 'auto';
  textareaEl.style.height = `${Math.min(textareaEl.scrollHeight, 160)}px`;
}

async function handleSend() {
  const text = body.trim();
  if (!text || sending || disabled) return;
  sending = true;
  body = '';
  if (textareaEl) textareaEl.style.height = 'auto';
  try {
    await onSend(text);
  } finally {
    sending = false;
    textareaEl?.focus();
  }
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    void handleSend();
  }
}

const canSend = $derived(body.trim().length > 0 && !sending && !disabled);
</script>

<div class="mc-wrap" role="form" aria-label="Message composer">
  <button class="mc-attach" aria-label="Attach file" disabled={disabled} title="Attach">
    <Paperclip size={13} aria-hidden="true" />
  </button>

  <textarea
    class="mc-input"
    bind:this={textareaEl}
    bind:value={body}
    {placeholder}
    disabled={disabled || sending}
    onkeydown={handleKeydown}
    oninput={autoResize}
    rows={1}
    aria-label="Message body"
    aria-multiline="true"
    spellcheck={true}
  ></textarea>

  <button
    class="mc-send"
    class:mc-send--active={canSend}
    onclick={() => void handleSend()}
    disabled={!canSend}
    aria-label="Send message"
    title="Send (Enter)"
  >
    <Send size={13} aria-hidden="true" />
  </button>
</div>

<style>
  .mc-wrap {
    display: flex;
    align-items: flex-end;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border-top: 1px solid var(--border);
    background: var(--bg);
  }

  .mc-attach {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    flex-shrink: 0;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    color: var(--fg-subtle);
    cursor: pointer;
    padding: 0;
    margin-bottom: 1px;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .mc-attach:hover:not(:disabled) {
    color: var(--fg-muted);
  }

  .mc-attach:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .mc-input {
    flex: 1;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: 6px 10px;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    outline: none;
    resize: none;
    min-height: 32px;
    max-height: 160px;
    line-height: 1.5;
    transition: border-color var(--dur-instant) var(--ease-out);
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .mc-input::placeholder {
    color: var(--fg-subtle);
  }

  .mc-input:focus {
    border-color: var(--border-strong);
  }

  .mc-input:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .mc-send {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    flex-shrink: 0;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    color: var(--fg-subtle);
    cursor: pointer;
    padding: 0;
    margin-bottom: 1px;
    transition: color var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out);
  }

  .mc-send--active {
    color: var(--cnp-accent);
  }

  .mc-send--active:hover {
    background: color-mix(in oklch, var(--cnp-accent) 10%, transparent);
  }

  .mc-send:disabled {
    cursor: not-allowed;
    opacity: 0.35;
  }
</style>
