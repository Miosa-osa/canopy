# NOTICE

Canopy v2 Third-Party Acknowledgments

Canopy (desktop) — © 2026 Roberto H. Luna / MIOSA. Licensed under Apache 2.0.

## Third-Party Code Acknowledgments

Canopy incorporates patterns and interface designs adapted from the following
open-source projects. All usage complies with each project's license terms.

### Paperclip — MIT License

- Source: https://github.com/paperclipai/paperclip
- License: MIT (https://github.com/paperclipai/paperclip/blob/main/LICENSE)
- Copyright: © 2025 Paperclip AI
- Adapted components:
  - `ServerAdapterModule` interface design → `Canopy.Runtimes.Adapter` behaviour
  - Mutable dual registry with hot-swap pause/resume pattern
  - Session resume triple-key design (`sessionId` + `cwd` + `promptBundleKey`)
  - Content-addressed prompt bundles (SHA256)
  - Wake context environment variable injection pattern
  - `TranscriptEntry` discriminated union structure
  - Declarative `getConfigSchema()` credential form pattern
  - `testEnvironment()` preflight contract with info/warn/error levels

Per MIT license, this attribution is sufficient. No sublicense or source
distribution of Paperclip code is required.

### Cabinet — License pending verification on lift

- Source: https://github.com/hilash/cabinet
- Design patterns referenced (OKLCh tokens, color-mix terminal palette,
  composer card shape, epilogue block convention) are non-copyrightable
  interface designs re-implemented from analysis, not copied code.

### Core-OSS — License pending verification on lift

- Source: https://github.com/10xapp/core-oss
- Design patterns referenced (inset shell, module route architecture,
  push panel shape) are non-copyrightable interface designs re-implemented
  from analysis, not copied code.

### Multica — License pending verification on lift

- Source: https://github.com/multica-ai/multica
- Design patterns referenced (`ActorAvatar` component shape, WS-as-invalidation
  pattern) are non-copyrightable interface designs re-implemented from
  analysis, not copied code.

### SuperHQ — License pending verification on lift

- Source: https://github.com/superhq-ai/superhq
- Patterns referenced (JSONL event bus design, lazy diff-on-expand) are
  conceptual and re-implemented, not copied code.

---

ACTION: When the other projects' LICENSE files are verified on first lift,
move them from "pending verification" to a confirmed section.
