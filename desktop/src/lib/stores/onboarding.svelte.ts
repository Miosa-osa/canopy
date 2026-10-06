import { browser } from "$app/environment";

export interface ProviderConfig {
  slug: string;
  apiKey: string;
  verified: boolean;
}

export interface WorkspaceConfig {
  path: string;
  name: string;
  description: string;
}

export type TeamTemplate = "solo" | "dev-team" | "research" | "custom";

export type AdapterType =
  | "osa"
  | "claude-code"
  | "codex"
  | "openclaw"
  | "jidoclaw"
  | "hermes"
  | "bash"
  | "http";

export interface AgentTemplateData {
  id: string;
  name: string;
  emoji: string;
  role: string;
  adapter: string;
  model?: string;
  skills: string[];
  system_prompt?: string;
}

export interface OnboardingData {
  displayName: string;
  provider: ProviderConfig | null;
  adapter: AdapterType;
  workspace: WorkspaceConfig | null;
  teamTemplate: TeamTemplate | null;
  agents: AgentTemplateData[];
  miosaCloud: boolean;
}

const STORAGE_KEY = "canopy-onboarding";
const TOTAL_STEPS = 4;

const DEFAULT_DATA: OnboardingData = {
  displayName: "",
  provider: null,
  adapter: "osa",
  workspace: null,
  teamTemplate: "dev-team",
  agents: [],
  miosaCloud: false,
};

function createOnboardingStore() {
  let completed = $state(false);
  let currentStep = $state(0);
  let data = $state<OnboardingData>({ ...DEFAULT_DATA });

  function load() {
    if (!browser) return;
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const parsed = JSON.parse(raw) as {
        completed?: boolean;
        currentStep?: number;
        data?: Partial<OnboardingData>;
      };
      completed = parsed.completed ?? false;
      currentStep = parsed.currentStep ?? 0;
      data = { ...DEFAULT_DATA, ...(parsed.data ?? {}) };
    } catch {
      // Corrupted storage — start fresh
    }
  }

  function persist() {
    if (!browser) return;
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ completed, currentStep, data }),
    );
  }

  function nextStep() {
    if (currentStep < TOTAL_STEPS - 1) {
      currentStep++;
      persist();
    }
  }

  function prevStep() {
    if (currentStep > 0) {
      currentStep--;
      persist();
    }
  }

  function goToStep(n: number) {
    if (n >= 0 && n < TOTAL_STEPS) {
      currentStep = n;
      persist();
    }
  }

  function updateData(partial: Partial<OnboardingData>) {
    data = { ...data, ...partial };
    persist();
  }

  function complete() {
    completed = true;
    persist();
  }

  function reset() {
    completed = false;
    currentStep = 0;
    data = { ...DEFAULT_DATA };
    if (browser) localStorage.removeItem(STORAGE_KEY);
  }

  // Hydrate immediately on construction
  load();

  return {
    get completed() {
      return completed;
    },
    get currentStep() {
      return currentStep;
    },
    get data() {
      return data;
    },
    get totalSteps() {
      return TOTAL_STEPS;
    },
    load,
    persist,
    nextStep,
    prevStep,
    goToStep,
    updateData,
    complete,
    reset,
  };
}

export const onboardingStore = createOnboardingStore();
