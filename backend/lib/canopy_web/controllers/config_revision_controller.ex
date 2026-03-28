defmodule CanopyWeb.ConfigRevisionController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.ConfigRevision
  import Ecto.Query

  def index(conn, params) do
    query =
      from r in ConfigRevision,
        order_by: [desc: r.inserted_at]

    query =
      if params["entity_type"],
        do: where(query, [r], r.entity_type == ^params["entity_type"]),
        else: query

    query =
      if params["entity_id"],
        do: where(query, [r], r.entity_id == ^params["entity_id"]),
        else: query

    query =
      if params["workspace_id"],
        do: where(query, [r], r.workspace_id == ^params["workspace_id"]),
        else: query

    limit = min(parse_int(params["limit"], 50), 200)
    query = limit(query, ^limit)

    revisions = Repo.all(query)
    json(conn, %{revisions: Enum.map(revisions, &serialize/1)})
  end

  def restore(conn, %{"id" => id}) do
    case Repo.get(ConfigRevision, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      revision ->
        # Create a restore revision: old_value is what we're changing FROM (current),
        # new_value is what we're restoring TO (the old_value from the selected revision)
        attrs = %{
          "entity_type" => revision.entity_type,
          "entity_id" => revision.entity_id,
          "key" => revision.key,
          "old_value" => revision.new_value,
          "new_value" => revision.old_value,
          "workspace_id" => revision.workspace_id
        }

        case %ConfigRevision{} |> ConfigRevision.changeset(attrs) |> Repo.insert() do
          {:ok, restored} ->
            json(conn, %{ok: true, revision: serialize(restored)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end
    end
  end

  # --- Private helpers ---

  defp serialize(%ConfigRevision{} = r) do
    %{
      id: r.id,
      entity_type: r.entity_type,
      entity_id: r.entity_id,
      key: r.key,
      old_value: r.old_value,
      new_value: r.new_value,
      changed_by: r.changed_by,
      workspace_id: r.workspace_id,
      inserted_at: r.inserted_at
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
