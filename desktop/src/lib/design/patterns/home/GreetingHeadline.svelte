<script lang="ts">
import { onMount, onDestroy } from 'svelte';
import { profile } from '$lib/stores/profile.svelte.js';

const userName = $derived(profile.displayName || 'you');

const GREETINGS: ((name: string) => string)[] = [
  (n) => { const h = new Date().getHours(); return h < 12 ? `Good morning, ${n}.` : h < 17 ? `Good afternoon, ${n}.` : `Good evening, ${n}.`; },
  (n) => `Look who's back, ${n}.`,
  (n) => `${n} is back for more.`,
  (n) => `Welcome back, ${n}.`,
  (n) => `Ready when you are, ${n}.`,
  (n) => `Let's get to work, ${n}.`,
  (n) => `The terminal awaits, ${n}.`,
  (n) => `Back at it, ${n}.`,
  (n) => `${n}. Let's ship something.`,
  (n) => `Another day, another deploy, ${n}.`,
  (n) => `${n} has entered the building.`,
  (n) => `Missed you, ${n}. Just kidding. Let's build.`,
  (n) => `Alright ${n}, what's the move?`,
  (n) => `${n}'s in the zone.`,
  (n) => `Hey ${n}. I've been thinking...`,
];

const SPARKS = [
  "I was just looking at your recent sessions — want to pick up where you left off?",
  "You've got 3 agents idle right now. Want to put them to work?",
  "What if we automated that thing you keep doing manually?",
  "I noticed some failing tests in your last session. Want me to take a look?",
  "Your codebase has grown 12% this week. Need a refactor pass?",
  "Got a wild idea? Type it out — worst case we learn something.",
  "Want me to review what changed since yesterday?",
  "I can run your test suite in the background while you think.",
  "Any fires to put out, or are we building something new?",
  "Ship something small today. Momentum compounds.",
  "What's the one thing that would make tomorrow easier?",
  "I'm warmed up and ready. What's first?",
  "Sketch it out in words — I'll turn it into code.",
  "Want to pair on something? I'll drive.",
  "Tell me about the ugliest part of your codebase. Let's fix it.",
  "What would you build if you had zero meetings today?",
  "Describe your ideal outcome for today in one sentence.",
  "I just checked — your deploy pipeline is green. Time to push something.",
  "Want to explore a new architecture? I'll prototype it.",
  "Let's make something you'll be proud of.",
];

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function pickWithout<T>(arr: T[], exclude: T): T {
  const filtered = arr.filter((x) => x !== exclude);
  return filtered.length > 0 ? pick(filtered) : pick(arr);
}

// ── Greeting typewriter ──────────────────────────────────────────────────────
const initialGreeting = pick(GREETINGS)(userName);
let displayed = $state('');
let showCursor = $state(true);
let doneTyping = $state(false);

// ── Rotating spark subtitle ──────────────────────────────────────────────────
let currentSpark = $state(pick(SPARKS));
let sparkVisible = $state(false);
let sparkInterval: ReturnType<typeof setInterval> | null = null;
const SPARK_ROTATE_MS = 8000;

onMount(() => {
  const text = initialGreeting;
  let i = 0;

  const typeInterval = setInterval(() => {
    i++;
    displayed = text.slice(0, i);
    if (i >= text.length) {
      clearInterval(typeInterval);
      doneTyping = true;
      setTimeout(() => { showCursor = false; }, 600);
      setTimeout(() => { sparkVisible = true; }, 300);

      sparkInterval = setInterval(() => {
        sparkVisible = false;
        setTimeout(() => {
          currentSpark = pickWithout(SPARKS, currentSpark);
          sparkVisible = true;
        }, 400);
      }, SPARK_ROTATE_MS);
    }
  }, 38);

  return () => {
    clearInterval(typeInterval);
    if (sparkInterval) clearInterval(sparkInterval);
  };
});

onDestroy(() => {
  if (sparkInterval) clearInterval(sparkInterval);
});
</script>

<div class="gh-root" aria-label="Greeting">
  <h1 class="gh-headline">
    {displayed}<span class="gh-cursor" class:gh-cursor--hidden={!showCursor}>|</span>
  </h1>
  <p class="gh-spark" class:gh-spark--visible={sparkVisible}>
    {currentSpark}
  </p>
</div>

<style>
  .gh-root {
    display: flex;
    flex-direction: column;
    gap: 12px;
    text-align: center;
    padding-top: 32px;
  }

  .gh-headline {
    font-family: var(--font-sans);
    font-size: 2rem;
    font-weight: 700;
    color: var(--fg);
    margin: 0;
    line-height: 1.15;
    letter-spacing: -0.02em;
    min-height: 2.4em;
  }

  .gh-cursor {
    color: var(--cnp-accent, #6366f1);
    font-weight: 400;
    animation: gh-blink 0.7s step-end infinite;
  }

  .gh-cursor--hidden {
    opacity: 0;
    animation: none;
  }

  @keyframes gh-blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0; }
  }

  .gh-spark {
    font-family: var(--font-sans);
    font-size: 0.92rem;
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.5;
    max-width: 480px;
    margin-inline: auto;
    opacity: 0;
    transform: translateY(6px);
    transition: opacity 400ms ease-out, transform 400ms ease-out;
    font-style: italic;
  }

  .gh-spark--visible {
    opacity: 1;
    transform: translateY(0);
  }
</style>
