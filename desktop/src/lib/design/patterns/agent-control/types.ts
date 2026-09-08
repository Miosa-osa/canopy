/**
 * Shared types for Agent Control Center components.
 */

export type AgentLane = 'running' | 'paused' | 'scheduled' | 'idle' | 'offline';

export interface LaneConfig {
  id: AgentLane;
  label: string;
  color: string;
}

export const LANE_CONFIGS: LaneConfig[] = [
  {
    id: 'running',
    label: 'Running',
    color: 'var(--success, oklch(0.72 0.17 155))',
  },
  {
    id: 'paused',
    label: 'Paused',
    color: 'var(--priority, oklch(0.75 0.15 80))',
  },
  {
    id: 'scheduled',
    label: 'Scheduled',
    color: 'var(--priority, oklch(0.75 0.15 80))',
  },
  { id: 'idle', label: 'Idle', color: 'var(--fg-muted)' },
  {
    id: 'offline',
    label: 'Offline',
    color: 'var(--destructive, oklch(0.65 0.22 25))',
  },
];
