// SPA mode for Tauri — adapter-static with fallback: 'index.html' serves a
// single client-rendered shell. SSR is disabled because every page uses
// TanStack Query + live backend fetches; running them on Node on every dev
// request triggers eager-fetch warnings and breaks auth-scoped requests.
export const prerender = false;
export const ssr = false;
