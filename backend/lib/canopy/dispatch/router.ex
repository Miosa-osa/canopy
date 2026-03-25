defmodule Canopy.Dispatch.Router do
  @moduledoc """
  Dynamic adapter routing based on task content and requirements.

  When an agent delegates work, the router analyzes the task to pick
  the optimal runtime adapter. Priority order:

    1. Explicit `adapter_override` on the task/issue
    2. Task-type routing rules (label-based)
    3. Content analysis (keyword regex)
    4. Agent's default adapter

  All paths are nil-safe. Unknown or unresolvable adapters fall back to
  the agent's default rather than raising.
  """

  require Logger

  @doc """
  Resolve the best adapter module for a given task and agent.

  `task` is an Issue struct (or any map with `:adapter_override`, `:title`,
  `:description`, `:labels`). `agent` is an Agent struct with an `:adapter` field.

  Returns `{:ok, adapter_module}` on success, `{:error, reason}` if even the
  agent default cannot be resolved (misconfigured agent).
  """
  @spec resolve(map(), map()) :: {:ok, module()} | {:error, term()}
  def resolve(task, agent) do
    task_adapter_type = get_task_adapter(task)

    result =
      cond do
        # 1. Explicit adapter override on the task
        task_adapter_type ->
          case Canopy.Adapter.resolve(task_adapter_type) do
            {:ok, mod} ->
              Logger.debug("[Dispatch.Router] Task override → #{task_adapter_type}")
              {:ok, mod}

            {:error, _} ->
              Logger.warning(
                "[Dispatch.Router] Unknown override adapter #{inspect(task_adapter_type)}, falling back"
              )

              nil
          end

        # 2 + 3. Label/content matching
        true ->
          with nil <- match_by_task_type(task),
               nil <- match_by_content(task) do
            nil
          end
      end

    case result do
      {:ok, _} = ok ->
        ok

      nil ->
        # Fall back to agent default
        Canopy.Adapter.resolve(agent.adapter)
    end
  end

  @doc """
  Public entry point for content matching — used by Delegation to infer adapters
  without creating a full task struct. Returns the adapter type string or nil.
  """
  @spec infer_adapter_type(String.t()) :: String.t() | nil
  def infer_adapter_type(description) when is_binary(description) do
    stub = %{title: description, description: description, labels: []}

    case match_by_content(stub) do
      {:ok, mod} -> mod.type()
      nil -> nil
    end
  end

  def infer_adapter_type(_), do: nil

  @doc "Return routing rules for display in the UI."
  @spec routing_rules() :: [map()]
  def routing_rules do
    [
      %{
        priority: 1,
        name: "Explicit override",
        description: "Task has an adapter_override field set",
        trigger: "adapter_override",
        adapter: nil
      },
      %{
        priority: 2,
        name: "Label: code_review",
        description: "Task label 'code_review'",
        trigger: "label",
        adapter: "claude-code"
      },
      %{
        priority: 2,
        name: "Label: bulk_refactor",
        description: "Task label 'bulk_refactor'",
        trigger: "label",
        adapter: "codex"
      },
      %{
        priority: 2,
        name: "Label: test_suite",
        description: "Task label 'test_suite'",
        trigger: "label",
        adapter: "bash"
      },
      %{
        priority: 2,
        name: "Label: api_check",
        description: "Task label 'api_check'",
        trigger: "label",
        adapter: "http"
      },
      %{
        priority: 2,
        name: "Label: visual_analysis",
        description: "Task label 'visual_analysis'",
        trigger: "label",
        adapter: "gemini"
      },
      %{
        priority: 2,
        name: "Label: deployment",
        description: "Task label 'deployment'",
        trigger: "label",
        adapter: "bash"
      },
      %{
        priority: 3,
        name: "Content: multimodal",
        description: "Mentions screenshot, image, visual, diagram, ui review",
        trigger: "content_regex",
        pattern: "(screenshot|image|visual|diagram|ui review)",
        adapter: "gemini"
      },
      %{
        priority: 3,
        name: "Content: bulk file ops",
        description: "Mentions refactoring N files, mass update, bulk, find and replace across",
        trigger: "content_regex",
        pattern: "(refactor \\d+ files|bulk|mass update|find and replace across)",
        adapter: "codex"
      },
      %{
        priority: 3,
        name: "Content: shell/infra",
        description:
          "Mentions run tests, write tests, deploy, docker, kubectl, terraform, ansible, script, ci pipeline",
        trigger: "content_regex",
        pattern: "(run tests|write tests|deploy|docker|kubectl|terraform|ansible|script|ci pipeline)",
        adapter: "bash"
      },
      %{
        priority: 3,
        name: "Content: HTTP/webhook",
        description: "Mentions check endpoint, api status, webhook, curl, health check, ping",
        trigger: "content_regex",
        pattern: "(check endpoint|api status|webhook|curl|health check|ping)",
        adapter: "http"
      },
      %{
        priority: 3,
        name: "Content: deep reasoning",
        description: "Mentions design, architect, spec, complex, analyze, review, strategy",
        trigger: "content_regex",
        pattern: "(design|architect|spec|complex|analyze|review|strategy)",
        adapter: "claude-code"
      },
      %{
        priority: 4,
        name: "Agent default",
        description: "Falls back to the agent's preconfigured adapter",
        trigger: "agent_default",
        adapter: nil
      }
    ]
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  # Returns the adapter_override string from the task, or nil.
  defp get_task_adapter(%{adapter_override: override})
       when is_binary(override) and override != "",
       do: override

  defp get_task_adapter(_), do: nil

  # Label-based routing. Labels may be a list of Label structs (with :name) or strings.
  defp match_by_task_type(task) do
    labels = get_labels(task)

    type =
      Enum.find_value(labels, fn label ->
        name = normalize_label(label)

        case name do
          "code_review" -> "claude-code"
          "bulk_refactor" -> "codex"
          "test_suite" -> "bash"
          "api_check" -> "http"
          "visual_analysis" -> "gemini"
          "deployment" -> "bash"
          _ -> nil
        end
      end)

    case type do
      nil -> nil
      adapter_type -> safe_resolve(adapter_type, "label:#{inspect(labels)}")
    end
  end

  # Content-based routing. Safe against nil/empty strings.
  defp match_by_content(task) do
    content =
      [get_field(task, :title), get_field(task, :description)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.downcase()

    if content == "" do
      nil
    else
      cond do
        content =~ ~r/(screenshot|image|visual|diagram|ui review)/ ->
          safe_resolve("gemini", "content:multimodal")

        content =~ ~r/(refactor \d+ files|bulk|mass update|find and replace across)/ ->
          safe_resolve("codex", "content:bulk")

        content =~ ~r/(run tests|write tests|deploy|docker|kubectl|terraform|ansible|script|ci pipeline)/ ->
          safe_resolve("bash", "content:shell")

        content =~ ~r/(check endpoint|api status|webhook|curl|health check|ping)/ ->
          safe_resolve("http", "content:http")

        content =~ ~r/(design|architect|spec|complex|analyze|review|strategy)/ ->
          safe_resolve("claude-code", "content:reasoning")

        true ->
          nil
      end
    end
  end

  defp safe_resolve(adapter_type, source) do
    case Canopy.Adapter.resolve(adapter_type) do
      {:ok, mod} ->
        Logger.debug("[Dispatch.Router] Matched #{source} → #{adapter_type}")
        {:ok, mod}

      {:error, reason} ->
        Logger.warning(
          "[Dispatch.Router] Matched #{source} → #{adapter_type} but resolve failed: #{inspect(reason)}"
        )

        nil
    end
  end

  defp get_labels(%{labels: labels}) when is_list(labels), do: labels
  defp get_labels(_), do: []

  defp normalize_label(%{name: name}) when is_binary(name), do: String.downcase(name)
  defp normalize_label(name) when is_binary(name), do: String.downcase(name)
  defp normalize_label(_), do: ""

  defp get_field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
