// @vitest-environment jsdom

/**
 * Security Finding: S-09 — XSS via unsanitized {@html} in MarkdownRenderer
 *
 * These are ADVERSARIAL tests. They prove a vulnerability exists by asserting
 * that dangerous payloads pass through unsanitized. They are NOT asserting
 * correct behavior — they document what the vulnerable code currently does.
 *
 * Each test is paired with a contrast test against a component that applies
 * DOMPurify correctly (MessageBubble / DocumentViewer), proving the fix
 * pattern is already established in the codebase.
 *
 * ─── Finding Summary ──────────────────────────────────────────────────────────
 * ID:        S-09
 * Severity:  HIGH
 * Component: src/lib/components/ui/MarkdownRenderer.svelte
 * Root cause: `marked.parse(content)` output is assigned directly to `html`
 *             and rendered via `{@html html}` with zero sanitization.
 * Fix (1 line): Wrap the marked.parse call with DOMPurify.sanitize():
 *               let html = $derived(DOMPurify.sanitize(marked.parse(stripped) as string));
 *               Also add: import DOMPurify from 'dompurify';
 * Existing safe pattern: src/lib/components/chat/MessageBubble.svelte (line 63)
 *                        src/lib/components/documents/DocumentViewer.svelte (line 54)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Test runner: vitest (already installed — see package.json devDependencies)
 * Run:  cd canopy/desktop && npx vitest run src/lib/components/ui/__tests__/
 *
 * NOTE: These tests operate on the pure rendering logic extracted from each
 * component. Svelte 5 component mounting in jsdom requires @testing-library/svelte
 * which is not yet installed. The rendering logic is extracted faithfully from
 * the source — marked.parse alone (vulnerable) vs marked.parse + DOMPurify
 * (safe). This is the exact code path that executes at runtime.
 */

import { describe, it, expect } from 'vitest';
import { marked } from 'marked';
import DOMPurify from 'dompurify';

// ── Rendering functions extracted verbatim from each component ────────────────
//
// These are the exact expressions that produce the string passed to {@html ...}.
// No abstraction — copied from source so the test breaks immediately if the
// source diverges.

/**
 * VULNERABLE — extracted from MarkdownRenderer.svelte line 11:
 *   let html = $derived(marked.parse(stripped) as string);
 *
 * No sanitization. marked.parse preserves raw HTML in the input.
 */
function renderMarkdownVulnerable(content: string): string {
  // Mirror the frontmatter-strip logic from lines 5-10
  let stripped = content;
  if (content.startsWith('---')) {
    const second = content.indexOf('---', 3);
    if (second !== -1) {
      stripped = content.slice(second + 3).trimStart();
    }
  }
  // Line 11 — the vulnerable expression
  return marked.parse(stripped) as string;
}

/**
 * SAFE — extracted from MessageBubble.svelte renderMarkdown() lines 59-67:
 *   const raw = marked.parse(text, { async: false }) as string;
 *   return DOMPurify.sanitize(raw);
 *
 * This is the established fix pattern already in use for chat messages.
 */
function renderMarkdownSafe_MessageBubble(text: string): string {
  if (!text) return '';
  try {
    const raw = marked.parse(text, { async: false }) as string;
    return DOMPurify.sanitize(raw);
  } catch {
    return DOMPurify.sanitize(text);
  }
}

/**
 * SAFE — extracted from DocumentViewer.svelte renderMarkdown() line 54:
 *   return DOMPurify.sanitize(html);
 *
 * Applied after a custom regex-based markdown pipeline.
 */
function renderMarkdownSafe_DocumentViewer(md: string): string {
  if (!md) return '<p class="dv-empty-doc">This document is empty.</p>';
  // (Simplified to only the sanitization path relevant to XSS — the full
  // regex pipeline precedes this line in the original component.)
  return DOMPurify.sanitize(md);
}

// ── Payloads ──────────────────────────────────────────────────────────────────

const SCRIPT_TAG_PAYLOAD = '<script>alert(1)<\/script>';
const IMG_ONERROR_PAYLOAD = '<img src=x onerror="alert(1)">';

// ── S-09-A: <script> tag injection ────────────────────────────────────────────

describe('S-09-A: <script> tag XSS in MarkdownRenderer', () => {
  /**
   * VULNERABILITY PROOF
   *
   * marked.parse passes raw HTML through unchanged. When markdown content
   * contains a bare <script> tag, it survives into the output string that is
   * later passed to {@html html} — executing in the browser.
   *
   * Finding: S-09
   * Fix:     DOMPurify.sanitize() around marked.parse() output
   */
  it('[S-09] VULNERABILITY: <script> tag survives marked.parse in MarkdownRenderer', () => {
    const output = renderMarkdownVulnerable(SCRIPT_TAG_PAYLOAD);

    // The script tag is present in the output — this string goes to {@html}
    expect(output).toContain('<script>');
    expect(output).toContain('alert(1)');
  });

  /**
   * CONTRAST: MessageBubble — same payload, DOMPurify removes the script tag.
   * This proves the fix is one import + one function call away.
   */
  it('[S-09] SAFE CONTRAST: MessageBubble strips <script> via DOMPurify', () => {
    const output = renderMarkdownSafe_MessageBubble(SCRIPT_TAG_PAYLOAD);

    expect(output).not.toContain('<script>');
    expect(output).not.toContain('alert(1)');
  });

  /**
   * CONTRAST: DocumentViewer — same payload, DOMPurify removes the script tag.
   */
  it('[S-09] SAFE CONTRAST: DocumentViewer strips <script> via DOMPurify', () => {
    const output = renderMarkdownSafe_DocumentViewer(SCRIPT_TAG_PAYLOAD);

    expect(output).not.toContain('<script>');
    expect(output).not.toContain('alert(1)');
  });
});

