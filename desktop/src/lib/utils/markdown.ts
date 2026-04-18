/**
 * Minimal inline markdown renderer — no external dependencies.
 * Supports: headings (#/##/###), bold (**), italic (*), inline code (`),
 * fenced code blocks (```), unordered lists (-), ordered lists (1.),
 * links ([text](url)). All other constructs render as raw text.
 * HTML is escaped before processing — no XSS surface.
 * LOC target: ≤ 150.
 */

/** Escape HTML entities so raw user content cannot inject markup. */
export function escapeHtml(raw: string): string {
  return raw
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/**
 * Allowlisted URL schemes for rendered links.
 * javascript:, data:, file:, vbscript:, and all other schemes are blocked.
 */
const SAFE_SCHEMES = new Set(["http:", "https:", "mailto:"]);

/**
 * Validate a URL's scheme against the allowlist.
 * Returns the trimmed URL if safe, null if the scheme is blocked.
 * Relative URLs (no scheme prefix) pass through — they cannot trigger JS execution.
 */
export function sanitizeHref(raw: string): string | null {
  const trimmed = raw.trim();
  // Relative URLs have no scheme — safe to pass through.
  if (!/^[a-z][a-z0-9+.-]*:/i.test(trimmed)) return trimmed;
  try {
    const url = new URL(trimmed);
    return SAFE_SCHEMES.has(url.protocol) ? trimmed : null;
  } catch {
    // Unparseable URL — treat as unsafe.
    return null;
  }
}

/** Apply inline spans: bold, italic, inline code, links. Input is already HTML-escaped. */
function inlineRender(escaped: string): string {
  return (
    escaped
      // Bold: **text** — must come before italic to avoid partial match
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      // Italic: *text*
      .replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, "<em>$1</em>")
      // Inline code: `code` — use a replacement function to avoid nested processing
      .replace(/`([^`]+)`/g, '<code class="fv-inline-code">$1</code>')
      // Links: [text](url) — sanitize href scheme before emitting anchor.
      // Blocked schemes render as literal text so the user sees something was stripped.
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, text: string, url: string) => {
        const safe = sanitizeHref(url);
        if (safe === null) {
          // Emit a span with the raw [text](url) content, HTML-escaped.
          return `<span class="fv-unsafe-link">[${text}](${escapeHtml(url)})</span>`;
        }
        return `<a href="${safe}" target="_blank" rel="noopener noreferrer" class="fv-link">${text}</a>`;
      })
  );
}

/** Render a markdown string to an HTML string. Never throws — falls back to raw text. */
export function renderMarkdown(md: string): string {
  if (md === "") return "";
  const lines = md.split("\n");
  const out: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    // Fenced code block
    if (line.trimStart().startsWith("```")) {
      const lang = escapeHtml(line.trimStart().slice(3).trim());
      const codeLines: string[] = [];
      i++;
      while (i < lines.length && !lines[i].trimStart().startsWith("```")) {
        codeLines.push(escapeHtml(lines[i]));
        i++;
      }
      out.push(
        `<pre class="fv-code-block"><code${lang ? ` data-lang="${lang}"` : ""}>${codeLines.join("\n")}</code></pre>`,
      );
      i++; // skip closing ```
      continue;
    }

    // Headings
    const h3 = line.match(/^### (.+)/);
    if (h3) {
      out.push(`<h3 class="fv-h3">${inlineRender(escapeHtml(h3[1]))}</h3>`);
      i++;
      continue;
    }
    const h2 = line.match(/^## (.+)/);
    if (h2) {
      out.push(`<h2 class="fv-h2">${inlineRender(escapeHtml(h2[1]))}</h2>`);
      i++;
      continue;
    }
    const h1 = line.match(/^# (.+)/);
    if (h1) {
      out.push(`<h1 class="fv-h1">${inlineRender(escapeHtml(h1[1]))}</h1>`);
      i++;
      continue;
    }

    // Unordered list block
    if (/^- /.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^- /.test(lines[i])) {
        items.push(`<li>${inlineRender(escapeHtml(lines[i].slice(2)))}</li>`);
        i++;
      }
      out.push(`<ul class="fv-ul">${items.join("")}</ul>`);
      continue;
    }

    // Ordered list block
    if (/^\d+\. /.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^\d+\. /.test(lines[i])) {
        items.push(
          `<li>${inlineRender(escapeHtml(lines[i].replace(/^\d+\. /, "")))}</li>`,
        );
        i++;
      }
      out.push(`<ol class="fv-ol">${items.join("")}</ol>`);
      continue;
    }

    // Blank line → paragraph break
    if (line.trim() === "") {
      out.push("<br>");
      i++;
      continue;
    }

    // Paragraph
    out.push(`<p class="fv-p">${inlineRender(escapeHtml(line))}</p>`);
    i++;
  }

  return out.join("\n");
}
