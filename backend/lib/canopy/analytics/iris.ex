defmodule Canopy.Analytics.Iris do
  @moduledoc """
  Bootstrap surface for **Iris**, Canopy's Analytics Agent.

  Iris is hired on application boot, her tool surface (`Canopy.Tools.Analytics`)
  is registered with the in-memory tool registry, and a one-time "online"
  message is posted to the `#analytics-feed` channel the first time she is
  hired.

  ## Boot sequence

  Called from the `Canopy.Application` post-startup Task in this order:

      Canopy.Analytics.Iris.hire_if_missing()  # ensure DB row, set hired: true
      Canopy.Analytics.Iris.register_tools()   # ETS registration of 6 tools

  The heartbeat schedule (`cron: "0 */4 * * *"`) is picked up automatically by
  `Canopy.Heartbeat.Registrar.register_all_hired/0` after `hire_if_missing/0`
  has flipped `hired: true` on the DB row.

  ## Idempotency

  All three public functions are safe to call repeatedly:

  - `hire_if_missing/0` upserts the row by slug; never duplicates.
  - `register_tools/0` overwrites existing ETS entries with the same name.
  - `announce_online/0` only posts on the very first hire — once the agent row
    has `config["announced_online"] = true` it is a no-op.
  """

  alias Canopy.Agents
  alias Canopy.Agents.Agent
  alias Canopy.Channels
  alias Canopy.Repo
  alias Canopy.Tools.Registry, as: ToolRegistry

  require Logger

  @slug "analytics-agent"
  @category "specialized"
  @name "Iris"
  @description "Quiet, persistent analytics operator for the Canopy workspace."
  @persona_path "analytics-agent/persona.md"
  @default_runtime "claude-local"
  @default_model "claude-sonnet-4-7"
  @heartbeat_cron "0 */4 * * *"
  @budget_monthly_usd Decimal.new(5000)
  @announce_channel_slug "analytics-feed"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Ensures Iris exists in the `agents` table with `hired: true`.

  Reads the persona body from `priv/agents/analytics-agent/persona.md` (best
  effort — falls back to an empty string if the file is missing) and upserts
  an `Canopy.Agents.Agent` row keyed by slug.

  Returns `{:ok, agent}` on success, `{:error, changeset}` on persistence
  failure. Never raises; the boot Task can call this without try/rescue.
  """
  @spec hire_if_missing() :: {:ok, Agent.t()} | {:error, Ecto.Changeset.t()}
  def hire_if_missing do
    persona_markdown = read_persona_body()

    base_attrs = %{
      slug: @slug,
      category: @category,
      name: @name,
      description: @description,
      persona_path: @persona_path,
      persona_markdown: persona_markdown,
      default_runtime: @default_runtime,
      default_model: @default_model,
      heartbeat_cron: @heartbeat_cron,
      budget_monthly_usd: @budget_monthly_usd,
      hired: true
    }

    case Agents.get_by_slug(@slug) do
      {:ok, existing} ->
        # Re-hire if the row exists. We deliberately do NOT overwrite
        # persona_markdown if it has been edited at runtime via
        # Agents.update_persona/2 — only refresh metadata fields and ensure
        # hired: true.
        update_attrs =
          base_attrs
          |> Map.delete(:persona_markdown)
          |> maybe_keep_persona(existing)

        existing
        |> Agent.changeset(update_attrs)
        |> Repo.update()

      {:error, :not_found} ->
        %Agent{}
        |> Agent.changeset(base_attrs)
        |> Repo.insert()
    end
  end

  @doc """
  Registers Iris's tool surface (`Canopy.Tools.Analytics`) with the in-memory
  tool registry.

  Idempotent — the registry overwrites entries on re-registration, so this is
  safe to call from boot, from tests, or after a hot reload.

  Returns `:ok`.
  """
  @spec register_tools() :: :ok
  def register_tools do
    ToolRegistry.register_module(Canopy.Tools.Analytics)
  end

  @doc """
  Posts a one-time "online" message to the `#analytics-feed` channel.

  This is the boot-time announcement: the first time Iris is hired we want a
  visible signal in the analytics feed so operators know she has come up. On
  subsequent boots the function is a no-op.

  The first-run flag is stored as `config["announced_online"] = true` on the
  agent row. Subsequent calls short-circuit by inspecting that flag.

  If the `analytics-feed` channel does not exist this function logs a warning
  and returns `:ok`. Channel creation is the operator's responsibility — Iris
  does not create channels on her own.

  Returns `:ok` whether or not a message was actually posted.
  """
  @spec announce_online() :: :ok
  def announce_online do
    with {:ok, %Agent{} = agent} <- Agents.get_by_slug(@slug),
         false <- already_announced?(agent),
         {:ok, channel} <- Channels.get(@announce_channel_slug),
         {:ok, _msg} <- post_online_message(channel.id, agent.id) do
      mark_announced!(agent)
      :ok
    else
      true ->
        # Already announced — short-circuit cleanly.
        :ok

      {:error, :not_found} ->
        Logger.info(
          "[Canopy.Analytics.Iris] Skipping online announcement — " <>
            "channel ##{@announce_channel_slug} or agent #{@slug} not found yet."
        )

        :ok

      {:error, reason} ->
        Logger.warning(
          "[Canopy.Analytics.Iris] Online announcement failed (non-fatal): " <>
            inspect(reason)
        )

        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec read_persona_body() :: String.t()
  defp read_persona_body do
    priv = :canopy |> :code.priv_dir() |> to_string()
    path = Path.join([priv, "agents", @persona_path])

    case File.read(path) do
      {:ok, raw} -> extract_body(raw)
      {:error, _reason} -> ""
    end
  rescue
    _error -> ""
  end

  @frontmatter_regex ~r/\A---\n(.+?)\n---\n/s

  @spec extract_body(String.t()) :: String.t()
  defp extract_body(raw) do
    case Regex.run(@frontmatter_regex, raw) do
      [full | _] ->
        raw
        |> String.slice(String.length(full)..-1//1)
        |> String.trim()

      nil ->
        String.trim(raw)
    end
  end

  # If the existing row already has persona_markdown content, preserve it so
  # runtime edits via Agents.update_persona/2 are not stomped on by reboot.
  @spec maybe_keep_persona(map(), Agent.t()) :: map()
  defp maybe_keep_persona(attrs, %Agent{persona_markdown: pm}) when is_binary(pm) and pm != "" do
    attrs
  end

  defp maybe_keep_persona(attrs, _agent) do
    Map.put(attrs, :persona_markdown, read_persona_body())
  end

  @spec already_announced?(Agent.t()) :: boolean()
  defp already_announced?(%Agent{config: config}) when is_map(config) do
    Map.get(config, "announced_online", false) == true
  end

  defp already_announced?(_), do: false

  @spec mark_announced!(Agent.t()) :: :ok
  defp mark_announced!(%Agent{config: config} = agent) do
    new_config = Map.put(config || %{}, "announced_online", true)

    agent
    |> Agent.changeset(%{config: new_config})
    |> Repo.update()
    |> case do
      {:ok, _} ->
        :ok

      {:error, cs} ->
        Logger.warning(
          "[Canopy.Analytics.Iris] Failed to mark announced_online: #{inspect(cs.errors)}"
        )

        :ok
    end
  end

  @spec post_online_message(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, term()} | {:error, term()}
  defp post_online_message(channel_id, agent_id) do
    body = """
    📈 **Iris** is online.

    Heartbeat scheduled every 4 hours. Daily digest at 9am Roberto-local. \
    Wake on `@iris` mention. Investigations stream to this channel.
    """

    Channels.create_message(%{
      channel_id: channel_id,
      author_type: "agent",
      author_id: to_string(agent_id),
      body_markdown: String.trim(body)
    })
  end
end
