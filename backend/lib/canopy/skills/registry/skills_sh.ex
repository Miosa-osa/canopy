defmodule Canopy.Skills.Registry.SkillsSh do
  @moduledoc """
  HTTP client for the Skills.sh skills registry.

  Skills.sh hosts community-contributed agent skills in markdown format.
  Skills are fetched as JSON with `slug`, `name`, `description`, `content`, and `tags`.

  If `SKILLS_SH_URL` is unset or the registry is unreachable, all functions return
  empty results gracefully — the caller (mix task, import API) handles the no-op.
  """

  require Logger

  @default_url "https://skills.sh/api/v1/skills"

  @doc """
  Fetches all skills from Skills.sh.

  Returns `{:ok, [map()]}` on success, `{:ok, []}` when unconfigured or
  the registry is unreachable.
  """
  @spec fetch_all() :: {:ok, [map()]}
  def fetch_all do
    base_url()
    |> fetch("/")
    |> normalize_list()
  end

  @doc """
  Fetches a single skill by slug from Skills.sh.

  Returns `{:ok, map()}` or `{:ok, nil}` when not found.
  """
  @spec fetch_by_slug(String.t()) :: {:ok, map() | nil}
  def fetch_by_slug(slug) do
    base_url()
    |> fetch("/#{slug}")
    |> normalize_single()
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec base_url() :: String.t() | nil
  defp base_url do
    Application.get_env(:canopy, :skills_sh_url, @default_url)
  end

  @spec fetch(String.t() | nil, String.t()) :: {:ok, term()} | {:error, term()}
  defp fetch(nil, _), do: {:error, :not_configured}

  defp fetch(base, path) do
    url = base <> path

    case Req.get(url, receive_timeout: 10_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        Logger.warning("[SkillsSh] unexpected status #{status} for #{url}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.warning("[SkillsSh] request failed for #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec normalize_list({:ok, term()} | {:error, term()}) :: {:ok, [map()]}
  defp normalize_list({:ok, items}) when is_list(items), do: {:ok, items}
  defp normalize_list({:ok, %{"data" => items}}) when is_list(items), do: {:ok, items}
  defp normalize_list(_), do: {:ok, []}

  @spec normalize_single({:ok, term()} | {:error, term()}) :: {:ok, map() | nil}
  defp normalize_single({:ok, item}) when is_map(item), do: {:ok, item}
  defp normalize_single({:ok, %{"data" => item}}) when is_map(item), do: {:ok, item}
  defp normalize_single(_), do: {:ok, nil}
end
