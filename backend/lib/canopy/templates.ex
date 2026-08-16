defmodule Canopy.Templates do
  @moduledoc """
  Public API for the Templates super-module.

  This is the operational data layer for **Forge**, Canopy's Template
  Composer agent. Exposes template CRUD, parameter-substituted preview,
  instantiation accounting, fork-from-workspace, publishing, and version
  diffing.

  ## Architecture

  ```
  Roberto / Forge ─call─▶ templates.* tools ─via─▶ this module
  Mustache renderer ─reads─▶ Template.body + parameters
  Instantiator ─writes─▶ Template Instantiation (audit row)
  Versioning ─snapshots─▶ Template Version (diff + body)
  Frontend /templates ─reads─▶ all of the above
  ```

  Forge's tool surface (`templates.*`) calls this module exclusively — no
  direct Repo access from tools.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Templates.Instantiation
  alias Canopy.Templates.Template
  alias Canopy.Templates.Version

  require Logger

  @default_template_limit 100
  @default_instantiation_limit 50
  @default_version_limit 50

  # ---------------------------------------------------------------------------
  # Templates
  # ---------------------------------------------------------------------------

  @doc """
  Lists templates with optional filters.

  Options:
  - `:kind` — filter to "workspace" / "persona" / "workflow"
  - `:verified` — boolean filter
  - `:published` — boolean filter
  - `:search` — substring match against name and description
  - `:tag` — single-tag match against tags array
  - `:limit` — default 100
  """
  @spec list_templates(keyword()) :: [Template.t()]
  def list_templates(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_template_limit)

    from(t in Template,
      order_by: [desc: t.popularity_count, asc: t.name],
      limit: ^limit
    )
    |> filter(:kind, opts[:kind])
    |> filter(:verified, opts[:verified])
    |> filter(:published, opts[:published])
    |> maybe_search(opts[:search])
    |> maybe_tag(opts[:tag])
    |> Repo.all()
  end

  @doc "Fetches a single template by slug. Raises if missing."
  @spec get_template!(String.t()) :: Template.t()
  def get_template!(slug), do: Repo.get_by!(Template, slug: slug)

  @doc "Fetches a single template by slug, returning nil on miss."
  @spec get_template(String.t()) :: Template.t() | nil
  def get_template(slug), do: Repo.get_by(Template, slug: slug)

  @doc "Creates a template."
  @spec create_template(map()) :: {:ok, Template.t()} | {:error, Ecto.Changeset.t()}
  def create_template(attrs) do
    %Template{} |> Template.changeset(attrs) |> Repo.insert()
  end

  @doc "Updates a template."
  @spec update_template(Template.t(), map()) ::
          {:ok, Template.t()} | {:error, Ecto.Changeset.t()}
  def update_template(%Template{} = template, attrs) do
    template |> Template.changeset(attrs) |> Repo.update()
  end

  @doc """
  Renders a parameter-substituted preview of a template body.

  Performs Mustache-style `{{var}}` rendering on every string field in the
  body recursively. Missing required parameters surface as
  `{:error, {:missing_parameters, [param_name, ...]}}`.

  Optional parameters fall through to declared defaults.
  """
  @spec preview_template(Template.t(), map()) ::
          {:ok, %{body: map(), resolved_params: map()}}
          | {:error, {:missing_parameters, [String.t()]}}
  def preview_template(%Template{} = template, params) do
    schema = template.parameters || %{}

    case resolve_params(schema, params) do
      {:ok, resolved} ->
        rendered = render_body(template.body || %{}, resolved)
        {:ok, %{body: rendered, resolved_params: resolved}}

      {:error, missing} ->
        {:error, {:missing_parameters, missing}}
    end
  end

  @doc """
  Records an instantiation event. Called by the instantiator after a
  successful (or partial / failed) template materialization.
  """
  @spec record_instantiation(map()) ::
          {:ok, Instantiation.t()} | {:error, Ecto.Changeset.t()}
  def record_instantiation(attrs) do
    case %Instantiation{} |> Instantiation.changeset(attrs) |> Repo.insert() do
      {:ok, inst} = ok ->
        bump_popularity(inst.template_slug)
        ok

      err ->
        err
    end
  end

  @doc """
  Lists instantiation records with optional filters.

  Options:
  - `:template_slug` — filter to one template
  - `:target_workspace_slug` — filter to one workspace
  - `:status` — filter to "pending" / "success" / "partial" / "failed"
  - `:limit` — default 50
  """
  @spec list_instantiations(keyword()) :: [Instantiation.t()]
  def list_instantiations(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_instantiation_limit)

    from(i in Instantiation,
      order_by: [desc: i.inserted_at],
      limit: ^limit
    )
    |> filter(:template_slug, opts[:template_slug])
    |> filter(:target_workspace_slug, opts[:target_workspace_slug])
    |> filter(:status, opts[:status])
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Versions / publishing
  # ---------------------------------------------------------------------------

  @doc """
  Publishes a template. Snapshots the current body + parameters into a
  template_versions row, sets `:published` to true, and (optionally) bumps
  the version string.
  """
  @spec publish_template(Template.t(), keyword()) ::
          {:ok, %{template: Template.t(), version: Version.t()}}
          | {:error, term()}
  def publish_template(%Template{} = template, opts \\ []) do
    version_str = Keyword.get(opts, :version, template.version)
    changelog = Keyword.get(opts, :changelog)
    authored_by = Keyword.get(opts, :authored_by)
    authored_by_agent_id = Keyword.get(opts, :authored_by_agent_id)

    diff = compute_version_diff(template, version_str)

    Repo.transaction(fn ->
      with {:ok, updated} <-
             update_template(template, %{
               version: version_str,
               published: true
             }),
           {:ok, version} <-
             create_version(%{
               template_id: updated.id,
               version: version_str,
               diff: diff,
               body_snapshot: updated.body || %{},
               parameters_snapshot: updated.parameters || %{},
               changelog: changelog,
               sha256: body_sha256(updated.body),
               authored_by: authored_by,
               authored_by_agent_id: authored_by_agent_id
             }) do
        %{template: updated, version: version}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Forks a template — creates a new template that records its parent.
  Optionally accepts overrides for the new slug, name, body, and
  parameters.
  """
  @spec fork_template(Template.t(), map()) ::
          {:ok, Template.t()} | {:error, Ecto.Changeset.t()}
  def fork_template(%Template{} = parent, attrs) do
    forked_attrs =
      attrs
      |> Map.put_new(:kind, parent.kind)
      |> Map.put_new(:body, parent.body)
      |> Map.put_new(:parameters, parent.parameters)
      |> Map.put_new(:description, parent.description)
      |> Map.put(:parent_template_id, parent.id)
      |> Map.put(:forked_from_slug, parent.slug)
      |> Map.put(:verified, false)
      |> Map.put(:published, false)
      |> Map.put_new(:version, "0.1.0")

    create_template(forked_attrs)
  end

  @doc "Lists prior versions of a template."
  @spec list_versions(Ecto.UUID.t(), keyword()) :: [Version.t()]
  def list_versions(template_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_version_limit)

    from(v in Version,
      where: v.template_id == ^template_id,
      order_by: [desc: v.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc "Creates a version snapshot row."
  @spec create_version(map()) :: {:ok, Version.t()} | {:error, Ecto.Changeset.t()}
  def create_version(attrs) do
    %Version{} |> Version.changeset(attrs) |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter(query, _field, nil), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, term) when is_binary(term) do
    pattern = "%" <> String.downcase(term) <> "%"

    from(q in query,
      where:
        ilike(q.name, ^pattern) or
          ilike(fragment("coalesce(?, '')", q.description), ^pattern) or
          ilike(q.slug, ^pattern)
    )
  end

  defp maybe_tag(query, nil), do: query
  defp maybe_tag(query, ""), do: query

  defp maybe_tag(query, tag) when is_binary(tag) do
    from(q in query, where: ^tag in q.tags)
  end

  defp bump_popularity(nil), do: :ok
  defp bump_popularity(""), do: :ok

  defp bump_popularity(slug) when is_binary(slug) do
    from(t in Template, where: t.slug == ^slug)
    |> Repo.update_all(inc: [popularity_count: 1])

    :ok
  rescue
    err ->
      Logger.warning("[Templates] popularity bump failed: #{inspect(err)}")
      :ok
  end

  # ── Parameter resolution ──────────────────────────────────────────────────

  defp resolve_params(schema, supplied) when is_map(schema) and is_map(supplied) do
    {resolved, missing} =
      Enum.reduce(schema, {%{}, []}, fn {name, decl}, {acc, miss} ->
        decl = decl_to_map(decl)
        provided = Map.get(supplied, name) || Map.get(supplied, to_string(name))
        default = Map.get(decl, "default")
        required? = Map.get(decl, "required", false)

        cond do
          not is_nil(provided) ->
            {Map.put(acc, to_string(name), provided), miss}

          not is_nil(default) ->
            {Map.put(acc, to_string(name), default), miss}

          required? ->
            {acc, [to_string(name) | miss]}

          true ->
            {acc, miss}
        end
      end)

    extra =
      supplied
      |> Map.drop(Map.keys(schema) ++ Enum.map(schema, fn {k, _} -> to_string(k) end))
      |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)

    final = Map.merge(extra, resolved)

    case missing do
      [] -> {:ok, final}
      missing -> {:error, Enum.reverse(missing)}
    end
  end

  defp resolve_params(_, _), do: {:ok, %{}}

  defp decl_to_map(decl) when is_map(decl), do: decl
  defp decl_to_map(_), do: %{}

  # ── Mustache-style rendering ──────────────────────────────────────────────

  @mustache ~r/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/

  defp render_body(body, params) when is_map(body) do
    Enum.into(body, %{}, fn {k, v} -> {k, render_value(v, params)} end)
  end

  defp render_body(other, _params), do: other

  defp render_value(v, params) when is_binary(v), do: render_string(v, params)

  defp render_value(v, params) when is_list(v), do: Enum.map(v, &render_value(&1, params))

  defp render_value(v, params) when is_map(v) do
    Enum.into(v, %{}, fn {k, v2} -> {k, render_value(v2, params)} end)
  end

  defp render_value(v, _params), do: v

  defp render_string(str, params) when is_binary(str) do
    Regex.replace(@mustache, str, fn _, name ->
      case Map.get(params, name) do
        nil -> "{{" <> name <> "}}"
        value -> to_string(value)
      end
    end)
  end

  # ── Diff + hashing ────────────────────────────────────────────────────────

  defp compute_version_diff(%Template{id: id, body: body}, new_version) do
    case Repo.one(
           from v in Version,
             where: v.template_id == ^id,
             order_by: [desc: v.inserted_at],
             limit: 1
         ) do
      nil ->
        %{"first_version" => true, "version" => new_version}

      previous ->
        %{
          "previous_version" => previous.version,
          "new_version" => new_version,
          "changed_keys" =>
            body
            |> map_keys_changed(previous.body_snapshot || %{})
            |> Enum.map(&to_string/1)
        }
    end
  end

  defp map_keys_changed(a, b) when is_map(a) and is_map(b) do
    keys_a = MapSet.new(Map.keys(a))
    keys_b = MapSet.new(Map.keys(b))

    added = MapSet.difference(keys_a, keys_b) |> MapSet.to_list()
    removed = MapSet.difference(keys_b, keys_a) |> MapSet.to_list()

    modified =
      keys_a
      |> MapSet.intersection(keys_b)
      |> MapSet.to_list()
      |> Enum.filter(fn k -> Map.get(a, k) != Map.get(b, k) end)

    added ++ removed ++ modified
  end

  defp map_keys_changed(_, _), do: []

  defp body_sha256(nil), do: nil
  defp body_sha256(body) when is_map(body) do
    body
    |> Jason.encode!()
    |> then(fn s -> :crypto.hash(:sha256, s) end)
    |> Base.encode16(case: :lower)
  end
end
