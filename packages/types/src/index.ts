/**
 * @canopyai/types — Shared TypeScript types for Canopy v2
 *
 * API types are generated from the backend OpenAPI spec via:
 *   pnpm generate
 *
 * This runs `mix canopy.gen.openapi` (writes openapi.json from Elixir schemas),
 * then `openapi-typescript openapi.json --output src/api.ts`.
 *
 * DO NOT hand-edit src/api.ts — it is generated. Edit the Elixir schemas
 * under backend/lib/canopy_web/schemas/*.ex and regenerate.
 *
 * Re-export convention: consumers import from "@canopyai/types" for the helpers
 * and from "@canopyai/types/api" for the raw generated paths/components types.
 */

export type * from "./api.js";

// ---------------------------------------------------------------------------
// Helper types for extracting request / response bodies from generated paths
// ---------------------------------------------------------------------------
//
// openapi-typescript generates:
//   paths["/api/v1/sessions"]["post"] = operations["CanopyWeb.SessionsController.create"]
//   operations[name].requestBody?: { content: { "application/json": <schema> } }
//   operations[name].responses[200].content["application/json"] = <schema>
//
// The helpers below extract the typed payload for each verb and status code.
// They handle the optional requestBody field (marked `?:` in generated output).

import type { paths } from "./api.js";

// Internal utility: resolve an optional property to its non-undefined value.
type NonOptional<T> = NonNullable<T>;

/**
 * Extracts the JSON request body type for a given API path.
 *
 * Searches POST → PUT → PATCH in order; returns `never` if none has a body.
 *
 * Usage:
 *   type CreateSessionBody = ApiRequestBody<"/api/v1/sessions">;
 *   // → { runtime_type: string; cwd: string; … }
 */
export type ApiRequestBody<Path extends keyof paths> =
  // POST
  paths[Path] extends { post: infer Op }
    ? Op extends { requestBody?: infer B }
      ? NonOptional<B> extends { content: { "application/json": infer R } }
        ? R
        : never
      : never
    : // PUT
      paths[Path] extends { put: infer Op }
      ? Op extends { requestBody?: infer B }
        ? NonOptional<B> extends { content: { "application/json": infer R } }
          ? R
          : never
        : never
      : // PATCH
        paths[Path] extends { patch: infer Op }
        ? Op extends { requestBody?: infer B }
          ? NonOptional<B> extends { content: { "application/json": infer R } }
            ? R
            : never
          : never
        : never;

/**
 * Extracts the JSON response body type for a given API path and status code.
 * Defaults to status 200.
 *
 * Searches GET → POST → PUT → DELETE in order.
 *
 * Usage:
 *   type Session = ApiResponseBody<"/api/v1/sessions/{id}">;
 *   type Sessions = ApiResponseBody<"/api/v1/sessions", 200>;
 *   type ErrorBody = ApiResponseBody<"/api/v1/sessions", 422>;
 */
export type ApiResponseBody<
  Path extends keyof paths,
  Status extends number = 200,
> = paths[Path] extends { get: infer Op }
  ? Op extends {
      responses: {
        [K in Status]: { content: { "application/json": infer R } };
      };
    }
    ? R
    : never
  : paths[Path] extends { post: infer Op }
    ? Op extends {
        responses: {
          [K in Status]: { content: { "application/json": infer R } };
        };
      }
      ? R
      : never
    : paths[Path] extends { put: infer Op }
      ? Op extends {
          responses: {
            [K in Status]: { content: { "application/json": infer R } };
          };
        }
        ? R
        : never
      : paths[Path] extends { delete: infer Op }
        ? Op extends {
            responses: {
              [K in Status]: { content: { "application/json": infer R } };
            };
          }
          ? R
          : never
        : never;

/**
 * Extracts path parameter types for a given API path.
 *
 * Usage:
 *   type SessionParams = ApiPathParams<"/api/v1/sessions/{id}">;
 *   // → { id: string }
 */
export type ApiPathParams<Path extends keyof paths> = paths[Path] extends {
  parameters: { path: infer P };
}
  ? P
  : never;
