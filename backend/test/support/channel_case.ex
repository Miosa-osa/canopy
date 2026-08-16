defmodule CanopyWeb.ChannelCase do
  @moduledoc """
  Test case template for Phoenix channel tests.

  Provides `subscribe_and_join/3,4` and assertion helpers from
  `Phoenix.ChannelTest`, plus the Ecto SQL sandbox for DB access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import Canopy.Factory

      @endpoint CanopyWeb.Endpoint
    end
  end

  setup tags do
    Canopy.DataCase.setup_sandbox(tags)
    :ok
  end
end
