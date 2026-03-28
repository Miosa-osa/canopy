defmodule CanopyWeb.PluginController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Plugin, PluginLog}
  import Ecto.Query

  def index(conn, params) do
    query =
      from p in Plugin,
        order_by: [asc: p.name]

    query =
      if params["workspace_id"],
        do: where(query, [p], p.workspace_id == ^params["workspace_id"]),
        else: query

    query =
      if params["enabled"] != nil,
        do: where(query, [p], p.enabled == ^(params["enabled"] == "true")),
        else: query

    plugins = Repo.all(query)
    json(conn, %{plugins: Enum.map(plugins, &serialize/1)})
  end

  def create(conn, params) do
    changeset = Plugin.changeset(%Plugin{}, params)

    case Repo.insert(changeset) do
      {:ok, plugin} ->
        conn |> put_status(201) |> json(%{plugin: serialize(plugin)})

      {:error, cs} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(cs)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Plugin, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      plugin ->
        json(conn, %{plugin: serialize(plugin)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Plugin, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      plugin ->
        changeset = Plugin.changeset(plugin, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{plugin: serialize(updated)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Plugin, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      plugin ->
        Repo.delete!(plugin)
        json(conn, %{ok: true})
    end
  end

  def logs(conn, %{"plugin_id" => id} = params) do
    case Repo.get(Plugin, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      _plugin ->
        limit = min(parse_int(params["limit"], 100), 500)

        query =
          from l in PluginLog,
            where: l.plugin_id == ^id,
            order_by: [desc: l.inserted_at],
            limit: ^limit

        query =
          if params["level"],
            do: where(query, [l], l.level == ^params["level"]),
            else: query

        logs = Repo.all(query)
        json(conn, %{logs: Enum.map(logs, &serialize_log/1)})
    end
  end

  # --- Private helpers ---

  defp serialize(%Plugin{} = p) do
    %{
      id: p.id,
      slug: p.slug,
      name: p.name,
      version: p.version,
      enabled: p.enabled,
      config: p.config,
      state: p.state,
      workspace_id: p.workspace_id,
      created_at: p.inserted_at,
      inserted_at: p.inserted_at,
      updated_at: p.updated_at
    }
  end

  defp serialize_log(%PluginLog{} = l) do
    %{
      id: l.id,
      plugin_id: l.plugin_id,
      level: l.level,
      message: l.message,
      metadata: l.metadata,
      inserted_at: l.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
