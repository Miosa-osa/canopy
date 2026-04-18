defmodule Mix.Tasks.Canopy.Gen.OpenapiTest do
  @moduledoc """
  Integration tests for `mix canopy.gen.openapi`.

  The task requires `app.start` (honoured at runtime). Tests invoke the task
  directly with a temp-dir `--output` path and assert on the generated JSON to
  verify the spec is well-formed and covers the known API surface.
  """

  use ExUnit.Case, async: false

  alias Mix.Tasks.Canopy.Gen.Openapi

  describe "mix canopy.gen.openapi" do
    test "generates a valid OpenAPI JSON file at the specified output path" do
      output = tmp_path("exists")
      Openapi.run(["--output", output])
      assert File.exists?(output)
    end

    test "generated file is parseable JSON" do
      output = tmp_path("parseable")
      Openapi.run(["--output", output])

      raw = File.read!(output)
      assert {:ok, decoded} = Jason.decode(raw)
      assert is_map(decoded)
    end

    test "spec has correct info.title" do
      output = tmp_path("title")
      Openapi.run(["--output", output])

      spec = decode_spec!(output)
      assert spec["info"]["title"] == "Canopy API"
    end

    test "spec has a non-empty info.version" do
      output = tmp_path("version")
      Openapi.run(["--output", output])

      spec = decode_spec!(output)
      assert is_binary(spec["info"]["version"])
      assert String.length(spec["info"]["version"]) > 0
    end

    test "spec declares openapi 3.x" do
      output = tmp_path("oapi_version")
      Openapi.run(["--output", output])

      spec = decode_spec!(output)
      assert String.starts_with?(spec["openapi"], "3.")
    end

    test "spec includes /api/v1/sessions/{id}/events (SSE stream) path" do
      output = tmp_path("sse_path")
      Openapi.run(["--output", output])

      assert "/api/v1/sessions/{id}/events" in path_keys(output)
    end

    test "spec includes /api/v1/runtimes path" do
      output = tmp_path("runtimes")
      Openapi.run(["--output", output])

      assert "/api/v1/runtimes" in path_keys(output)
    end

    test "spec includes /api/v1/sessions path" do
      output = tmp_path("sessions")
      Openapi.run(["--output", output])

      assert "/api/v1/sessions" in path_keys(output)
    end

    test "spec includes /api/v1/agents path" do
      output = tmp_path("agents")
      Openapi.run(["--output", output])

      assert "/api/v1/agents" in path_keys(output)
    end

    test "spec has at least 10 distinct paths" do
      output = tmp_path("path_count")
      Openapi.run(["--output", output])

      count = output |> decode_spec!() |> Map.fetch!("paths") |> map_size()
      assert count >= 10, "expected ≥10 paths, got #{count}"
    end

    test "spec has a non-empty components/schemas section" do
      output = tmp_path("schemas")
      Openapi.run(["--output", output])

      schemas = output |> decode_spec!() |> get_in(["components", "schemas"])
      assert is_map(schemas)
      assert map_size(schemas) > 0
    end

    test "Runtime schema is present in components" do
      output = tmp_path("runtime_schema")
      Openapi.run(["--output", output])

      schemas = output |> decode_spec!() |> get_in(["components", "schemas"]) |> Map.keys()
      assert "Runtime" in schemas
    end

    test "Session schema is present in components" do
      output = tmp_path("session_schema")
      Openapi.run(["--output", output])

      schemas = output |> decode_spec!() |> get_in(["components", "schemas"]) |> Map.keys()
      assert "Session" in schemas
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp tmp_path(label) do
    path =
      Path.join(
        System.tmp_dir!(),
        "canopy_openapi_#{label}_#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(path) end)
    path
  end

  defp decode_spec!(output) do
    output |> File.read!() |> Jason.decode!()
  end

  defp path_keys(output) do
    output |> decode_spec!() |> Map.fetch!("paths") |> Map.keys()
  end
end