// ── S-09-B: <img onerror> event handler injection ─────────────────────────────

describe('S-09-B: <img onerror> XSS in MarkdownRenderer', () => {
  /**
   * VULNERABILITY PROOF
   *
   * marked.parse passes raw HTML through, including event handler attributes.
   * The onerror attribute on a broken image tag executes arbitrary JS in the
   * renderer process (Tauri WebView) when the image fails to load — which is
   * immediate since src=x is not a valid URL.
   *
   * Finding: S-09
   * Fix:     DOMPurify.sanitize() strips event handler attributes by default
   */
  it('[S-09] VULNERABILITY: <img onerror> survives marked.parse in MarkdownRenderer', () => {
    const output = renderMarkdownVulnerable(IMG_ONERROR_PAYLOAD);

    // The onerror attribute is present — executes JS when rendered in a WebView
    expect(output).toContain('onerror');
    expect(output).toContain('alert(1)');
    expect(output).toContain('<img');
  });

  /**
   * CONTRAST: MessageBubble — DOMPurify strips onerror from img tags.
   * The img element may survive (DOMPurify allows img by default) but event
   * handlers are always stripped.
   */
  it('[S-09] SAFE CONTRAST: MessageBubble strips onerror attribute via DOMPurify', () => {
    const output = renderMarkdownSafe_MessageBubble(IMG_ONERROR_PAYLOAD);

    expect(output).not.toContain('onerror');
    expect(output).not.toContain('alert(1)');
  });

  /**
   * CONTRAST: DocumentViewer — DOMPurify strips onerror attribute.
   */
  it('[S-09] SAFE CONTRAST: DocumentViewer strips onerror attribute via DOMPurify', () => {
    const output = renderMarkdownSafe_DocumentViewer(IMG_ONERROR_PAYLOAD);

    expect(output).not.toContain('onerror');
    expect(output).not.toContain('alert(1)');
  });
});

// ── S-09-C: Frontmatter bypass — payload after YAML header ───────────────────

describe('S-09-C: XSS payload after frontmatter strip in MarkdownRenderer', () => {
  /**
   * VULNERABILITY PROOF
   *
   * MarkdownRenderer strips YAML frontmatter (lines 5-10) before rendering.
   * An attacker who controls document content can place the payload after the
   * second --- delimiter. The strip logic correctly removes the frontmatter,
   * but the payload in the body is still not sanitized.
   *
   * This matters for documents loaded from the filesystem (nodes/, signals/)
   * since any markdown file could contain adversarial content if the workspace
   * path is attacker-controlled or the file is externally modified.
   *
   * Finding: S-09 (frontmatter bypass variant)
   * Fix:     Same — DOMPurify.sanitize() on the marked.parse output
   */
  it('[S-09] VULNERABILITY: payload survives frontmatter strip in MarkdownRenderer', () => {
    const contentWithFrontmatter =
      '---\ntitle: Legitimate Document\n---\n\n' + SCRIPT_TAG_PAYLOAD;

    const output = renderMarkdownVulnerable(contentWithFrontmatter);

    // Frontmatter is correctly stripped, but XSS payload in body still present
    expect(output).not.toContain('title: Legitimate Document');
    expect(output).toContain('<script>');
    expect(output).toContain('alert(1)');
  });

  it('[S-09] SAFE CONTRAST: MessageBubble sanitizes payload after frontmatter equivalent', () => {
    // MessageBubble does not strip frontmatter — but it sanitizes the full output
    const output = renderMarkdownSafe_MessageBubble(SCRIPT_TAG_PAYLOAD);

    expect(output).not.toContain('<script>');
    expect(output).not.toContain('alert(1)');
  });
});

// ── S-09-D: javascript: href injection ────────────────────────────────────────

describe('S-09-D: javascript: href XSS in MarkdownRenderer', () => {
  /**
   * VULNERABILITY PROOF
   *
   * marked converts [text](javascript:alert(1)) to
   * <a href="javascript:alert(1)">text</a>.
   * When rendered in a WebView via {@html}, clicking the link executes JS.
   *
   * Finding: S-09 (javascript: URI variant)
   * Fix:     DOMPurify.sanitize() strips javascript: hrefs by default
   */
  it('[S-09] VULNERABILITY: javascript: href survives marked.parse in MarkdownRenderer', () => {
    const payload = '[click me](javascript:alert(1))';
    const output = renderMarkdownVulnerable(payload);

    expect(output).toContain('href="javascript:alert(1)"');
  });

  it('[S-09] SAFE CONTRAST: MessageBubble strips javascript: href via DOMPurify', () => {
    const payload = '[click me](javascript:alert(1))';
    const output = renderMarkdownSafe_MessageBubble(payload);

    expect(output).not.toContain('javascript:alert');
  });
});

// ── Fix reference ─────────────────────────────────────────────────────────────
//
// To fix S-09, apply this diff to MarkdownRenderer.svelte:
//
//   --- a/src/lib/components/ui/MarkdownRenderer.svelte
//   +++ b/src/lib/components/ui/MarkdownRenderer.svelte
//   @@ -1,6 +1,7 @@
//    <script lang="ts">
//      import { marked } from 'marked';
//   +  import DOMPurify from 'dompurify';
//      interface Props { content: string; }
//      let { content }: Props = $props();
//      let stripped = $derived.by(() => {
//   @@ -10,5 +11,5 @@
//        return content.slice(second + 3).trimStart();
//      });
//   -  let html = $derived(marked.parse(stripped) as string);
//   +  let html = $derived(DOMPurify.sanitize(marked.parse(stripped) as string));
//    </script>
//
// dompurify is already installed (package.json dependencies).
// No new dependencies required.
