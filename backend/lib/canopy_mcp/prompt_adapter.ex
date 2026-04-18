defmodule CanopyMCP.PromptAdapter do
  @moduledoc """
  Exposes hired Canopy agent personas as callable MCP prompts.

  Each hired agent becomes a prompt an MCP client can invoke:

      prompts/get {"name": "agent.product-manager", "arguments": {"context": "..."}}

  Only hired agents are exposed. Unhired agents are invisible to MCP clients.

  ## Prompt naming

  Prompt names follow the pattern `agent.<slug>` where `<slug>` is the
  agent's DB slug (e.g. `"agent.senior-backend-engineer"`). The dot-prefixed
  namespace keeps agent prompts grouped in client UIs that sort by name.

  ## Argument injection

  Each prompt accepts a single optional argument `"context"`. When provided it
  is prepended as a user message before the system persona, giving the client
  a way to anchor the persona to a specific domain without modifying the
  underlying persona markdown.
  """

  alias Canopy.Agents

  @prompt_prefix "agent."

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns a list of MCP prompt descriptors, one per hired agent.

  Each descriptor has the shape:

      %{
        "name"        => "agent.product-manager",
        "description" => "Product manager persona ...",
        "arguments"   => [
          %{"name" => "context", "description" => "Domain context to inject", "required" => false}
        ]
      }
  """
  @spec list_prompts() :: [map()]
  def list_prompts do
    case Agents.list(hired: true) do
      {:ok, agents} -> Enum.map(agents, &agent_to_prompt_descriptor/1)
      _error -> []
    end
  end

  @doc """
  Returns the messages array for a named prompt, optionally injecting `arguments`.

  `name` must follow the `"agent.<slug>"` convention.
  `arguments` is a string-keyed map. The key `"context"` injects a user turn.

  Returns `{:ok, prompt_result}` on success:

      %{
        "description" => "...",
        "messages"    => [
          %{"role" => "user",   "content" => %{"type" => "text", "text" => context}},
          %{"role" => "system", "content" => %{"type" => "text", "text" => persona_markdown}}
        ]
      }

  Returns `{:error, :not_found}` when the name is unknown or the agent is not hired.
  """
  @spec get_prompt(String.t(), map()) :: {:ok, map()} | {:error, :not_found}
  def get_prompt(name, arguments) when is_binary(name) and is_map(arguments) do
    case slug_from_name(name) do
      {:ok, slug} ->
        case Agents.get_by_slug(slug) do
          {:ok, %{hired: true} = agent} ->
            {:ok, build_prompt_result(agent, arguments)}

          {:ok, %{hired: false}} ->
            {:error, :not_found}

          {:error, :not_found} ->
            {:error, :not_found}
        end

      :error ->
        {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — descriptor construction
  # ---------------------------------------------------------------------------

  @spec agent_to_prompt_descriptor(Canopy.Agents.Agent.t()) :: map()
  defp agent_to_prompt_descriptor(agent) do
    %{
      "name" => prompt_name(agent.slug),
      "description" => agent.description || "#{agent.name} persona",
      "arguments" => [
        %{
          "name" => "context",
          "description" => "Domain context to inject as a user turn before the persona",
          "required" => false
        }
      ]
    }
  end

  # ---------------------------------------------------------------------------
  # Private — prompt result construction
  # ---------------------------------------------------------------------------

  @spec build_prompt_result(Canopy.Agents.Agent.t(), map()) :: map()
  defp build_prompt_result(agent, arguments) do
    context = Map.get(arguments, "context", "")

    system_message = %{
      "role" => "system",
      "content" => %{"type" => "text", "text" => agent.persona_markdown || ""}
    }

    messages =
      if context != "" do
        user_message = %{
          "role" => "user",
          "content" => %{"type" => "text", "text" => context}
        }

        [user_message, system_message]
      else
        [system_message]
      end

    %{
      "description" => agent.description || "#{agent.name} persona",
      "messages" => messages
    }
  end

  # ---------------------------------------------------------------------------
  # Private — name <-> slug mapping
  # ---------------------------------------------------------------------------

  @spec prompt_name(String.t()) :: String.t()
  defp prompt_name(slug), do: @prompt_prefix <> slug

  @spec slug_from_name(String.t()) :: {:ok, String.t()} | :error
  defp slug_from_name(@prompt_prefix <> slug) when slug != "", do: {:ok, slug}
  defp slug_from_name(_name), do: :error
end
