/**
 * Unit tests for the inline markdown renderer.
 * Covers: HTML escaping, headings, bold, italic, inline code,
 * fenced code blocks, unordered lists, ordered lists, links, blank lines,
 * and fallback to raw text for unsupported constructs.
 */
import { describe, expect, it } from 'vitest';

import { escapeHtml, renderMarkdown, sanitizeHref } from '../markdown.js';

// ── sanitizeHref — scheme allowlist ─────────────────────────────────────────

describe('sanitizeHref()', () => {
  it('allows https: URLs', () => {
    expect(sanitizeHref('https://example.com')).toBe('https://example.com');
  });

  it('allows http: URLs', () => {
    expect(sanitizeHref('http://example.com')).toBe('http://example.com');
  });

  it('allows mailto: URLs', () => {
    expect(sanitizeHref('mailto:x@y.com')).toBe('mailto:x@y.com');
  });

  it('allows relative URLs (no scheme)', () => {
    expect(sanitizeHref('/relative/path')).toBe('/relative/path');
  });

  it('blocks javascript: scheme', () => {
    expect(sanitizeHref('javascript:alert(1)')).toBeNull();
  });

  it('blocks data: scheme', () => {
    expect(sanitizeHref('data:text/html,<script>alert(1)</script>')).toBeNull();
  });

  it('blocks file: scheme', () => {
    expect(sanitizeHref('file:///etc/passwd')).toBeNull();
  });

  it('blocks javascript: with unicode escape (\\u003a)', () => {
    // The raw string contains a literal colon — unicode escape is a JS string concern,
    // but we verify the pattern-based detection handles tricky inputs.
    expect(sanitizeHref('javascript\u003aalert(1)')).toBeNull();
  });

  it('blocks JAVASCRIPT: (case-insensitive)', () => {
    expect(sanitizeHref('  JAVASCRIPT:evil()  ')).toBeNull();
  });
});

// ── renderMarkdown — link scheme filtering ───────────────────────────────────

describe('renderMarkdown() — link scheme allowlist', () => {
  it('blocks javascript: href — renders literal text span, not anchor', () => {
    const html = renderMarkdown('[click](javascript:alert(1))');
    expect(html).not.toContain('<a ');
    expect(html).toContain('fv-unsafe-link');
    expect(html).toContain('javascript');
  });

  it('allows mailto: href', () => {
    const html = renderMarkdown('[mail](mailto:x@y.com)');
    expect(html).toContain('href="mailto:x@y.com"');
    expect(html).toContain('fv-link');
  });

  it('allows https: href', () => {
    const html = renderMarkdown('[link](https://example.com)');
    expect(html).toContain('href="https://example.com"');
    expect(html).toContain('fv-link');
  });

  it('allows relative href (no scheme)', () => {
    const html = renderMarkdown('[link](/relative/path)');
    expect(html).toContain('href="/relative/path"');
    expect(html).toContain('fv-link');
  });

  it('blocks data: href', () => {
    const html = renderMarkdown('[link](data:text/html,<script>)');
    expect(html).not.toContain('<a ');
    expect(html).toContain('fv-unsafe-link');
  });

  it('blocks file: href', () => {
    const html = renderMarkdown('[link](file:///etc/passwd)');
    expect(html).not.toContain('<a ');
    expect(html).toContain('fv-unsafe-link');
  });

  it('blocks javascript: with unicode colon escape in source string', () => {
    // \u003a is ':', so this is "javascript:evil()" at the string level
    const html = renderMarkdown('[link](javascript\u003aevil())');
    expect(html).not.toContain('<a ');
    expect(html).toContain('fv-unsafe-link');
  });

  it('blocks JAVASCRIPT: case-insensitive with surrounding whitespace', () => {
    const html = renderMarkdown('[link](  JAVASCRIPT:evil()  )');
    expect(html).not.toContain('<a ');
    expect(html).toContain('fv-unsafe-link');
  });
});

// ── escapeHtml ──────────────────────────────────────────────────────────────

describe('escapeHtml()', () => {
  it('escapes ampersands', () => {
    expect(escapeHtml('A & B')).toBe('A &amp; B');
  });

  it('escapes less-than', () => {
    expect(escapeHtml('<script>')).toBe('&lt;script&gt;');
  });

  it('escapes double quotes', () => {
    expect(escapeHtml('"hi"')).toBe('&quot;hi&quot;');
  });

  it('escapes single quotes', () => {
    expect(escapeHtml("it's")).toBe('it&#39;s');
  });

  it('leaves safe text unchanged', () => {
    expect(escapeHtml('Hello world 123')).toBe('Hello world 123');
  });
});

