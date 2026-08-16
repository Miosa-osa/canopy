defmodule Canopy.Docs do
  @moduledoc """
  Public context for the Docs module.

  Manages doc_folders and documents. No versions, no optimistic lock.
  body_text is derived inline from body_json on every write.
  """

  import Ecto.Query, only: [from: 2, where: 3]

  require Logger

  alias Canopy.Docs.{Document, Folder}
  alias Canopy.Governance.Reviewer
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # Folder CRUD
  # ---------------------------------------------------------------------------

  @doc "Returns all non-archived folders for a workspace, ordered by sort_order, name."
  @spec list_folders(String.t()) :: [Folder.t()]
  def list_folders(workspace_slug) do
    Repo.all(
      from f in Folder,
        where: f.workspace_slug == ^workspace_slug and is_nil(f.archived_at),
        order_by: [asc: f.sort_order, asc: f.name]
    )
  end

  @doc """
  Returns a nested folder tree for a workspace.

  Each folder map has a `:children` key containing its immediate child folders.
  """
  @spec get_folder_tree(String.t()) :: [map()]
  def get_folder_tree(workspace_slug) do
    folders = list_folders(workspace_slug)
    build_tree(folders, nil)
  end

  @doc "Creates a folder. Returns `{:ok, folder}` or `{:error, changeset}`."
  @spec create_folder(map()) :: {:ok, Folder.t()} | {:error, Ecto.Changeset.t()}
  def create_folder(attrs) do
    %Folder{}
    |> Folder.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a folder. Returns `{:ok, folder}` or `{:error, changeset}`."
  @spec update_folder(Folder.t(), map()) :: {:ok, Folder.t()} | {:error, Ecto.Changeset.t()}
  def update_folder(%Folder{} = folder, attrs) do
    folder
    |> Folder.changeset(attrs)
    |> Repo.update()
  end

  @doc "Archives a folder (soft-delete). Returns `{:ok, folder}` or `{:error, :not_found}`."
  @spec archive_folder(String.t()) :: {:ok, Folder.t()} | {:error, :not_found}
  def archive_folder(id) do
    case Repo.get(Folder, id) do
      nil -> {:error, :not_found}
      folder -> Repo.update(Folder.archive_changeset(folder))
    end
  end

  @doc "Gets a folder by id. Returns `{:ok, folder}` or `{:error, :not_found}`."
  @spec get_folder(String.t()) :: {:ok, Folder.t()} | {:error, :not_found}
  def get_folder(id) do
    case Repo.get(Folder, id) do
      nil -> {:error, :not_found}
      folder -> {:ok, folder}
    end
  end

  # ---------------------------------------------------------------------------
  # Document CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Lists documents with optional filters.

  Accepted filter keys (all optional):
  - `folder_id`, `author_id`, `tag`, `published`, `workspace_slug`, `text_query`, `archived`
  """
  @spec list_documents(map()) :: [Document.t()]
  def list_documents(filters \\ %{}) do
    base =
      from d in Document,
        order_by: [desc: d.updated_at]

    base
    |> maybe_filter_workspace(filters)
    |> maybe_filter_folder(filters)
    |> maybe_filter_author(filters)
    |> maybe_filter_tag(filters)
    |> maybe_filter_published(filters)
    |> maybe_filter_archived(filters)
    |> maybe_full_text_search(filters)
    |> Repo.all()
  end

  @doc """
  Gets a document by id or by `{slug, workspace_slug}` tuple.

  Returns `{:ok, document}` or `{:error, :not_found}`.
  """
  @spec get(String.t() | {String.t(), String.t()}) ::
          {:ok, Document.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case Repo.get(Document, id) do
      nil -> {:error, :not_found}
      doc -> {:ok, doc}
    end
  end

  def get({slug, workspace_slug}) do
    case Repo.one(
           from d in Document,
             where: d.slug == ^slug and d.workspace_slug == ^workspace_slug
         ) do
      nil -> {:error, :not_found}
      doc -> {:ok, doc}
    end
  end

  @doc """
  Creates a document.

  `body_text` is derived from `body_json` — do not supply it in attrs.

  If a `:requires_review` governance rule matches (based on workspace, author_type,
  and artifact_type "doc"), the document is inserted with `review_id` set and the
  caller receives `{:ok, doc}` — the doc is live but carries the review reference
  so list views can show the "Under review" pill.
  """
  @spec create(map()) :: {:ok, Document.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    result =
      %Document{}
      |> Document.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, doc} ->
        # Check governance: only agent-authored docs trigger review gate.
        author_type = Map.get(attrs, :author_type) || Map.get(attrs, "author_type")
        agent_id = Map.get(attrs, :author_id) || Map.get(attrs, "author_id")

        review_result =
          if author_type == "agent" do
            Reviewer.maybe_request_review(:artifact, %{
              workspace_slug: doc.workspace_slug,
              artifact_type: "doc",
              artifact_id: doc.id,
              artifact_preview: doc.title,
              agent_id: agent_id,
              session_id: nil
            })
          else
            :no_review_required
          end

        case review_result do
          {:review_pending, review_id} ->
            case doc
                 |> Document.changeset(%{review_id: review_id})
                 |> Repo.update() do
              {:ok, updated} -> {:ok, updated}
              # Fail open: review was created but we couldn't stamp the doc.
              {:error, _} -> {:ok, doc}
            end

          :no_review_required ->
            {:ok, doc}
        end

      error ->
        error
    end
  end

  @doc """
  Updates a document. No optimistic lock; last writer wins.

  `body_text` is re-derived from `body_json` on every update.
  """
  @spec update(Document.t(), map()) ::
          {:ok, Document.t()} | {:error, Ecto.Changeset.t()}
  def update(%Document{} = doc, attrs) do
    doc
    |> Document.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Publishes a document. Returns `{:ok, doc}` or `{:error, :not_found}`."
  @spec publish(String.t()) :: {:ok, Document.t()} | {:error, :not_found}
  def publish(id) do
    with {:ok, doc} <- get(id) do
      doc
      |> Document.publish_changeset()
      |> Repo.update()
    end
  end

  @doc "Unpublishes a document. Returns `{:ok, doc}` or `{:error, :not_found}`."
  @spec unpublish(String.t()) :: {:ok, Document.t()} | {:error, :not_found}
  def unpublish(id) do
    with {:ok, doc} <- get(id) do
      doc
      |> Document.unpublish_changeset()
      |> Repo.update()
    end
  end

  @doc "Archives a document (soft-delete). Returns `{:ok, doc}` or `{:error, :not_found}`."
  @spec archive(String.t()) :: {:ok, Document.t()} | {:error, :not_found}
  def archive(id) do
    with {:ok, doc} <- get(id) do
      doc
      |> Document.archive_changeset()
      |> Repo.update()
    end
  end

  @doc "Unarchives a document. Returns `{:ok, doc}` or `{:error, :not_found}`."
  @spec unarchive(String.t()) :: {:ok, Document.t()} | {:error, :not_found}
  def unarchive(id) do
    with {:ok, doc} <- get(id) do
      doc
      |> Document.unarchive_changeset()
      |> Repo.update()
    end
  end

  @doc "Hard-deletes a document. Returns `{:ok, doc}` or `{:error, :not_found}`."
  @spec delete(String.t()) :: {:ok, Document.t()} | {:error, :not_found}
  def delete(id) do
    with {:ok, doc} <- get(id) do
      Repo.delete(doc)
    end
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  @doc "Full-text search over documents in a workspace using PostgreSQL `to_tsvector`."
  @spec search(String.t(), String.t()) :: [Document.t()]
  def search(workspace_slug, query) when is_binary(query) and query != "" do
    Repo.all(
      from d in Document,
        where:
          d.workspace_slug == ^workspace_slug and
            is_nil(d.archived_at) and
            fragment(
              "to_tsvector('english', ?) @@ plainto_tsquery('english', ?)",
              d.body_text,
              ^query
            ),
        order_by: [
          desc:
            fragment(
              "ts_rank(to_tsvector('english', ?), plainto_tsquery('english', ?))",
              d.body_text,
              ^query
            )
        ]
    )
  end

  def search(_workspace_slug, _query), do: []

  # ---------------------------------------------------------------------------
  # Private — body_text extraction (inlined from deleted BodyExtractor)
  # ---------------------------------------------------------------------------

  @doc false
  def extract_body_text(nil), do: ""
  def extract_body_text(doc) when not is_map(doc), do: ""

  def extract_body_text(doc) do
    doc
    |> walk_body()
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
  end

  defp walk_body(%{"type" => "doc"} = node), do: walk_body_children(node)
  defp walk_body(%{"type" => "paragraph"} = node), do: [walk_body_children(node), "\n"]
  defp walk_body(%{"type" => "heading"} = node), do: [walk_body_children(node), "\n"]
  defp walk_body(%{"type" => "bulletList"} = node), do: walk_body_children(node)
  defp walk_body(%{"type" => "orderedList"} = node), do: walk_body_children(node)
  defp walk_body(%{"type" => "listItem"} = node), do: [walk_body_children(node), "\n"]
  defp walk_body(%{"type" => "codeBlock"} = node), do: [walk_body_children(node), "\n"]
  defp walk_body(%{"type" => "blockquote"} = node), do: walk_body_children(node)
  defp walk_body(%{"type" => "text", "text" => text}) when is_binary(text), do: text
  defp walk_body(_node), do: []

  defp walk_body_children(%{"content" => children}) when is_list(children) do
    Enum.map(children, &walk_body/1)
  end

  defp walk_body_children(_node), do: []

  # ---------------------------------------------------------------------------
  # Private — filter helpers
  # ---------------------------------------------------------------------------

  defp maybe_filter_workspace(query, %{"workspace_slug" => ws}) when is_binary(ws) do
    where(query, [d], d.workspace_slug == ^ws)
  end

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws) do
    where(query, [d], d.workspace_slug == ^ws)
  end

  defp maybe_filter_workspace(query, _), do: query

  defp maybe_filter_folder(query, %{"folder_id" => fid}) when is_binary(fid) do
    where(query, [d], d.folder_id == ^fid)
  end

  defp maybe_filter_folder(query, %{folder_id: fid}) when is_binary(fid) do
    where(query, [d], d.folder_id == ^fid)
  end

  defp maybe_filter_folder(query, _), do: query

  defp maybe_filter_author(query, %{"author_id" => aid}) when is_binary(aid) do
    where(query, [d], d.author_id == ^aid)
  end

  defp maybe_filter_author(query, %{author_id: aid}) when is_binary(aid) do
    where(query, [d], d.author_id == ^aid)
  end

  defp maybe_filter_author(query, _), do: query

  defp maybe_filter_tag(query, %{"tag" => tag}) when is_binary(tag) do
    where(query, [d], ^tag in d.tags)
  end

  defp maybe_filter_tag(query, %{tag: tag}) when is_binary(tag) do
    where(query, [d], ^tag in d.tags)
  end

  defp maybe_filter_tag(query, _), do: query

  defp maybe_filter_published(query, %{"published" => true}),
    do: where(query, [d], d.published == true)

  defp maybe_filter_published(query, %{published: true}),
    do: where(query, [d], d.published == true)

  defp maybe_filter_published(query, %{"published" => false}),
    do: where(query, [d], d.published == false)

  defp maybe_filter_published(query, %{published: false}),
    do: where(query, [d], d.published == false)

  defp maybe_filter_published(query, _), do: query

  defp maybe_filter_archived(query, %{"archived" => true}), do: query
  defp maybe_filter_archived(query, %{archived: true}), do: query
  defp maybe_filter_archived(query, _), do: where(query, [d], is_nil(d.archived_at))

  defp maybe_full_text_search(query, %{"text_query" => q}) when is_binary(q) and q != "" do
    where(
      query,
      [d],
      fragment(
        "to_tsvector('english', ?) @@ plainto_tsquery('english', ?)",
        d.body_text,
        ^q
      )
    )
  end

  defp maybe_full_text_search(query, %{text_query: q}) when is_binary(q) and q != "" do
    where(
      query,
      [d],
      fragment(
        "to_tsvector('english', ?) @@ plainto_tsquery('english', ?)",
        d.body_text,
        ^q
      )
    )
  end

  defp maybe_full_text_search(query, _), do: query

  # ---------------------------------------------------------------------------
  # Private — tree builder
  # ---------------------------------------------------------------------------

  @tree_fields ~w(id name parent_id workspace_slug owner_user_id owner_agent_slug
                  color sort_order archived_at inserted_at updated_at)a

  defp build_tree(folders, parent_id) do
    folders
    |> Enum.filter(fn f -> f.parent_id == parent_id end)
    |> Enum.map(fn f ->
      children = build_tree(folders, f.id)
      base = Map.take(f, @tree_fields)
      Map.put(base, :children, children)
    end)
    |> Enum.sort_by(& &1.sort_order)
  end
end
