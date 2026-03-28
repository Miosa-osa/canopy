defmodule CanopyWeb.AlertController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{AlertRule, AlertHistory}
  import Ecto.Query

  def index_rules(conn, params) do
    workspace_id = params["workspace_id"]
    entity = params["entity"]

    query = from r in AlertRule, order_by: [asc: r.name]
    query = if workspace_id, do: where(query, [r], r.workspace_id == ^workspace_id), else: query
    query = if entity, do: where(query, [r], r.entity == ^entity), else: query

    rules = Repo.all(query)
    json(conn, %{rules: Enum.map(rules, &serialize_rule/1)})
  end

  def show_rule(conn, %{"id" => id}) do
    case Repo.get(AlertRule, id) do
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
      rule -> json(conn, %{rule: serialize_rule(rule)})
    end
  end

  def create_rule(conn, params) do
    changeset = AlertRule.changeset(%AlertRule{}, params)

    case Repo.insert(changeset) do
      {:ok, rule} ->
        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(rule.workspace_id),
          %{event: "alert.rule_created", rule_id: rule.id, name: rule.name}
        )

        conn |> put_status(201) |> json(%{rule: serialize_rule(rule)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def update_rule(conn, %{"id" => id} = params) do
    case Repo.get(AlertRule, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      rule ->
        changeset = AlertRule.changeset(rule, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{rule: serialize_rule(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete_rule(conn, %{"id" => id}) do
    case Repo.get(AlertRule, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      rule ->
        Repo.delete!(rule)
        json(conn, %{ok: true})
    end
  end

  def evaluate(conn, params) do
    workspace_id = params["workspace_id"]

    # Placeholder — future: evaluate enabled rules against live metrics
    # and create AlertHistory records when conditions are met
    query = from r in AlertRule, where: r.enabled == true
    query = if workspace_id, do: where(query, [r], r.workspace_id == ^workspace_id), else: query
    enabled_rules = Repo.all(query)

    json(conn, %{
      ok: true,
      evaluated: length(enabled_rules),
      triggered: 0,
      note: "Live evaluation not yet implemented"
    })
  end

  def history(conn, params) do
    rule_id = params["rule_id"]
    resolved = params["resolved"]
    limit = min(parse_int(params["limit"], 50), 200)
    offset = parse_int(params["offset"], 0)

    query =
      from h in AlertHistory,
        join: r in AlertRule,
        on: h.rule_id == r.id,
        order_by: [desc: h.inserted_at],
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: h.id,
          rule_id: h.rule_id,
          rule_name: r.name,
          entity: r.entity,
          entity_value: h.entity_value,
          resolved: h.resolved,
          inserted_at: h.inserted_at
        }

    query = if rule_id, do: where(query, [h], h.rule_id == ^rule_id), else: query

    query =
      case resolved do
        "true" -> where(query, [h], h.resolved == true)
        "false" -> where(query, [h], h.resolved == false)
        _ -> query
      end

    entries = Repo.all(query)
    json(conn, %{history: entries})
  end

  defp serialize_rule(%AlertRule{} = r) do
    %{
      id: r.id,
      name: r.name,
      description: r.description,
      entity: r.entity,
      field: r.field,
      operator: r.operator,
      value: r.value,
      cooldown_minutes: r.cooldown_minutes,
      notify_targets: r.notify_targets,
      enabled: r.enabled,
      trigger_count: r.trigger_count,
      last_triggered_at: r.last_triggered_at,
      workspace_id: r.workspace_id,
      inserted_at: r.inserted_at,
      updated_at: r.updated_at
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
