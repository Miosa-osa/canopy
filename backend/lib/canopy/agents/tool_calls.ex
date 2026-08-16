defmodule Canopy.Agents.ToolCalls do
  @moduledoc """
  Read-side context for agent tool call audit records.

  Write path lives in `Canopy.Agents.Tools` which records a row on every
  `execute/3` call. This module provides list/get for the review UI and
  debug page.
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Canopy.Agents.ToolCall
  alias Canopy.Repo

  @spec list(map()) :: [ToolCall.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(tc in ToolCall, order_by: [desc: tc.inserted_at], limit: ^limit)
    |> maybe_filter_agent(filters)
    |> maybe_filter_session(filters)
    |> maybe_filter_status(filters)
    |> Repo.all()
  end

  @spec get(String.t()) :: {:ok, ToolCall.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case Repo.get(ToolCall, id) do
      nil -> {:error, :not_found}
      tc -> {:ok, tc}
    end
  end

  # ---------------------------------------------------------------------------
  # Private query helpers
  # ---------------------------------------------------------------------------

  defp maybe_filter_agent(query, %{agent_id: agent_id}) when is_binary(agent_id),
    do: where(query, [tc], tc.agent_id == ^agent_id)

  defp maybe_filter_agent(query, _), do: query

  defp maybe_filter_session(query, %{session_id: sid}) when is_binary(sid),
    do: where(query, [tc], tc.session_id == ^sid)

  defp maybe_filter_session(query, _), do: query

  defp maybe_filter_status(query, %{status: status}) when is_binary(status),
    do: where(query, [tc], tc.status == ^status)

  defp maybe_filter_status(query, _), do: query
end
