defmodule Canopy.Presence do
  @moduledoc """
  Phoenix.Presence adapter for Canopy.

  Tracks online users across real-time topics (channels, docs, etc.).
  Uses `Canopy.PubSub` as the backing pub-sub bus.

  Add to the supervision tree AFTER `{Phoenix.PubSub, name: Canopy.PubSub}`
  and BEFORE `CanopyWeb.Endpoint`.

  ## Canonical topic namespace

  All real-time topics in Canopy follow these formats. Callers that broadcast
  directly via `Phoenix.PubSub` MUST use these formats — no ad-hoc strings.

    user:<user_id>          per-user notifications + inbox
    workspace:<slug>        workspace-level events (file add, member join)
    session:<id>            session transcript entries (existing)
    channel:<id>            channel messages + presence
    chat:<thread_id>        chat thread messages
    doc:<id>                doc edit events + cursor presence
    task:<id>               task updates + comments
    tenant:<org_id>         tenant-wide broadcast (Week 17+)

  Example:

      Phoenix.PubSub.broadcast(Canopy.PubSub, "session:\#{id}", {:transcript_entry, entry})
      Phoenix.PubSub.subscribe(Canopy.PubSub, "channel:\#{channel_id}")
  """

  use Phoenix.Presence,
    otp_app: :canopy,
    pubsub_server: Canopy.PubSub
end
