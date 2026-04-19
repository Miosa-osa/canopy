/**
 * Sandbox domain types — matches CanopyWeb.Schemas.SandboxSchema.Sandbox.
 *
 * Sandboxes are ephemeral MIOSA-provisioned Firecracker VMs attached to
 * Canopy sessions. There is no separate sandboxes table; data is derived
 * from the sessions table (`miosa_sandbox_*` columns).
 */

export type SandboxStatus =
  | "pending"
  | "provisioning"
  | "ready"
  | "destroyed"
  | "skipped"
  | "failed";

export interface Sandbox {
  /** MIOSA-assigned sandbox ID */
  sandbox_id: string;
  /** Owning session UUID */
  session_id: string;
  /** Sandbox access URL injected as CANOPY_MIOSA_SANDBOX_URL. Null until ready. */
  url: string | null;
  /** Sandbox lifecycle status */
  status: SandboxStatus;
}
