<!-- src/routes/app/work-products/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { workProductsStore, type WorkProduct, type WorkProductType } from '$lib/stores/work-products.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  type FilterType = WorkProductType | 'all';

  const TYPE_TABS: { value: FilterType; label: string }[] = [
    { value: 'all', label: 'All' },
    { value: 'report', label: 'Reports' },
    { value: 'code', label: 'Code' },
    { value: 'data', label: 'Data' },
    { value: 'document', label: 'Documents' },
    { value: 'analysis', label: 'Analysis' },
    { value: 'design', label: 'Design' },
  ];

  let activeType = $state<FilterType>('all');
  let searchQuery = $state('');

  $effect(() => {
    void workspaceStore.activeWorkspaceId;
    void workProductsStore.fetchProducts();
  });

  $effect(() => {
    const f: Record<string, string> = {};
    if (activeType !== 'all') f['type'] = activeType;
    if (searchQuery.trim()) f['q'] = searchQuery.trim();
    workProductsStore.setFilter(
      activeType !== 'all' || searchQuery.trim()
        ? {
            type: activeType !== 'all' ? activeType : undefined,
            q: searchQuery.trim() || undefined,
          }
        : {},
    );
  });

  let selectedProduct = $state<WorkProduct | null>(null);

  function selectProduct(p: WorkProduct) {
    selectedProduct = selectedProduct?.id === p.id ? null : p;
  }

  function typeIcon(type: WorkProductType): string {
    switch (type) {
      case 'report':   return 'M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15a2.25 2.25 0 012.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25';
      case 'code':     return 'M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5';
      case 'data':     return 'M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125';
      case 'document': return 'M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z';
      case 'analysis': return 'M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z';
      case 'design':   return 'M9.53 16.122a3 3 0 00-5.78 1.128 2.25 2.25 0 01-2.4 2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128zm0 0a15.998 15.998 0 003.388-1.62m-5.043-.025a15.994 15.994 0 011.622-3.395m3.42 3.42a15.995 15.995 0 004.764-4.648l3.876-5.814a1.151 1.151 0 00-1.597-1.597L14.146 6.32a15.996 15.996 0 00-4.649 4.763m3.42 3.42a6.776 6.776 0 00-3.42-3.42';
    }
  }

  function typeColor(type: WorkProductType): string {
    switch (type) {
      case 'report':   return 'wp-type--report';
      case 'code':     return 'wp-type--code';
      case 'data':     return 'wp-type--data';
      case 'document': return 'wp-type--document';
      case 'analysis': return 'wp-type--analysis';
      case 'design':   return 'wp-type--design';
    }
  }

  function statusClass(status: string): string {
    switch (status) {
      case 'final':    return 'wp-status--final';
      case 'draft':    return 'wp-status--draft';
      case 'archived': return 'wp-status--archived';
      default:         return '';
    }
  }

  function formatFileSize(bytes: number | null): string {
    if (bytes === null) return '—';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  function formatDate(iso: string): string {
    return new Date(iso).toLocaleDateString('en-US', {
      month: 'short', day: 'numeric', year: 'numeric',
    });
  }

  function previewLines(text: string, max = 2): string {
    return text.split('\n').slice(0, max).join(' ').slice(0, 120);
  }

  const displayedProducts = $derived(workProductsStore.filteredProducts());
</script>

<PageShell
  title="Work Products"
  subtitle="Data"
  badge={workProductsStore.totalCount > 0 ? workProductsStore.totalCount : undefined}
>
  {#snippet actions()}
    <div class="wp-search-wrap">
      <svg class="wp-search-icon" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 15.803a7.5 7.5 0 0010.607 10.607z" />
      </svg>
      <input
        class="wp-search"
        type="search"
        placeholder="Search products…"
        aria-label="Search work products"
        bind:value={searchQuery}
      />
    </div>
  {/snippet}

  <!-- Type filter tabs -->
  <div class="wp-tabs" role="tablist" aria-label="Filter by product type">
    {#each TYPE_TABS as tab (tab.value)}
      <button
        class="wp-tab"
        class:wp-tab--active={activeType === tab.value}
        role="tab"
        aria-selected={activeType === tab.value}
        onclick={() => { activeType = tab.value; }}
      >
        {tab.label}
        {#if tab.value !== 'all'}
          {@const count = workProductsStore.byType().get(tab.value as WorkProductType)?.length ?? 0}
          {#if count > 0}
            <span class="wp-tab-count">{count}</span>
          {/if}
        {/if}
      </button>
    {/each}
  </div>

  {#if workProductsStore.isLoading}
    <div class="wp-loading" aria-live="polite" aria-busy="true">
      <div class="wp-spinner" aria-hidden="true"></div>
      <span>Loading work products…</span>
    </div>
  {:else if workProductsStore.error}
    <div class="wp-error" role="alert">
      <p>Failed to load: {workProductsStore.error}</p>
      <button onclick={() => void workProductsStore.fetchProducts()}>Retry</button>
    </div>
  {:else if displayedProducts.length === 0}
    <div class="wp-empty">
      <p>No work products found.</p>
    </div>
  {:else}
    <div class="wp-layout" class:wp-layout--split={selectedProduct !== null}>
      <!-- Grid -->
      <div class="wp-grid" role="list">
        {#each displayedProducts as product (product.id)}
          <button
            class="wp-card"
            class:wp-card--selected={selectedProduct?.id === product.id}
            onclick={() => selectProduct(product)}
            aria-pressed={selectedProduct?.id === product.id}
            aria-label="View {product.title}"
            role="listitem"
          >
            <!-- Card header -->
            <div class="wp-card-header">
              <div class="wp-type-icon {typeColor(product.type)}" aria-hidden="true">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d={typeIcon(product.type)} />
                </svg>
              </div>
              <span class="wp-status {statusClass(product.status)}">{product.status}</span>
            </div>

            <!-- Title -->
            <h3 class="wp-card-title">{product.title}</h3>

            <!-- Agent + date -->
            <div class="wp-card-meta">
              <span class="wp-card-agent">{product.agent_name}</span>
              <span class="wp-card-date">{formatDate(product.created_at)}</span>
            </div>

            <!-- Content preview -->
            <p class="wp-card-preview">{previewLines(product.content_preview)}</p>

            <!-- Footer: quality + size -->
            <div class="wp-card-footer">
              {#if product.quality_score !== null}
                <div class="wp-quality" aria-label="Quality score {product.quality_score}%">
                  <div class="wp-quality-bar-track" aria-hidden="true">
                    <div class="wp-quality-bar-fill" style="width: {product.quality_score}%"></div>
                  </div>
                  <span class="wp-quality-label">{product.quality_score}%</span>
                </div>
              {/if}
              {#if product.file_size_bytes !== null}
                <span class="wp-file-size">{formatFileSize(product.file_size_bytes)}</span>
              {/if}
            </div>
          </button>
        {/each}
      </div>

      <!-- Detail panel -->
      {#if selectedProduct !== null}
        {@const p = selectedProduct}
        <aside class="wp-detail" aria-label="Product details">
          <div class="wp-detail-header">
            <div class="wp-type-icon {typeColor(p.type)}" aria-hidden="true">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                <path d={typeIcon(p.type)} />
              </svg>
            </div>
            <div class="wp-detail-title-group">
              <h2 class="wp-detail-title">{p.title}</h2>
              <div class="wp-detail-badges">
                <span class="wp-status {statusClass(p.status)}">{p.status}</span>
                <span class="wp-type-pill">{p.type}</span>
              </div>
            </div>
            <button
              class="wp-detail-close"
              onclick={() => { selectedProduct = null; }}
              aria-label="Close detail panel"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <dl class="wp-detail-meta">
            <div class="wp-meta-row">
              <dt>Agent</dt>
              <dd>{p.agent_name}</dd>
            </div>
            <div class="wp-meta-row">
              <dt>Created</dt>
              <dd>{formatDate(p.created_at)}</dd>
            </div>
            <div class="wp-meta-row">
              <dt>Updated</dt>
              <dd>{formatDate(p.updated_at)}</dd>
            </div>
            {#if p.file_path !== null}
              <div class="wp-meta-row">
                <dt>File</dt>
                <dd class="wp-meta-filepath">{p.file_path}</dd>
              </div>
            {/if}
            {#if p.file_size_bytes !== null}
              <div class="wp-meta-row">
                <dt>Size</dt>
                <dd>{formatFileSize(p.file_size_bytes)}</dd>
              </div>
            {/if}
            {#if p.session_id !== null}
              <div class="wp-meta-row">
                <dt>Session</dt>
                <dd>
                  <a href="/app/sessions/{p.session_id}" class="wp-meta-link">{p.session_id}</a>
                </dd>
              </div>
            {/if}
            {#if p.project_id !== null}
              <div class="wp-meta-row">
                <dt>Project</dt>
                <dd>
                  <a href="/app/projects?id={p.project_id}" class="wp-meta-link">{p.project_id}</a>
                </dd>
              </div>
            {/if}
            {#if p.quality_score !== null}
              <div class="wp-meta-row">
                <dt>Quality</dt>
                <dd>
                  <div class="wp-quality wp-quality--detail">
                    <div class="wp-quality-bar-track" aria-hidden="true">
                      <div class="wp-quality-bar-fill" style="width: {p.quality_score}%"></div>
                    </div>
                    <span class="wp-quality-label">{p.quality_score}%</span>
                  </div>
                </dd>
              </div>
            {/if}
          </dl>

          <div class="wp-detail-content-label">Content Preview</div>
          <pre class="wp-detail-content">{p.content_preview}</pre>

          {#if p.status !== 'archived'}
            <div class="wp-detail-actions">
              <button
                class="wp-action-btn wp-action-btn--archive"
                onclick={() => void workProductsStore.archiveProduct(p.id)}
                aria-label="Archive {p.title}"
              >
                Archive
              </button>
            </div>
          {/if}
        </aside>
      {/if}
    </div>
  {/if}
</PageShell>

<style>
  /* ── Search ──────────────────────────────────────────────────────── */
  .wp-search-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }

  .wp-search-icon {
    position: absolute;
    left: 8px;
    color: var(--text-tertiary);
    pointer-events: none;
  }

  .wp-search {
    width: 200px;
    height: 28px;
    padding: 0 10px 0 28px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-primary);
    font-family: var(--font-sans);
    font-size: 12px;
    transition: border-color 120ms ease;
  }

  .wp-search:focus {
    outline: none;
    border-color: var(--border-hover);
  }

  .wp-search::placeholder {
    color: var(--text-tertiary);
  }

  /* ── Type tabs ───────────────────────────────────────────────────── */
  .wp-tabs {
    display: flex;
    gap: 2px;
    border-bottom: 1px solid var(--border-default);
    margin-bottom: 16px;
    overflow-x: auto;
    scrollbar-width: none;
  }

  .wp-tabs::-webkit-scrollbar { display: none; }

  .wp-tab {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 6px 12px;
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    margin-bottom: -1px;
    color: var(--text-tertiary);
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: color 120ms ease, border-color 120ms ease;
    white-space: nowrap;
  }

  .wp-tab:hover {
    color: var(--text-secondary);
  }

  .wp-tab--active {
    color: var(--text-primary);
    border-bottom-color: var(--accent-primary, #58a6ff);
  }

  .wp-tab-count {
    font-size: 10px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: 9999px;
    padding: 0 5px;
    color: var(--text-tertiary);
  }

  /* ── Loading / Error / Empty ──────────────────────────────────────── */
  .wp-loading {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 48px 0;
    color: var(--text-tertiary);
    font-size: 13px;
    justify-content: center;
  }

  .wp-spinner {
    width: 16px;
    height: 16px;
    border: 2px solid var(--border-default);
    border-top-color: var(--text-secondary);
    border-radius: 50%;
    animation: wp-spin 0.7s linear infinite;
  }

  @keyframes wp-spin {
    to { transform: rotate(360deg); }
  }

  .wp-error,
  .wp-empty {
    padding: 48px 0;
    text-align: center;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .wp-error button {
    margin-top: 12px;
    padding: 6px 16px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-primary);
    font-size: 12px;
    cursor: pointer;
  }

  /* ── Layout ──────────────────────────────────────────────────────── */
  .wp-layout {
    display: block;
  }

  .wp-layout--split {
    display: grid;
    grid-template-columns: 1fr 340px;
    gap: 16px;
    align-items: start;
  }

  @media (max-width: 800px) {
    .wp-layout--split {
      grid-template-columns: 1fr;
    }
  }

  /* ── Product grid ─────────────────────────────────────────────────── */
  .wp-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 12px;
  }

  .wp-layout--split .wp-grid {
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  }

  /* ── Product card ─────────────────────────────────────────────────── */
  .wp-card {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 14px;
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    text-align: left;
    cursor: pointer;
    transition: border-color 120ms ease, background 120ms ease;
    width: 100%;
  }

  .wp-card:hover {
    border-color: var(--border-hover);
  }

  .wp-card--selected {
    border-color: var(--accent-primary, #58a6ff);
    background: var(--bg-surface);
  }

  .wp-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 2px;
  }

  .wp-card-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    line-height: 1.3;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .wp-card-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
  }

  .wp-card-agent {
    font-size: 11px;
    color: var(--text-tertiary);
    font-weight: 500;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wp-card-date {
    font-size: 11px;
    color: var(--text-quaternary, var(--text-tertiary));
    white-space: nowrap;
  }

  .wp-card-preview {
    font-size: 11px;
    color: var(--text-tertiary);
    line-height: 1.4;
    margin: 2px 0;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    font-family: var(--font-mono, monospace);
  }

  .wp-card-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: 4px;
  }

  /* ── Type icon ───────────────────────────────────────────────────── */
  .wp-type-icon {
    width: 26px;
    height: 26px;
    border-radius: var(--radius-xs);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .wp-type--report   { background: rgba(88, 166, 255, 0.12); color: #58a6ff; }
  .wp-type--code     { background: rgba(63, 185, 80, 0.12);  color: #3fb950; }
  .wp-type--data     { background: rgba(163, 113, 247, 0.12); color: #a371f7; }
  .wp-type--document { background: rgba(227, 179, 65, 0.12); color: #e3b341; }
  .wp-type--analysis { background: rgba(248, 81, 73, 0.12);  color: #f85149; }
  .wp-type--design   { background: rgba(240, 136, 62, 0.12); color: #f0883e; }

  /* ── Status badge ─────────────────────────────────────────────────── */
  .wp-status {
    font-size: 10px;
    font-weight: 500;
    padding: 1px 7px;
    border-radius: 9999px;
    text-transform: capitalize;
  }

  .wp-status--final    { background: rgba(63, 185, 80, 0.12);  color: #3fb950; }
  .wp-status--draft    { background: rgba(227, 179, 65, 0.12); color: #e3b341; }
  .wp-status--archived { background: var(--bg-surface);        color: var(--text-tertiary); border: 1px solid var(--border-default); }

  /* ── Quality bar ──────────────────────────────────────────────────── */
  .wp-quality {
    display: flex;
    align-items: center;
    gap: 5px;
    flex: 1;
    min-width: 0;
  }

  .wp-quality--detail {
    max-width: 180px;
  }

  .wp-quality-bar-track {
    flex: 1;
    height: 3px;
    background: var(--border-default);
    border-radius: 2px;
    overflow: hidden;
  }

  .wp-quality-bar-fill {
    height: 100%;
    background: var(--accent-primary, #58a6ff);
    border-radius: 2px;
  }

  .wp-quality-label {
    font-size: 10px;
    color: var(--text-tertiary);
    white-space: nowrap;
  }

  .wp-file-size {
    font-size: 10px;
    color: var(--text-tertiary);
    white-space: nowrap;
  }

  /* ── Detail panel ─────────────────────────────────────────────────── */
  .wp-detail {
    background: var(--bg-elevated);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    padding: 16px;
    position: sticky;
    top: 16px;
  }

  .wp-detail-header {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    margin-bottom: 14px;
  }

  .wp-detail-title-group {
    flex: 1;
    min-width: 0;
  }

  .wp-detail-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0 0 5px 0;
    line-height: 1.3;
  }

  .wp-detail-badges {
    display: flex;
    align-items: center;
    gap: 5px;
    flex-wrap: wrap;
  }

  .wp-type-pill {
    font-size: 10px;
    font-weight: 500;
    padding: 1px 7px;
    border-radius: 9999px;
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    color: var(--text-tertiary);
    text-transform: capitalize;
  }

  .wp-detail-close {
    background: none;
    border: none;
    color: var(--text-tertiary);
    cursor: pointer;
    padding: 2px;
    border-radius: var(--radius-xs);
    transition: color 100ms ease;
    flex-shrink: 0;
  }

  .wp-detail-close:hover {
    color: var(--text-primary);
  }

  /* ── Detail metadata ──────────────────────────────────────────────── */
  .wp-detail-meta {
    margin: 0 0 14px 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .wp-meta-row {
    display: flex;
    align-items: baseline;
    gap: 8px;
    font-size: 12px;
  }

  .wp-meta-row dt {
    width: 60px;
    flex-shrink: 0;
    color: var(--text-tertiary);
    font-weight: 500;
  }

  .wp-meta-row dd {
    color: var(--text-secondary);
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wp-meta-filepath {
    font-family: var(--font-mono, monospace);
    font-size: 11px;
    color: var(--text-secondary);
  }

  .wp-meta-link {
    color: var(--accent-primary, #58a6ff);
    text-decoration: none;
    font-family: var(--font-mono, monospace);
    font-size: 11px;
  }

  .wp-meta-link:hover {
    text-decoration: underline;
  }

  /* ── Detail content preview ───────────────────────────────────────── */
  .wp-detail-content-label {
    font-size: 10px;
    font-weight: 600;
    color: var(--text-tertiary);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-bottom: 6px;
  }

  .wp-detail-content {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    padding: 10px;
    font-family: var(--font-mono, monospace);
    font-size: 11px;
    color: var(--text-secondary);
    line-height: 1.5;
    white-space: pre-wrap;
    word-break: break-word;
    max-height: 280px;
    overflow-y: auto;
    margin: 0 0 12px 0;
    scrollbar-width: thin;
  }

  /* ── Detail actions ───────────────────────────────────────────────── */
  .wp-detail-actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .wp-action-btn {
    height: 28px;
    padding: 0 12px;
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xs);
    color: var(--text-secondary);
    font-family: var(--font-sans);
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: all 100ms ease;
  }

  .wp-action-btn:hover {
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .wp-action-btn--archive:hover {
    border-color: #f8514966;
    color: #f85149;
    background: rgba(248, 81, 73, 0.06);
  }
</style>
