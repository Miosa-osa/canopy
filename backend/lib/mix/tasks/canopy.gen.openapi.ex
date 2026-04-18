defmodule Mix.Tasks.Canopy.Gen.Openapi do
  @shortdoc "Generate OpenAPI 3.1 JSON from CanopyWeb schemas"

  @moduledoc """
  Generates an OpenAPI 3.1 JSON specification from the `CanopyWeb.ApiSpec`
  module and writes it to disk.

  The output file is consumed by `openapi-typescript` in `packages/types/`
  to produce `src/api.ts`. Do not hand-edit that file — regenerate it from
  the Elixir schemas.

  ## Usage

      # Write to default location (../packages/types/openapi.json)
      mix canopy.gen.openapi

      # Write to a custom path
      mix canopy.gen.openapi --output /tmp/canopy.json

  ## Integration

  This task is wired into `make gen-types` and into the `packages/types`
  `pnpm generate` script. It is also run in CI after `mix test` to verify
  the spec is always generatable from source.
  """

  use Mix.Task

  @requirements ["app.start"]

  @default_output "../packages/types/openapi.json"

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args, strict: [output: :string])

    output_path = Keyword.get(opts, :output, default_output_path())

    Mix.shell().info("Generating OpenAPI spec from CanopyWeb.ApiSpec...")

    spec = CanopyWeb.ApiSpec.spec()
    path_count = map_size(spec.paths)

    # Serialize via the same path used by mix openapi.spec.json:
    # convert the OpenApiSpex struct tree to a plain map, then JSON-encode it.
    spec_map = OpenApiSpex.OpenApi.to_map(spec)

    json =
      case OpenApiSpex.OpenApi.json_encoder().encode(spec_map, pretty: false) do
        {:ok, encoded} -> encoded
        {:error, reason} -> Mix.raise("Failed to encode OpenAPI spec: #{inspect(reason)}")
      end

    output_path
    |> Path.expand()
    |> tap(&ensure_parent_dir!/1)
    |> write_spec!(json)

    Mix.shell().info("""

    Done.
      output:  #{output_path}
      title:   #{spec.info.title}
      version: #{spec.info.version}
      paths:   #{path_count}
    """)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec default_output_path() :: String.t()
  defp default_output_path do
    # __DIR__ = backend/lib/mix/tasks — traverse up 4 levels to backend/,
    # then ../packages/types/openapi.json
    Path.join([__DIR__, "..", "..", "..", "..", @default_output])
  end

  @spec ensure_parent_dir!(String.t()) :: :ok
  defp ensure_parent_dir!(absolute_path) do
    dir = Path.dirname(absolute_path)

    case File.mkdir_p(dir) do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.raise("Cannot create output directory #{dir}: #{:file.format_error(reason)}")
    end
  end

  @spec write_spec!(String.t(), String.t()) :: :ok
  defp write_spec!(absolute_path, json) do
    case File.write(absolute_path, json) do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.raise("Cannot write OpenAPI spec to #{absolute_path}: #{:file.format_error(reason)}")
    end
  end
end