// ── renderMarkdown ──────────────────────────────────────────────────────────

describe('renderMarkdown()', () => {
  // Headings
  it('renders h1', () => {
    expect(renderMarkdown('# Title')).toContain('<h1 class="fv-h1">Title</h1>');
  });

  it('renders h2', () => {
    expect(renderMarkdown('## Section')).toContain('<h2 class="fv-h2">Section</h2>');
  });

  it('renders h3', () => {
    expect(renderMarkdown('### Sub')).toContain('<h3 class="fv-h3">Sub</h3>');
  });

  // Bold / italic
  it('renders bold inside a paragraph', () => {
    const html = renderMarkdown('This is **bold** text');
    expect(html).toContain('<strong>bold</strong>');
  });

  it('renders italic inside a paragraph', () => {
    const html = renderMarkdown('This is *italic* text');
    expect(html).toContain('<em>italic</em>');
  });

  // Inline code
  it('renders inline code', () => {
    const html = renderMarkdown('Use `npm install`');
    expect(html).toContain('<code class="fv-inline-code">npm install</code>');
  });

  // Links
  it('renders links with target=_blank', () => {
    const html = renderMarkdown('[Canopy](https://canopy.ai)');
    expect(html).toContain('href="https://canopy.ai"');
    expect(html).toContain('target="_blank"');
    expect(html).toContain('class="fv-link"');
    expect(html).toContain('>Canopy</a>');
  });

  // Fenced code blocks
  it('renders fenced code blocks', () => {
    const md = '```ts\nconst x = 1;\n```';
    const html = renderMarkdown(md);
    expect(html).toContain('<pre class="fv-code-block">');
    expect(html).toContain('data-lang="ts"');
    expect(html).toContain('const x = 1;');
  });

  it('renders fenced code blocks without a lang tag', () => {
    const md = '```\nplain code\n```';
    const html = renderMarkdown(md);
    expect(html).toContain('<code>');
    expect(html).toContain('plain code');
  });

  // Unordered list
  it('renders unordered lists', () => {
    const md = '- Alpha\n- Beta\n- Gamma';
    const html = renderMarkdown(md);
    expect(html).toContain('<ul class="fv-ul">');
    expect(html).toContain('<li>Alpha</li>');
    expect(html).toContain('<li>Beta</li>');
    expect(html).toContain('<li>Gamma</li>');
  });

  // Ordered list
  it('renders ordered lists', () => {
    const md = '1. First\n2. Second\n3. Third';
    const html = renderMarkdown(md);
    expect(html).toContain('<ol class="fv-ol">');
    expect(html).toContain('<li>First</li>');
    expect(html).toContain('<li>Second</li>');
    expect(html).toContain('<li>Third</li>');
  });

  // Blank lines → br
  it('renders blank lines as <br>', () => {
    const html = renderMarkdown('line one\n\nline two');
    expect(html).toContain('<br>');
  });

  // HTML escaping inside headings
  it('escapes HTML in headings', () => {
    const html = renderMarkdown('# <script>alert(1)</script>');
    expect(html).not.toContain('<script>');
    expect(html).toContain('&lt;script&gt;');
  });

  // HTML escaping in code blocks
  it('escapes HTML in fenced code blocks', () => {
    const md = '```\n<img src=x onerror=alert(1)>\n```';
    const html = renderMarkdown(md);
    expect(html).not.toContain('<img');
    expect(html).toContain('&lt;img');
  });

  // Unsupported construct: render as paragraph (no crash)
  it('renders unsupported constructs as paragraph text', () => {
    const html = renderMarkdown('> This is a blockquote');
    // Should not throw; should contain raw-ish text wrapped in a paragraph
    expect(html).toContain('This is a blockquote');
  });

  // Empty input
  it('handles empty string', () => {
    expect(renderMarkdown('')).toBe('');
  });

  // Inline bold inside heading
  it('applies inline rendering inside headings', () => {
    const html = renderMarkdown('## Hello **world**');
    expect(html).toContain('<strong>world</strong>');
  });
});
