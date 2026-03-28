// src/lib/api/config.ts
// Shared API configuration — single source of truth for all connection modules.

export const API_BASE_URL: string =
  import.meta.env.VITE_API_URL ?? "http://127.0.0.1:9089";

export const API_PREFIX = "/api/v1";

export const WS_BASE_URL: string =
  import.meta.env.VITE_WS_URL ?? API_BASE_URL.replace(/^http/, "ws");
