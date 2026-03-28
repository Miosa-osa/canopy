defmodule CanopyWeb.LibraryController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, LibraryInstall, LibraryItem, Skill}
  import Ecto.Query

  # ──────────────────────────────────────────────────────────────────────────────
  # Read actions
  # ──────────────────────────────────────────────────────────────────────────────

  def index(conn, params) do
    query = base_query()

    query = apply_category_filter(query, params["category"])
    query = apply_status_filter(query, params["status"])
    query = apply_visibility_filter(query, params["visibility"])
    query = apply_search_filter(query, params["search"])
    query = apply_tags_filter(query, params["tags"])
    query = apply_sort(query, params["sort_by"])

    {page, per_page} = pagination_params(params)
    offset = (page - 1) * per_page

    total = Repo.aggregate(query, :count, :id)
    items = Repo.all(from q in query, limit: ^per_page, offset: ^offset)

    json(conn, %{
      items: Enum.map(items, &serialize/1),
      meta: %{page: page, per_page: per_page, total: total}
    })
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(LibraryItem, id) do
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
      item -> json(conn, %{item: serialize(item)})
    end
  end

  def installed(conn, params) do
    workspace_id = params["workspace_id"] || conn.assigns[:workspace_id]

    installs =
      Repo.all(
        from li in LibraryInstall,
          where: li.workspace_id == ^workspace_id,
          preload: [:library_item]
      )

    json(conn, %{installs: Enum.map(installs, &serialize_install/1)})
  end

  def categories(conn, _params) do
    rows =
      Repo.all(
        from i in LibraryItem,
          where: i.status == "published",
          group_by: i.category,
          select: %{
            category: i.category,
            count: count(i.id)
          },
          order_by: [asc: i.category]
      )

    json(conn, %{categories: rows})
  end

  # ──────────────────────────────────────────────────────────────────────────────
  # Write actions
  # ──────────────────────────────────────────────────────────────────────────────

  def create(conn, params) do
    current_user = conn.assigns[:current_user]
    organization_id = conn.assigns[:organization_id]

    attrs =
      params
      |> Map.put("created_by_id", current_user && current_user.id)
      |> Map.put("organization_id", organization_id)

    case %LibraryItem{} |> LibraryItem.changeset(attrs) |> Repo.insert() do
      {:ok, item} ->
        conn |> put_status(201) |> json(%{item: serialize(item)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(LibraryItem, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      item ->
        case item |> LibraryItem.changeset(params) |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{item: serialize(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(LibraryItem, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      item ->
        case item |> Ecto.Changeset.change(status: "archived") |> Repo.update() do
          {:ok, _} -> json(conn, %{ok: true})
          {:error, _} -> conn |> put_status(500) |> json(%{error: "delete_failed"})
        end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────────
  # Install / Uninstall
  # ──────────────────────────────────────────────────────────────────────────────

  def install(conn, %{"library_id" => item_id} = params) do
    workspace_id = params["workspace_id"] || conn.assigns[:workspace_id]
    current_user = conn.assigns[:current_user]

    with %LibraryItem{} = item <- Repo.get(LibraryItem, item_id) || {:error, :not_found},
         nil <- existing_install(item_id, workspace_id) do
      install_attrs = %{
        library_item_id: item_id,
        workspace_id: workspace_id,
        installed_by_id: current_user && current_user.id,
        installed_version: item.version,
        config_overrides: params["config_overrides"] || %{}
      }

      Repo.transaction(fn ->
        {:ok, install} =
          %LibraryInstall{}
          |> LibraryInstall.changeset(install_attrs)
          |> Repo.insert()

        Repo.update_all(
          from(i in LibraryItem, where: i.id == ^item_id),
          inc: [install_count: 1]
        )

        entity = maybe_create_entity(item, workspace_id, params)
        {install, entity}
      end)
      |> case do
        {:ok, {install, entity}} ->
          response = %{install: serialize_install(%{install | library_item: item})}
          response = if entity, do: Map.put(response, :entity, entity), else: response
          conn |> put_status(201) |> json(response)

        {:error, _} ->
          conn |> put_status(500) |> json(%{error: "install_failed"})
      end
    else
      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      %LibraryInstall{} ->
        conn |> put_status(409) |> json(%{error: "already_installed"})
    end
  end

  def uninstall(conn, %{"library_id" => item_id} = params) do
    workspace_id = params["workspace_id"] || conn.assigns[:workspace_id]

    case existing_install(item_id, workspace_id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_installed"})

      install ->
        Repo.transaction(fn ->
          Repo.delete!(install)

          Repo.update_all(
            from(i in LibraryItem, where: i.id == ^item_id and i.install_count > 0),
            inc: [install_count: -1]
          )
        end)

        json(conn, %{ok: true})
    end
  end

  # ──────────────────────────────────────────────────────────────────────────────
  # Rating
  # ──────────────────────────────────────────────────────────────────────────────

  def rate(conn, %{"library_id" => item_id} = params) do
    score = params["score"]

    cond do
      is_nil(score) ->
        conn |> put_status(422) |> json(%{error: "score_required"})

      not is_integer(score) or score < 1 or score > 5 ->
        conn |> put_status(422) |> json(%{error: "score_must_be_1_to_5"})

      true ->
        case Repo.get(LibraryItem, item_id) do
          nil ->
            conn |> put_status(404) |> json(%{error: "not_found"})

          item ->
            {:ok, updated} =
              item
              |> Ecto.Changeset.change(
                rating_sum: item.rating_sum + score,
                rating_count: item.rating_count + 1
              )
              |> Repo.update()

            json(conn, %{
              ok: true,
              avg_rating: LibraryItem.avg_rating(updated),
              rating_count: updated.rating_count
            })
        end
    end
  end

  # ──────────────────────────────────────────────────────────────────────────────
  # Private helpers
  # ──────────────────────────────────────────────────────────────────────────────

  defp base_query do
    from i in LibraryItem, order_by: [desc: i.inserted_at]
  end

  defp apply_category_filter(query, nil), do: query
  defp apply_category_filter(query, cat), do: where(query, [i], i.category == ^cat)

  defp apply_status_filter(query, nil), do: query
  defp apply_status_filter(query, status), do: where(query, [i], i.status == ^status)

  defp apply_visibility_filter(query, nil), do: query
  defp apply_visibility_filter(query, vis), do: where(query, [i], i.visibility == ^vis)

  defp apply_search_filter(query, nil), do: query
  defp apply_search_filter(query, ""), do: query

  defp apply_search_filter(query, search) do
    pattern = "%#{search}%"
    where(query, [i], ilike(i.name, ^pattern) or ilike(i.description, ^pattern))
  end

  defp apply_tags_filter(query, nil), do: query
  defp apply_tags_filter(query, ""), do: query

  defp apply_tags_filter(query, tags) when is_binary(tags) do
    tag_list = String.split(tags, ",", trim: true)
    where(query, [i], fragment("? && ?", i.tags, ^tag_list))
  end

  defp apply_tags_filter(query, tags) when is_list(tags) do
    where(query, [i], fragment("? && ?", i.tags, ^tags))
  end

  defp apply_sort(query, "popular"), do: order_by(query, [i], desc: i.install_count)
  defp apply_sort(query, "recent"), do: order_by(query, [i], desc: i.inserted_at)

  defp apply_sort(query, "rating") do
    order_by(query, [i],
      desc:
        fragment(
          "CASE WHEN ? > 0 THEN ?::float / ? ELSE 0 END",
          i.rating_count,
          i.rating_sum,
          i.rating_count
        )
    )
  end

  defp apply_sort(query, _), do: order_by(query, [i], desc: i.inserted_at)

  defp pagination_params(params) do
    page = max(parse_int(params["page"], 1), 1)
    per_page = min(parse_int(params["per_page"], 20), 100)
    {page, per_page}
  end

  defp existing_install(item_id, workspace_id) do
    Repo.get_by(LibraryInstall, library_item_id: item_id, workspace_id: workspace_id)
  end

  # Create the underlying entity based on category. Returns a serializable map
  # or nil when no side-effect entity is applicable.
  defp maybe_create_entity(%LibraryItem{category: "agent_template"} = item, workspace_id, params) do
    config = item.config
    overrides = params["config_overrides"] || %{}
    merged = Map.merge(config, overrides)

    slug =
      merged["slug"] ||
        String.downcase(item.slug) <>
          "_" <>
          (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower))

    attrs =
      merged
      |> Map.put("workspace_id", workspace_id)
      |> Map.put("slug", slug)
      |> Map.put_new("name", item.name)
      |> Map.put_new("role", "assistant")
      |> Map.put_new("adapter", "osa")
      |> Map.put_new("model", "claude-3-5-sonnet-20241022")
      |> Map.put_new("status", "sleeping")

    case %Agent{} |> Agent.changeset(attrs) |> Repo.insert() do
      {:ok, agent} -> %{type: "agent", id: agent.id, name: agent.name, slug: agent.slug}
      {:error, _} -> nil
    end
  end

  defp maybe_create_entity(%LibraryItem{category: "skill"} = item, workspace_id, params) do
    config = item.config
    overrides = params["config_overrides"] || %{}
    merged = Map.merge(config, overrides)

    attrs =
      merged
      |> Map.put("workspace_id", workspace_id)
      |> Map.put_new("name", item.name)
      |> Map.put_new("description", item.description || "")
      |> Map.put_new("category", item.subcategory || "Custom")
      |> Map.put_new("enabled", true)

    case %Skill{} |> Skill.changeset(attrs) |> Repo.insert() do
      {:ok, skill} -> %{type: "skill", id: skill.id, name: skill.name}
      {:error, _} -> nil
    end
  end

  defp maybe_create_entity(_item, _workspace_id, _params), do: nil

  defp serialize(%LibraryItem{} = i) do
    %{
      id: i.id,
      organization_id: i.organization_id,
      created_by_id: i.created_by_id,
      name: i.name,
      slug: i.slug,
      description: i.description,
      category: i.category,
      subcategory: i.subcategory,
      version: i.version,
      status: i.status,
      visibility: i.visibility,
      icon: i.icon,
      config: i.config,
      tags: i.tags,
      install_count: i.install_count,
      avg_rating: LibraryItem.avg_rating(i),
      rating_count: i.rating_count,
      dependencies: i.dependencies,
      changelog: i.changelog,
      readme: i.readme,
      inserted_at: i.inserted_at,
      updated_at: i.updated_at
    }
  end

  defp serialize_install(%LibraryInstall{} = install) do
    %{
      id: install.id,
      library_item_id: install.library_item_id,
      workspace_id: install.workspace_id,
      installed_by_id: install.installed_by_id,
      installed_version: install.installed_version,
      config_overrides: install.config_overrides,
      status: install.status,
      inserted_at: install.inserted_at,
      updated_at: install.updated_at,
      item: serialize_embedded_item(install)
    }
  end

  defp serialize_embedded_item(%LibraryInstall{library_item: %LibraryItem{} = item}),
    do: serialize(item)

  defp serialize_embedded_item(_), do: nil

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
