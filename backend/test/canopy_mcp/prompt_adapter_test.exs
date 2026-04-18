defmodule CanopyMCP.PromptAdapterTest do
  @moduledoc """
  Unit + integration tests for CanopyMCP.PromptAdapter.

  All tests use DataCase (SQL sandbox) because prompts derive from DB-backed
  agent rows. Tests run async — each uses its own isolated DB transaction.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias CanopyMCP.PromptAdapter

  # ---------------------------------------------------------------------------
  # list_prompts/0
  # ---------------------------------------------------------------------------

  describe "list_prompts/0" do
    test "returns empty list when no agents are hired" do
      _unhired = insert(:agent, hired: false)
      assert PromptAdapter.list_prompts() == []
    end

    test "returns one descriptor per hired agent" do
      insert(:agent, hired: true)
      insert(:agent, hired: true)
      insert(:agent, hired: false)

      prompts = PromptAdapter.list_prompts()
      assert length(prompts) == 2
    end

    test "each descriptor has name, description, arguments keys" do
      insert(:agent, hired: true)

      for descriptor <- PromptAdapter.list_prompts() do
        assert Map.has_key?(descriptor, "name")
        assert Map.has_key?(descriptor, "description")
        assert Map.has_key?(descriptor, "arguments")
      end
    end

    test "prompt name follows agent.<slug> convention" do
      agent = insert(:agent, hired: true)

      prompts = PromptAdapter.list_prompts()
      prompt = Enum.find(prompts, &(&1["name"] == "agent.#{agent.slug}"))

      assert prompt != nil
    end

    test "arguments list contains the context argument as not required" do
      insert(:agent, hired: true)

      [descriptor] = PromptAdapter.list_prompts()
      args = descriptor["arguments"]

      assert is_list(args)
      assert length(args) == 1

      context_arg = hd(args)
      assert context_arg["name"] == "context"
      assert context_arg["required"] == false
    end

    test "description falls back to name-based string when agent has no description" do
      agent = insert(:agent, hired: true, description: nil, name: "Test Agent")

      prompts = PromptAdapter.list_prompts()
      descriptor = Enum.find(prompts, &(&1["name"] == "agent.#{agent.slug}"))

      assert is_binary(descriptor["description"])
      assert String.length(descriptor["description"]) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # get_prompt/2 — success paths
  # ---------------------------------------------------------------------------

  describe "get_prompt/2 success" do
    test "returns prompt result for a hired agent by name" do
      agent = insert(:agent, hired: true, persona_markdown: "You are a coding expert.")
      name = "agent.#{agent.slug}"

      assert {:ok, result} = PromptAdapter.get_prompt(name, %{})
      assert Map.has_key?(result, "description")
      assert Map.has_key?(result, "messages")
    end

    test "messages contain system persona when no context given" do
      agent = insert(:agent, hired: true, persona_markdown: "You are a coding expert.")
      name = "agent.#{agent.slug}"

      assert {:ok, result} = PromptAdapter.get_prompt(name, %{})
      messages = result["messages"]

      assert length(messages) == 1
      [system_msg] = messages
      assert system_msg["role"] == "system"
      assert system_msg["content"]["type"] == "text"
      assert system_msg["content"]["text"] == "You are a coding expert."
    end

    test "injects context as user turn when context argument is provided" do
      agent = insert(:agent, hired: true, persona_markdown: "You are a coding expert.")
      name = "agent.#{agent.slug}"

      assert {:ok, result} = PromptAdapter.get_prompt(name, %{"context" => "Focus on Elixir."})
      messages = result["messages"]

      assert length(messages) == 2
      [user_msg, system_msg] = messages
      assert user_msg["role"] == "user"
      assert user_msg["content"]["text"] == "Focus on Elixir."
      assert system_msg["role"] == "system"
    end

    test "empty context string is treated the same as no context" do
      agent = insert(:agent, hired: true, persona_markdown: "You are a coding expert.")
      name = "agent.#{agent.slug}"

      assert {:ok, result} = PromptAdapter.get_prompt(name, %{"context" => ""})
      # Empty string = no injection
      assert length(result["messages"]) == 1
    end

    test "description in result matches agent description" do
      agent = insert(:agent, hired: true, description: "Senior Elixir engineer")
      name = "agent.#{agent.slug}"

      assert {:ok, result} = PromptAdapter.get_prompt(name, %{})
      assert result["description"] == "Senior Elixir engineer"
    end
  end

  # ---------------------------------------------------------------------------
  # get_prompt/2 — error paths
  # ---------------------------------------------------------------------------

  describe "get_prompt/2 errors" do
    test "returns :not_found for an unhired agent" do
      agent = insert(:agent, hired: false)
      name = "agent.#{agent.slug}"

      assert {:error, :not_found} = PromptAdapter.get_prompt(name, %{})
    end

    test "returns :not_found for a completely unknown name" do
      assert {:error, :not_found} = PromptAdapter.get_prompt("agent.ghost-agent-xyz", %{})
    end

    test "returns :not_found when name does not have agent. prefix" do
      agent = insert(:agent, hired: true)

      # Direct slug without prefix
      assert {:error, :not_found} = PromptAdapter.get_prompt(agent.slug, %{})
    end

    test "returns :not_found for empty name string" do
      assert {:error, :not_found} = PromptAdapter.get_prompt("", %{})
    end

    test "returns :not_found for prefix-only name (no slug)" do
      assert {:error, :not_found} = PromptAdapter.get_prompt("agent.", %{})
    end
  end
end
