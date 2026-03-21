// src/lib/stores/schedules.svelte.ts
import type { Schedule, HeartbeatRun, CronPreset } from "$api/types";
import { schedules as schedulesApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

export const CRON_PRESETS: CronPreset[] = [
  {
    id: "every-minute",
    cron: "* * * * *",
    label: "Every minute",
    description: "Runs once per minute",
  },
  {
    id: "every-5-minutes",
    cron: "*/5 * * * *",
    label: "Every 5 minutes",
    description: "Runs every 5 minutes",
  },
  {
    id: "every-15-minutes",
    cron: "*/15 * * * *",
    label: "Every 15 minutes",
    description: "Runs every 15 minutes",
  },
  {
    id: "every-30-minutes",
    cron: "*/30 * * * *",
    label: "Every 30 minutes",
    description: "Runs every 30 minutes",
  },
  {
    id: "hourly",
    cron: "0 * * * *",
    label: "Hourly",
    description: "Runs at the top of every hour",
  },
  {
    id: "every-4-hours",
    cron: "0 */4 * * *",
    label: "Every 4 hours",
    description: "Runs every 4 hours",
  },
  {
    id: "daily-midnight",
    cron: "0 0 * * *",
    label: "Daily at midnight",
    description: "Runs once per day at 00:00 UTC",
  },
  {
    id: "daily-9am",
    cron: "0 9 * * *",
    label: "Daily at 9am",
    description: "Runs once per day at 09:00 UTC",
  },
  {
    id: "weekdays",
    cron: "0 9 * * 1-5",
    label: "Weekdays at 9am",
    description: "Runs Monday–Friday at 09:00 UTC",
  },
  {
    id: "weekly-monday",
    cron: "0 9 * * 1",
    label: "Weekly on Monday",
    description: "Runs every Monday at 09:00 UTC",
  },
  {
    id: "monthly-1st",
    cron: "0 9 1 * *",
    label: "Monthly on the 1st",
    description: "Runs on the 1st of every month at 09:00 UTC",
  },
];

class SchedulesStore {
  schedules = $state<Schedule[]>([]);
  runHistory = $state<Record<string, HeartbeatRun[]>>({});
  selected = $state<Schedule | null>(null);
  loading = $state(false);
  error = $state<string | null>(null);

  // Derived: schedules sorted by next_run_at ascending (nulls last)
  nextRuns = $derived.by(() => {
    return [...this.schedules].sort((a, b) => {
      if (!a.next_run_at && !b.next_run_at) return 0;
      if (!a.next_run_at) return 1;
      if (!b.next_run_at) return -1;
      return (
        new Date(a.next_run_at).getTime() - new Date(b.next_run_at).getTime()
      );
    });
  });

  enabledCount = $derived(this.schedules.filter((s) => s.enabled).length);
  totalCount = $derived(this.schedules.length);

  async fetchSchedules(workspaceId?: string): Promise<void> {
    this.loading = true;
    try {
      this.schedules = await schedulesApi.list(workspaceId);
      this.error = null;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load schedules", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchRunHistory(scheduleId: string): Promise<HeartbeatRun[]> {
    try {
      const data = await schedulesApi.runs(scheduleId);
      const runs = data.runs ?? [];
      this.runHistory = { ...this.runHistory, [scheduleId]: runs };
      return runs;
    } catch (e) {
      const msg = (e as Error).message;
      toastStore.error("Failed to load run history", msg);
      return [];
    }
  }

  async createSchedule(data: {
    agent_id: string;
    cron: string;
    context?: string;
  }): Promise<Schedule | null> {
    this.loading = true;
    try {
      const created = await schedulesApi.create(data);
      this.schedules = [created, ...this.schedules];
      this.error = null;
      toastStore.success("Schedule created", created.human_readable);
      return created;
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to create schedule", msg);
      return null;
    } finally {
      this.loading = false;
    }
  }

  async updateSchedule(
    id: string,
    data: Partial<{ cron: string; context: string; enabled: boolean }>,
  ): Promise<Schedule | null> {
    const previous = this.schedules;
    this.schedules = this.schedules.map((s) =>
      s.id === id ? { ...s, ...data } : s,
    );
    if (this.selected?.id === id) {
      this.selected = { ...this.selected, ...data };
    }
    try {
      const updated = await schedulesApi.update(id, data);
      this.schedules = this.schedules.map((s) => (s.id === id ? updated : s));
      if (this.selected?.id === id) {
        this.selected = updated;
      }
      this.error = null;
      return updated;
    } catch (e) {
      this.schedules = previous;
      if (this.selected?.id === id) {
        this.selected = previous.find((s) => s.id === id) ?? this.selected;
      }
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to update schedule", msg);
      return null;
    }
  }

  async toggleSchedule(id: string): Promise<void> {
    const schedule = this.schedules.find((s) => s.id === id);
    if (!schedule) return;
    await this.updateSchedule(id, { enabled: !schedule.enabled });
  }

  async deleteSchedule(id: string): Promise<void> {
    const previous = this.schedules;
    this.schedules = this.schedules.filter((s) => s.id !== id);
    if (this.selected?.id === id) {
      this.selected = null;
    }
    try {
      await schedulesApi.delete(id);
      this.error = null;
      toastStore.success("Schedule deleted");
    } catch (e) {
      this.schedules = previous;
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to delete schedule", msg);
    }
  }

  async triggerNow(id: string): Promise<HeartbeatRun | null> {
    try {
      const run = await schedulesApi.triggerNow(id);
      // Prepend new run to history cache if we have it
      if (this.runHistory[id]) {
        this.runHistory = {
          ...this.runHistory,
          [id]: [run, ...this.runHistory[id]],
        };
      }
      toastStore.success("Schedule triggered", "Run started immediately.");
      return run;
    } catch (e) {
      const msg = (e as Error).message;
      toastStore.error("Failed to trigger schedule", msg);
      return null;
    }
  }

  selectSchedule(schedule: Schedule | null): void {
    this.selected = schedule;
  }
}

export const schedulesStore = new SchedulesStore();
