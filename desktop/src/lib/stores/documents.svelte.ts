// src/lib/stores/documents.svelte.ts
// Documents store — fetches from /api/v1/documents when available,
// falls back to empty state gracefully (endpoint is optional on the backend).

import type { Document, DocumentTreeNode } from "$api/types";
import { documents as documentsApi } from "$api/client";

class DocumentsStore {
  documents = $state<Document[]>([]);
  tree = $state<DocumentTreeNode[]>([]);
  selected = $state<Document | null>(null);
  loading = $state(false);
  error = $state<string | null>(null);

  async fetchDocuments(): Promise<void> {
    this.loading = true;
    try {
      const data = await documentsApi.list();
      this.documents = data.documents;
      this.tree = data.tree;
      this.error = null;
    } catch {
      // Non-fatal: endpoint may not yet be available on the backend.
      // Stay empty silently.
      this.documents = [];
      this.tree = [];
      this.error = null;
    } finally {
      this.loading = false;
    }
  }

  selectDocument(doc: Document | null): void {
    this.selected = doc;
  }

  getByPath(path: string): Document | null {
    return this.documents.find((d) => d.path === path) ?? null;
  }
}

export const documentsStore = new DocumentsStore();
