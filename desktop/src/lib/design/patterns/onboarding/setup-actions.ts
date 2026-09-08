import { hireAgent } from '$lib/api/queries/agents.js';
import { getTauriDialog, isTauri } from '$lib/tauri/index.js';

export async function chooseOnboardingFolder(): Promise<string | null> {
  if (!isTauri()) {
    throw new Error('Folder selection requires the Canopy desktop app. You can skip this step.');
  }
  const { open } = await getTauriDialog();
  const result = await open({ directory: true, multiple: false, title: 'Select workspace folder' });
  return typeof result === 'string' ? result : null;
}

export async function hireStarterAgents(
  slugs: string[]
): Promise<{ hired: string[]; failed: string[] }> {
  const results = await Promise.allSettled(slugs.map((slug) => hireAgent(slug)));
  const hired: string[] = [];
  const failed: string[] = [];
  results.forEach((result, index) => {
    (result.status === 'fulfilled' ? hired : failed).push(slugs[index]);
  });
  return { hired, failed };
}
