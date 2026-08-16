/**
 * Terminal Harness store — per-session transcript buffer + observer state.
 *
 * Design:
 *  - Holds a per-session ring buffer (last 2000 output chunks).
 *  - Transcript is fed via onOutput callback prop exposed from TerminalSession,
 *    OR by the Harness opening a second subscription to the same Phoenix channel.
 *  - Observer pane: sends buffer to OpenAI/Anthropic endpoint with user's stored key.
 *
 * CSS prefix: th- (TerminalHarness)
 * LOC target: ≤ 140.
 */

const MAX_LINES = 2_000;
const WS_URL = `ws://localhost:9190/socket/websocket?vsn=2.0.0`;

export type ObserverStatus =
  | "idle"
  | "loading"
  | "streaming"
  | "done"
  | "error";

export interface ObserverMessage {
  role: "assistant";
  content: string;
}

class HarnessStore {
  // Transcript ring buffer — raw terminal output chunks.
  private _buffer = $state<string[]>([]);
  // WebSocket used for transcript capture (second subscriber).
  private _ws: WebSocket | null = null;
  private _sessionId: string | null = null;

  // Observer pane state.
  observerStatus = $state<ObserverStatus>("idle");
  observerMessages = $state<ObserverMessage[]>([]);
  observerError = $state<string | null>(null);

  /** Start capturing output for a session by opening a parallel channel sub. */
  startCapture(sessionId: string): () => void {
    if (this._sessionId === sessionId && this._ws)
      return () => {
        /* already running */
      };

    this.stopCapture();
    this._sessionId = sessionId;
    this._buffer = [];

    const TOPIC = `terminal:session:${sessionId}`;
    let refCounter = 0;
    const nextRef = () => String(++refCounter);

    const ws = new WebSocket(WS_URL);
    this._ws = ws;

    ws.onopen = () => {
      // Send heartbeat then join.
      ws.send(JSON.stringify([null, nextRef(), "phoenix", "heartbeat", {}]));
      const joinRef = nextRef();
      ws.send(JSON.stringify([joinRef, nextRef(), TOPIC, "phx_join", {}]));
    };

    ws.onmessage = (ev: MessageEvent<string>) => {
      let frame: [string | null, string | null, string, string, unknown];
      try {
        frame = JSON.parse(ev.data) as typeof frame;
      } catch {
        return;
      }
      const [, , topic, event, payload] = frame;
      if (topic !== TOPIC || event !== "output") return;
      const out = payload as { data?: string };
      if (!out.data) return;
      this._buffer =
        this._buffer.length >= MAX_LINES
          ? [...this._buffer.slice(1), out.data]
          : [...this._buffer, out.data];
    };

    return () => this.stopCapture();
  }

  /** Feed output directly (from onOutput prop if available). */
  feedChunk(chunk: string): void {
    this._buffer =
      this._buffer.length >= MAX_LINES
        ? [...this._buffer.slice(1), chunk]
        : [...this._buffer, chunk];
  }

  stopCapture(): void {
    if (this._ws) {
      try {
        this._ws.close();
      } catch {
        /* ignore */
      }
      this._ws = null;
    }
    this._sessionId = null;
  }

  get transcript(): string {
    return this._buffer.join("");
  }

  get transcriptText(): string {
    // Strip ANSI escape codes for observer readability.
    // eslint-disable-next-line no-control-regex
    return this.transcript.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "");
  }

  /** Send transcript to OpenAI/Anthropic observer endpoint. */
  async runObserver(
    apiKey: string,
    provider: "openai" | "anthropic" = "anthropic",
  ): Promise<void> {
    const text = this.transcriptText.slice(-12_000); // keep last ~12K chars
    if (!text.trim()) {
      this.observerError = "No transcript to observe yet.";
      this.observerStatus = "error";
      return;
    }

    this.observerStatus = "loading";
    this.observerError = null;
    this.observerMessages = [];

    const systemPrompt =
      "You are a session observer reviewing what a Claude agent is doing in a terminal. " +
      "Flag anything concerning: infinite loops, destructive commands, wrong directory, " +
      "unexpected errors. Be concise. 3-5 bullet points max.";

    try {
      if (provider === "openai") {
        const res = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model: "gpt-4o-mini",
            stream: false,
            messages: [
              { role: "system", content: systemPrompt },
              {
                role: "user",
                content: `Terminal session output:\n\`\`\`\n${text}\n\`\`\``,
              },
            ],
          }),
        });
        if (!res.ok) throw new Error(`OpenAI ${res.status}`);
        const json = (await res.json()) as {
          choices?: Array<{ message?: { content?: string } }>;
        };
        const content = json.choices?.[0]?.message?.content ?? "(no response)";
        this.observerMessages = [{ role: "assistant", content }];
      } else {
        const res = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-haiku-4-5",
            max_tokens: 512,
            system: systemPrompt,
            messages: [
              {
                role: "user",
                content: `Terminal session output:\n\`\`\`\n${text}\n\`\`\``,
              },
            ],
          }),
        });
        if (!res.ok) throw new Error(`Anthropic ${res.status}`);
        const json = (await res.json()) as {
          content?: Array<{ text?: string }>;
        };
        const content = json.content?.[0]?.text ?? "(no response)";
        this.observerMessages = [{ role: "assistant", content }];
      }
      this.observerStatus = "done";
    } catch (err) {
      this.observerError =
        err instanceof Error ? err.message : "Observer failed";
      this.observerStatus = "error";
    }
  }

  reset(): void {
    this.observerStatus = "idle";
    this.observerMessages = [];
    this.observerError = null;
    this._buffer = [];
  }
}

export const harnessStore = new HarnessStore();
