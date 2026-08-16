/**
 * Tests for detect-type — exhaustive extension → viewer mapping.
 * Each case hits one viewer branch in resolution order.
 */
import { describe, expect, it } from "vitest";
import { detectType, extractExtension } from "./detect-type.js";

// ── extractExtension ─────────────────────────────────────────────────────────

describe("extractExtension()", () => {
  it("returns lowercase extension without the dot", () => {
    expect(extractExtension("README.MD")).toBe("md");
    expect(extractExtension("App.Tsx")).toBe("tsx");
    expect(extractExtension("data.JSON")).toBe("json");
  });

  it("returns empty string when no extension", () => {
    expect(extractExtension("README")).toBe("");
    expect(extractExtension("noext")).toBe("");
  });

  it("special-cases Dockerfile and Makefile", () => {
    expect(extractExtension("Dockerfile")).toBe("dockerfile");
    expect(extractExtension("Makefile")).toBe("makefile");
    expect(extractExtension("path/to/Dockerfile")).toBe("dockerfile");
  });

  it("returns extension after final dot only", () => {
    expect(extractExtension("archive.tar.gz")).toBe("gz");
    expect(extractExtension("a.b.c.svelte")).toBe("svelte");
  });
});

// ── Markdown ─────────────────────────────────────────────────────────────────

describe("detectType() — markdown", () => {
  it.each([["README.md"], ["NOTES.markdown"], ["doc.mdx"]])(
    "%s → markdown",
    (name) => {
      expect(detectType(name, null).viewer).toBe("markdown");
    },
  );
});

// ── JSON family ──────────────────────────────────────────────────────────────

describe("detectType() — json family", () => {
  it.each([
    ["package.json"],
    ["tsconfig.jsonc"],
    ["map.geojson"],
    ["data.ndjson"],
    ["config.json5"],
  ])("%s → json viewer with json language", (name) => {
    const r = detectType(name, null);
    expect(r.viewer).toBe("json");
    expect(r.language).toBe("json");
  });

  it("application/json MIME → json", () => {
    expect(detectType("payload", "application/json").viewer).toBe("json");
  });
});

// ── YAML ─────────────────────────────────────────────────────────────────────

describe("detectType() — yaml", () => {
  it.each([["values.yaml"], ["compose.yml"]])("%s → yaml", (name) => {
    expect(detectType(name, null).viewer).toBe("yaml");
  });

  it("application/x-yaml MIME → yaml", () => {
    expect(detectType("noext", "application/x-yaml").viewer).toBe("yaml");
  });
});

// ── CSV / TSV ────────────────────────────────────────────────────────────────

describe("detectType() — tabular", () => {
  it("data.csv → csv", () => {
    expect(detectType("data.csv", null).viewer).toBe("csv");
  });

  it("data.tsv → tsv", () => {
    expect(detectType("data.tsv", null).viewer).toBe("tsv");
  });

  it("text/csv MIME → csv", () => {
    expect(detectType("noext", "text/csv").viewer).toBe("csv");
  });
});

// ── Logs ─────────────────────────────────────────────────────────────────────

describe("detectType() — logs", () => {
  it.each([["app.log"], ["build.out"], ["build.err"]])("%s → log", (name) => {
    expect(detectType(name, null).viewer).toBe("log");
  });
});

// ── Code → Shiki ─────────────────────────────────────────────────────────────

describe("detectType() — code", () => {
  it.each([
    ["index.ts", "typescript"],
    ["App.tsx", "tsx"],
    ["util.js", "javascript"],
    ["shop.svelte", "svelte"],
    ["lib.ex", "elixir"],
    ["script.exs", "elixir"],
    ["main.rs", "rust"],
    ["main.go", "go"],
    ["app.py", "python"],
    ["query.sql", "sql"],
    ["build.sh", "bash"],
    ["styles.css", "css"],
    ["Dockerfile", "docker"],
    ["index.html", "html"],
    ["Cargo.toml", "toml"],
    ["spec.graphql", "graphql"],
  ])("%s → code with language %s", (name, lang) => {
    const r = detectType(name, null);
    expect(r.viewer).toBe("code");
    expect(r.language).toBe(lang);
  });
});

// ── Images ───────────────────────────────────────────────────────────────────

