defmodule Canopy.Workspaces do
  @moduledoc """
  Public API for Canopy workspace management.

  A workspace is a directory on the user's filesystem (or MIOSA sandbox) that
  follows the Canopy Workspace Protocol: structured markdown folders defining
  org context, goals, agent assignments, and active tasks.

  Week 3 additions:
  - `delete/1` — soft-delete flag (no disk mutation)
  - `list_templates/0` — returns the 4 built-in starter templates
  - `create_from_template/3` — materialises template files on disk, then inserts DB row
  - `create/1` — extended to also create `root_path` dir + SYSTEM.md template if missing
  """

  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  @templates_dir Application.app_dir(:canopy, "priv/workspace_templates")

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Returns all workspaces (not soft-deleted), ordered by name."
  @spec list() :: {:ok, [Workspace.t()]}
  def list do
    import Ecto.Query
    workspaces = Repo.all(from w in Workspace, where: is_nil(w.deleted_at), order_by: w.name)
    {:ok, workspaces}
  end

  @doc "Returns a workspace by slug, or `{:error, :not_found}`."
  @spec get_by_slug(String.t()) :: {:ok, Workspace.t()} | {:error, :not_found}
  def get_by_slug(slug) do
    import Ecto.Query

    case Repo.one(from w in Workspace, where: w.slug == ^slug and is_nil(w.deleted_at)) do
      nil -> {:error, :not_found}
      workspace -> {:ok, workspace}
    end
  end

  # ---------------------------------------------------------------------------
  # Mutations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new workspace from the given attrs.

  If the `root_path` directory does not exist it is created. A minimal
  `SYSTEM.md` is written if not already present.

  Returns `{:ok, workspace}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Workspace.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    changeset = Workspace.changeset(%Workspace{}, attrs)

    if changeset.valid? do
      root_path = Ecto.Changeset.get_field(changeset, :root_path)
      name = Ecto.Changeset.get_field(changeset, :name)

      with :ok <- ensure_root_path(root_path),
           :ok <- ensure_system_md(root_path, name) do
        Repo.insert(changeset)
      else
        {:error, reason} -> {:error, reason}
      end
    else
      Repo.insert(changeset)
    end
  end

  @doc """
  Soft-deletes a workspace by setting its `deleted_at` timestamp.

  Does not touch the filesystem. Returns `{:ok, workspace}` or
  `{:error, :not_found}`.
  """
  @spec delete(String.t()) :: {:ok, Workspace.t()} | {:error, :not_found}
  def delete(slug) do
    with {:ok, workspace} <- get_by_slug(slug) do
      workspace
      |> Workspace.delete_changeset()
      |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Templates
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of available starter templates.

  Each entry is:

      %{slug: binary, name: binary, description: binary, files: [binary]}

  `files` is a sorted list of relative file paths inside the template directory.
  """
  @spec list_templates() :: [map()]
  def list_templates do
    [
      %{
        slug: "sales-engine",
        name: "Sales Engine",
        description: "Pipeline management, outreach, and CRM-style workspace for sales teams.",
        files: template_files("sales-engine")
      },
      %{
        slug: "dev-shop",
        name: "Dev Shop",
        description:
          "Software development workspace with engineering standards, runbooks, and CI reference.",
        files: template_files("dev-shop")
      },
      %{
        slug: "content-factory",
        name: "Content Factory",
        description:
          "Content production workspace with editorial calendar, scripts, and publishing SOPs.",
        files: template_files("content-factory")
      },
      %{
        slug: "blank",
        name: "Blank",
        description: "Minimal workspace — SYSTEM.md and company.yaml only.",
        files: template_files("blank")
      }
    ]
  end

  @doc """
  Creates a workspace from a template.

  Materialises the template files under `root_path`, then inserts a DB row
  with the given `slug`. The workspace `template` field is set to
  `template_slug`.

  Returns `{:ok, %Workspace{}}` or `{:error, term}`.
  """
  @spec create_from_template(String.t(), String.t(), String.t()) ::
          {:ok, Workspace.t()} | {:error, term()}
  def create_from_template(slug, template_slug, root_path) do
    src_dir = Path.join(@templates_dir, template_slug)

    if File.dir?(src_dir) do
      name = humanize_slug(slug)

      with :ok <- copy_template(src_dir, root_path) do
        create(%{
          slug: slug,
          name: name,
          root_path: root_path,
          template: template_slug
        })
      end
    else
      {:error, :unknown_template}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp ensure_root_path(nil), do: :ok

  defp ensure_root_path(root_path) do
    case File.mkdir_p(root_path) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_system_md(nil, _name), do: :ok

  defp ensure_system_md(root_path, name) do
    system_md = Path.join(root_path, "SYSTEM.md")

    if File.exists?(system_md) do
      :ok
    else
      content = default_system_md(name || "Workspace")

      case File.write(system_md, content) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp copy_template(src_dir, dst_dir) do
    with :ok <- File.mkdir_p(dst_dir) do
      src_dir
      |> walk_files()
      |> Enum.reduce_while(:ok, fn rel_path, :ok ->
        src = Path.join(src_dir, rel_path)
        dst = Path.join(dst_dir, rel_path)

        with :ok <- File.mkdir_p(Path.dirname(dst)),
             {:ok, content} <- File.read(src),
             :ok <- File.write(dst, content) do
          {:cont, :ok}
        else
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp walk_files(dir) do
    case File.ls(dir) do
      {:ok, names} ->
        Enum.flat_map(names, fn name ->
          full = Path.join(dir, name)

          if File.dir?(full) do
            Enum.map(walk_files(full), &Path.join(name, &1))
          else
            [name]
          end
        end)

      {:error, _reason} ->
        []
    end
  end

  defp template_files(slug) do
    dir = Path.join(@templates_dir, slug)

    if File.dir?(dir) do
      dir |> walk_files() |> Enum.sort()
    else
      []
    end
  end

  defp humanize_slug(slug) do
    slug
    |> String.split("-")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp default_system_md(name) do
    """
    # #{name}

    > A Canopy workspace following the Workspace Protocol.

    ## Identity

    This workspace is named **#{name}**. It operates as a general-purpose workspace.

    ## Boot Sequence

    1. Read this SYSTEM.md — understand context and operating rules.
    2. Discover available skills in `skills/` — each subfolder has a `SKILL.md`.
    3. Discover available agents in `agents/` — each `.md` file is a specialist.
    4. Review `reference/` for domain knowledge.

    ## Core Loop

    ```
    RECEIVE  → Read input
    CLASSIFY → What is it? (task, question, update)
    ACT      → Execute the appropriate skill or agent
    VERIFY   → Confirm completion
    PERSIST  → Update relevant files
    ```

    ## Skills

    No skills defined yet. Add them to `skills/{name}/SKILL.md`.

    ## Agents

    No agents defined yet. Add them to `agents/{name}.md`.

    ## Quality Rules

    - Keep SYSTEM.md concise — it is loaded on every boot.
    - Store domain knowledge in `reference/`, not here.
    - One skill per folder. One agent per file.
    """
  end
end
