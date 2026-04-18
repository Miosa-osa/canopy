defmodule Canopy.AgentsTest do
  @moduledoc """
  Integration tests for the Canopy.Agents context module.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Agents
  alias Canopy.Agents.Agent, as: AgentSchema

  defp valid_agent_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        slug: "senior-dev-#{System.unique_integer([:positive])}",
        category: "engineering",
        name: "Senior Developer",
        persona_path: "engineering/senior-dev.md"
      },
      overrides
    )
  end

  describe "list/0 and list/1" do
    test "returns empty list when no agents exist" do
      assert {:ok, []} = Agents.list()
    end

    test "returns all agents" do
      {:ok, _inserted} =
        Canopy.Repo.insert(AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs()))

      assert {:ok, agents} = Agents.list()
      assert agents != []
    end

    test "filters to hired agents when hired: true" do
      {:ok, _hired} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: true}))
        )

      {:ok, _not_hired} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: false}))
        )

      {:ok, agents} = Agents.list(hired: true)
      assert Enum.all?(agents, & &1.hired)
    end

    test "filters to unhired agents when hired: false" do
      {:ok, _hired} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: true}))
        )

      {:ok, _not_hired} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: false}))
        )

      {:ok, agents} = Agents.list(hired: false)
      assert Enum.all?(agents, &(not &1.hired))
    end
  end

  describe "list_hired/0" do
    test "returns only hired agents" do
      {:ok, _hired} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: true}))
        )

      {:ok, _not_hired} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: false}))
        )

      assert {:ok, agents} = Agents.list_hired()
      assert agents != []
      assert Enum.all?(agents, & &1.hired)
    end

    test "returns empty list when no agents are hired" do
      {:ok, _not_hired} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: false}))
        )

      assert {:ok, []} = Agents.list_hired()
    end
  end

  describe "get_by_slug/1" do
    test "returns agent when found" do
      {:ok, inserted} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{slug: "my-slug"}))
        )

      assert {:ok, agent} = Agents.get_by_slug("my-slug")
      assert agent.id == inserted.id
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Agents.get_by_slug("nonexistent-slug")
    end
  end

  describe "hire/1" do
    test "marks an agent as hired" do
      {:ok, agent} =
        Canopy.Repo.insert(AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs()))

      refute agent.hired
      assert {:ok, hired} = Agents.hire(agent.slug)
      assert hired.hired == true
    end

    test "returns error for unknown slug" do
      assert {:error, :not_found} = Agents.hire("no-such-agent")
    end
  end

  describe "fire/1" do
    test "marks an agent as not hired" do
      {:ok, agent} =
        Canopy.Repo.insert(
          AgentSchema.changeset(%AgentSchema{}, valid_agent_attrs(%{hired: true}))
        )

      assert agent.hired == true
      assert {:ok, fired} = Agents.fire(agent.slug)
      assert fired.hired == false
    end

    test "returns error for unknown slug" do
      assert {:error, :not_found} = Agents.fire("no-such-agent")
    end
  end

  describe "slug uniqueness" do
    test "rejects duplicate slug" do
      attrs = valid_agent_attrs(%{slug: "unique-slug"})
      {:ok, _first} = Canopy.Repo.insert(AgentSchema.changeset(%AgentSchema{}, attrs))
      {:error, cs} = Canopy.Repo.insert(AgentSchema.changeset(%AgentSchema{}, attrs))
      assert %{slug: ["has already been taken"]} = errors_on(cs)
    end
  end
end
