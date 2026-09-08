defmodule Canopy.EngineFixture do
  @moduledoc false

  def pin!(root) do
    dir = Path.join(root, "engine")

    contract = %{
      "contract_version" => 1,
      "repository" => "Miosa-osa/OptimalEngine",
      "version" => "0.3.1",
      "api_version" => "v1",
      "expected_migration" => 62,
      "capabilities" => ["workspace_mix_tasks"]
    }

    File.write!(Path.join(dir, "engine-contract.json"), Jason.encode!(contract))
    git!(dir, ["init", "-q"])
    git!(dir, ["config", "user.email", "test@example.invalid"])
    git!(dir, ["config", "user.name", "Fixture"])
    git!(dir, ["remote", "add", "origin", "https://github.com/Miosa-osa/OptimalEngine.git"])
    git!(dir, ["add", "."])
    git!(dir, ["-c", "commit.gpgsign=false", "commit", "-qm", "fixture"])
    revision = git!(dir, ["rev-parse", "HEAD"])
    manifest = Path.join([root, ".canopy", "engine.yaml"])

    File.write!(
      manifest,
      """
      compatibility:
        repository: Miosa-osa/OptimalEngine
        revision: #{revision}
        version: ">= 0.3.1 and < 0.4.0"
        contract_version: 1
        api_version: v1
        expected_migration: 62
        required_capabilities: [workspace_mix_tasks]
      """ <> File.read!(manifest)
    )

    revision
  end

  def git!(dir, args) do
    {output, 0} = System.cmd("git", args, cd: dir, stderr_to_stdout: true)
    String.trim(output)
  end
end