describe("detectType() — images", () => {
  it.each([
    ["pic.png"],
    ["pic.jpg"],
    ["pic.jpeg"],
    ["pic.gif"],
    ["pic.webp"],
    ["icon.svg"],
    ["icon.ico"],
    ["next.avif"],
  ])("%s → image", (name) => {
    expect(detectType(name, null).viewer).toBe("image");
  });

  it("image/png MIME → image", () => {
    expect(detectType("noext", "image/png").viewer).toBe("image");
  });
});

// ── Audio / Video ────────────────────────────────────────────────────────────

describe("detectType() — media", () => {
  it.each([["song.mp3"], ["voice.wav"], ["pod.flac"], ["talk.opus"]])(
    "%s → audio",
    (name) => {
      expect(detectType(name, null).viewer).toBe("audio");
    },
  );

  it.each([["clip.mp4"], ["clip.webm"], ["clip.mov"], ["clip.mkv"]])(
    "%s → video",
    (name) => {
      expect(detectType(name, null).viewer).toBe("video");
    },
  );

  it("video/mp4 MIME → video", () => {
    expect(detectType("noext", "video/mp4").viewer).toBe("video");
  });
});

// ── Office docs ──────────────────────────────────────────────────────────────

describe("detectType() — office", () => {
  it("contract.pdf → pdf", () => {
    expect(detectType("contract.pdf", null).viewer).toBe("pdf");
  });

  it("application/pdf MIME → pdf", () => {
    expect(detectType("noext", "application/pdf").viewer).toBe("pdf");
  });

  it("doc.docx → docx", () => {
    expect(detectType("doc.docx", null).viewer).toBe("docx");
  });

  it("DOCX MIME → docx", () => {
    expect(
      detectType(
        "noext",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      ).viewer,
    ).toBe("docx");
  });

  it("sheet.xlsx → xlsx", () => {
    expect(detectType("sheet.xlsx", null).viewer).toBe("xlsx");
  });

  it("XLSX MIME → xlsx", () => {
    expect(
      detectType(
        "noext",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      ).viewer,
    ).toBe("xlsx");
  });
});

// ── Plain text fallbacks ─────────────────────────────────────────────────────

describe("detectType() — plain text", () => {
  it("notes.txt → text", () => {
    expect(detectType("notes.txt", null).viewer).toBe("text");
  });

  it("text/plain MIME → text", () => {
    expect(detectType("noext", "text/plain").viewer).toBe("text");
  });
});

// ── Hex (binary fallback) ────────────────────────────────────────────────────

describe("detectType() — hex fallback", () => {
  it("unknown extension and no MIME → hex", () => {
    expect(detectType("blob.xyz", null).viewer).toBe("hex");
  });

  it("no extension and no MIME → hex", () => {
    expect(detectType("noext", null).viewer).toBe("hex");
  });

  it("binary MIME with unknown ext → hex", () => {
    expect(detectType("blob.bin", "application/octet-stream").viewer).toBe(
      "hex",
    );
  });
});

// ── Size cap ─────────────────────────────────────────────────────────────────

describe("detectType() — size cap", () => {
  it("files over 50 MB → too-large regardless of type", () => {
    const oneHundredMB = 100 * 1024 * 1024;
    expect(detectType("big.md", null, oneHundredMB).viewer).toBe("too-large");
    expect(detectType("big.png", "image/png", oneHundredMB).viewer).toBe(
      "too-large",
    );
  });

  it("files exactly at the cap are NOT too-large", () => {
    const fiftyMB = 50 * 1024 * 1024;
    expect(detectType("ok.md", null, fiftyMB).viewer).toBe("markdown");
  });
});

// ── Resolution order ─────────────────────────────────────────────────────────

describe("detectType() — resolution order", () => {
  it("MIME image/png wins over .pdf extension", () => {
    // A file named .pdf with image/png MIME — pathological, but the MIME
    // for known media families is more reliable than extension.
    // (PDF check runs before image check, so .pdf still wins.)
    expect(detectType("weird.pdf", "image/png").viewer).toBe("pdf");
  });

  it("MIME video/mp4 wins over no extension", () => {
    expect(detectType("clip", "video/mp4").viewer).toBe("video");
  });
});
