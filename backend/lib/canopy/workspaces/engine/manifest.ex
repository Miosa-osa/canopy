defmodule Canopy.Workspaces.Engine.Manifest do
  @moduledoc """
  Reads `.canopy/engine.yaml`, the workspace-local allowlist for engine tasks.

      commands:
        impact:
          task: optimal.impact
          description: Score strategy impact
          args: ["--json"]
  """

  @command_name_regex ~r/\A[a-z0-9][a-z0-9_-]*\z/
  @task_regex ~r/\Aoptimal\.[a-z0-9][a-z0-9_.-]*\z/

  @type command :: %{
          name: String.t(),
          task: String.t(),
          description: String.t() | nil,
          args: [String.t()]
        }

  @spec load(String.t()) :: {:ok, [command()]} | {:error, :manifest_not_found | term()}
  def load(root_path) when is_binary(root_path) do
    path = manifest_path(root_path)

    with true <- File.exists?(path) || {:error, :manifest_not_found},
         {:ok, raw} <- File.read(path),
         {:ok, parsed} <- YamlElixir.read_from_string(raw) do
      parse_commands(parsed)
    end
  end

  @spec manifest_path(String.t()) :: String.t()
  def manifest_path(root_path), do: Path.join([root_path, ".canopy", "engine.yaml"])

  defp parse_commands(%{"commands" => commands}) when is_map(commands) do
    commands =
      commands
      |> Enum.flat_map(&parse_command/1)
      |> Enum.sort_by(& &1.name)

    {:ok, commands}
  end

  defp parse_commands(%{commands: commands}) when is_map(commands),
    do: parse_commands(%{"commands" => commands})

  defp parse_commands(_), do: {:ok, []}

  defp parse_command({name, config}) when is_map(config) do
    name = to_string(name)
    task = command_task(name, config)

    if Regex.match?(@command_name_regex, name) and Regex.match?(@task_regex, task) do
      [
        %{
          name: name,
          task: task,
          description: string_value(config, "description"),
          args: list_value(config, "args")
        }
      ]
    else
      []
    end
  end

  defp parse_command(_), do: []

  defp command_task(name, config) do
    string_value(config, "task") ||
      string_value(config, "mix_task") ||
      "optimal.#{String.replace(name, "-", "_")}"
  end

  defp string_value(map, key) do
    value = Map.get(map, key) || Map.get(map, String.to_atom(key))

    case value do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp list_value(map, key) do
    value = Map.get(map, key) || Map.get(map, String.to_atom(key))

    case value do
      values when is_list(values) -> Enum.map(values, &to_string/1)
      value when is_binary(value) and value != "" -> [value]
      _ -> []
    end
  rescue
    ArgumentError -> []
  end
end
