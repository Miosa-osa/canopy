defmodule Canopy.Editors do
  @moduledoc """
  Editor detection for the "Open in editor" feature.

  `detect_editors/0` probes PATH for known editor executables and returns
  a list describing which are installed on the current machine.
  """

  @known_editors [
    %{command: "code", name: "VS Code"},
    %{command: "cursor", name: "Cursor"},
    %{command: "webstorm", name: "WebStorm"},
    %{command: "idea", name: "IDEA"},
    %{command: "subl", name: "Sublime Text"},
    %{command: "vim", name: "Vim"}
  ]

  @type editor_entry :: %{command: String.t(), name: String.t(), installed: boolean()}

  @doc """
  Returns a list of known editors with an `installed` flag indicating
  whether the binary is present on PATH via `System.find_executable/1`.

  ## Examples

      iex> editors = Canopy.Editors.detect_editors()
      iex> is_list(editors)
      true
      iex> Enum.all?(editors, &Map.has_key?(&1, :installed))
      true
  """
  @spec detect_editors() :: [editor_entry()]
  def detect_editors do
    Enum.map(@known_editors, fn %{command: cmd} = entry ->
      Map.put(entry, :installed, System.find_executable(cmd) != nil)
    end)
  end
end
