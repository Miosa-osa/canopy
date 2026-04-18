/**
 * Unit tests for the inline markdown renderer.
 * Covers: HTML escaping, headings, bold, italic, inline code,
 * fenced code blocks, unordered lists, ordered lists, links, blank lines,
 * and fallback to raw text for unsupported constructs.
 */
import { describe, expect, it } from "vitest";

import { escapeHtml, renderMarkdown } from "../markdown.js";

// ── escapeHtml ──────────────────────────────────────────────────────────────

describe("escapeHtml()", () => {
  it("escapes ampersands", () => {
    expect(escapeHtml("A & B")).toBe("A &amp; B");
  });

  it("escapes less-than", () => {
    expect(escapeHtml("<script>")).toBe("&lt;script&gt;");
  });

  it("escapes double quotes", () => {
    expect(escapeHtml('"hi"')).toBe("&quot;hi&quot;");
  });

  it("escapes single quotes", () => {
    expect(escapeHtml("it's")).toBe("it&#39;s");
  });

  it("leaves safe text unchanged", () => {
    expect(escapeHtml("Hello world 123")).toBe("Hello world 123");
  });
});

// ── renderMarkdown ──────────────────────────────────────────────────────────

describe("renderMarkdown()", () => {
  // Headings
  it("renders h1", () => {
    expect(renderMarkdown("# Title")).toContain('<h1 class="fv-h1">Title</h1>');
  });

  it("renders h2", () => {
    expect(renderMarkdown("## Section")).toContain(
      '<h2 class="fv-h2">Section</h2>',
    );
  });

  it("renders h3", () => {
    expect(renderMarkdown("### Sub")).toContain('<h3 class="fv-h3">Sub</h3>');
  });

  // Bold / italic
  it("renders bold inside a paragraph", () => {
    const html = renderMarkdown("This is **bold** text");
    expect(html).toContain("<strong>bold</strong>");
  });

  it("renders italic inside a paragraph", () => {
    const html = renderMarkdown("This is *italic* text");
    expect(html).toContain("<em>italic</em>");
  });

  // Inline code
  it("renders inline code", () => {
    const html = renderMarkdown("Use `npm install`");
    expect(html).toContain('<code class="fv-inline-code">npm install</code>');
  });

  // Links
  it("renders links with target=_blank", () => {
    const html = renderMarkdown("[Canopy](https://canopy.ai)");
    expect(html).toContain('href="https://canopy.ai"');
    expect(html).toContain('target="_blank"');
    expect(html).toContain('class="fv-link"');
    expect(html).toContain(">Canopy</a>");
  });

  // Fenced code blocks
  it("renders fenced code blocks", () => {
    const md = "```ts\nconst x = 1;\n```";
    const html = renderMarkdown(md);
    expect(html).toContain('<pre class="fv-code-block">');
    expect(html).toContain('data-lang="ts"');
    expect(html).toContain("const x = 1;");
  });

  it("renders fenced code blocks without a lang tag", () => {
    const md = "```\nplain code\n```";
    const html = renderMarkdown(md);
    expect(html).toContain("<code>");
    expect(html).toContain("plain code");
  });

  // Unordered list
  it("renders unordered lists", () => {
    const md = "- Alpha\n- Beta\n- Gamma";
    const html = renderMarkdown(md);
    expect(html).toContain('<ul class="fv-ul">');
    expect(html).toContain("<li>Alpha</li>");
    expect(html).toContain("<li>Beta</li>");
    expect(html).toContain("<li>Gamma</li>");
  });

  // Ordered list
  it("renders ordered lists", () => {
    const md = "1. First\n2. Second\n3. Third";
    const html = renderMarkdown(md);
    expect(html).toContain('<ol class="fv-ol">');
    expect(html).toContain("<li>First</li>");
    expect(html).toContain("<li>Second</li>");
    expect(html).toContain("<li>Third</li>");
  });

  // Blank lines → br
  it("renders blank lines as <br>", () => {
    const html = renderMarkdown("line one\n\nline two");
    expect(html).toContain("<br>");
  });

  // HTML escaping inside headings
  it("escapes HTML in headings", () => {
    const html = renderMarkdown("# <script>alert(1)</script>");
    expect(html).not.toContain("<script>");
    expect(html).toContain("&lt;script&gt;");
  });

  // HTML escaping in code blocks
  it("escapes HTML in fenced code blocks", () => {
    const md = "```\n<img src=x onerror=alert(1)>\n```";
    const html = renderMarkdown(md);
    expect(html).not.toContain("<img");
    expect(html).toContain("&lt;img");
  });

  // Unsupported construct: render as paragraph (no crash)
  it("renders unsupported constructs as paragraph text", () => {
    const html = renderMarkdown("> This is a blockquote");
    // Should not throw; should contain raw-ish text wrapped in a paragraph
    expect(html).toContain("This is a blockquote");
  });

  // Empty input
  it("handles empty string", () => {
    expect(renderMarkdown("")).toBe("");
  });

  // Inline bold inside heading
  it("applies inline rendering inside headings", () => {
    const html = renderMarkdown("## Hello **world**");
    expect(html).toContain("<strong>world</strong>");
  });
});
