import { apiGet } from '$lib/api/client.js';

export interface PinnedItem {
  id: string;
  workspaceSlug: string;
  itemType: string;
  itemRef: string;
  position: number;
}

export function workspacePinsQuery(slug: string) {
  return {
    queryKey: ['workspaces', slug, 'pins'] as const,
    queryFn: () => apiGet<PinnedItem[]>(`/workspaces/${slug}/pins`),
  };
}
