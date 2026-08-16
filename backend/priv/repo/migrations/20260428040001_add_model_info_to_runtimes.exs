defmodule Canopy.Repo.Migrations.AddModelInfoToRuntimes do
  @moduledoc """
  Adds a `model_info` jsonb column to `runtime_models` capturing rich
  per-model metadata used by the Runtime Adapter Agent.

  Schema for the embedded map (see `Canopy.Runtimes.ModelInfo`):

      {
        "max_tokens": int,
        "context_window": int,
        "supports_images": bool,
        "supports_prompt_cache": bool,
        "supports_reasoning": bool,
        "input_price": decimal,        # cents per 1M input tokens
        "output_price": decimal,
        "cache_writes_price": decimal,
        "cache_reads_price": decimal,
        "tiers": [%{name, threshold, multiplier}, ...]
      }

  The legacy ad-hoc booleans (`supports_thinking`, `supports_tools`,
  `supports_vision`) and the `*_cost_per_mtok` columns remain so existing
  callers continue to work; they are kept in sync by the application layer
  during writes.
  """

  use Ecto.Migration

  def change do
    alter table(:runtime_models) do
      add :model_info, :map, default: %{}, null: false
    end

    create index(:runtime_models, [:runtime_id])
  end
end
