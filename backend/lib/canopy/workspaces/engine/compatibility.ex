defmodule Canopy.Workspaces.Engine.Compatibility do
  @moduledoc """
  Static preflight for the workspace-local Mix integration.

  Pins are approved workspace configuration, not claims supplied by the engine.
  Verify the checkout before loading its project or running any of its code.
  This does not attest a separately running HTTP service.
  """

  alias Canopy.Workspaces.Engine.Manifest

  @repository "Miosa-osa/OptimalEngine"
  @remotes [
    "https://github.com/Miosa-osa/OptimalEngine.git",
    "https://github.com/Miosa-osa/OptimalEngine",
    "git@github.com:Miosa-osa/OptimalEngine.git",
    "ssh://git@github.com/Miosa-osa/OptimalEngine.git"
  ]

  @spec check(String.t()) :: :ok | {:error, term()}
  def check(root) do
    dir = Path.expand(Path.join(root, "engine"))

    result =
      with {:ok, raw} <- File.read(Manifest.manifest_path(root)),
           {:ok, data} <- YamlElixir.read_from_string(raw),
           {:ok, pin} <- pin(data),
           :ok <- checkout(dir, pin),
           {:ok, body} <- File.read(Path.join(dir, "engine-contract.json")),
           {:ok, contract} <- Jason.decode(body),
           :ok <- contract(contract, pin) do
        :ok
      end

    case result do
      :ok -> :ok
      {:error, reason} -> {:error, {:engine_incompatible, reason}}
      _ -> {:error, {:engine_incompatible, :invalid_contract}}
    end
  rescue
    _ -> {:error, {:engine_incompatible, :invalid_contract}}
  end

  defp pin(%{"compatibility" => pin}) when is_map(pin) do
    valid =
      pin["repository"] == @repository and
        is_binary(pin["revision"]) and Regex.match?(~r/\A[0-9a-f]{40}\z/, pin["revision"]) and
        is_binary(pin["version"]) and pin["contract_version"] == 1 and
        pin["api_version"] == "v1" and is_integer(pin["expected_migration"]) and
        is_list(pin["required_capabilities"]) and
        "workspace_mix_tasks" in pin["required_capabilities"] and
        Enum.all?(pin["required_capabilities"], &is_binary/1)

    if valid, do: {:ok, pin}, else: {:error, :invalid_pin}
  end

  defp pin(_), do: {:error, :missing_pin}

  defp checkout(dir, pin) do
    # A symlink/parent repository must not masquerade as the workspace checkout.
    with {:ok, stat} <- File.lstat(dir),
         true <- stat.type == :directory || {:error, :unexpected_checkout},
         {:ok, top} <- git(dir, ["rev-parse", "--show-toplevel"]),
         true <- same_directory?(top, dir) || {:error, :unexpected_checkout},
         {:ok, remote} <- git(dir, ["config", "--get", "remote.origin.url"]),
         true <- remote in @remotes || {:error, :repository_mismatch},
         {:ok, revision} <- git(dir, ["rev-parse", "HEAD"]),
         true <- revision == pin["revision"] || {:error, :revision_mismatch},
         {:ok, status} <- git(dir, ["status", "--porcelain", "--untracked-files=all"]),
         true <- status == "" || {:error, :dirty_checkout},
         {:ok, tracked} <- git(dir, ["ls-files", "--error-unmatch", "engine-contract.json"]),
         true <- tracked == "engine-contract.json" || {:error, :untracked_contract} do
      :ok
    end
  end

  defp same_directory?(left, right) do
    with {:ok, a} <- File.stat(left), {:ok, b} <- File.stat(right) do
      {a.major_device, a.inode} == {b.major_device, b.inode}
    else
      _ -> false
    end
  end

  defp contract(contract, pin) when is_map(contract) do
    with true <- contract["repository"] == @repository || {:error, :repository_mismatch},
         true <-
           contract["contract_version"] == pin["contract_version"] || {:error, :contract_mismatch},
         true <- contract["api_version"] == pin["api_version"] || {:error, :api_mismatch},
         true <-
           contract["expected_migration"] == pin["expected_migration"] ||
             {:error, :migration_mismatch},
         {:ok, version} <- Version.parse(contract["version"] || ""),
         {:ok, requirement} <- Version.parse_requirement(pin["version"]),
         true <- Version.match?(version, requirement) || {:error, :version_mismatch},
         capabilities when is_list(capabilities) <- contract["capabilities"],
         true <-
           Enum.all?(pin["required_capabilities"], &(&1 in capabilities)) ||
             {:error, :missing_capability} do
      :ok
    end
  end

  defp contract(_, _), do: {:error, :invalid_contract}

  defp git(dir, args) do
    case System.cmd("git", args,
           cd: dir,
           stderr_to_stdout: true,
           env: [{"GIT_DIR", nil}, {"GIT_WORK_TREE", nil}, {"GIT_INDEX_FILE", nil}]
         ) do
      {output, 0} -> {:ok, String.trim(output)}
      _ -> {:error, :invalid_checkout}
    end
  end
end
