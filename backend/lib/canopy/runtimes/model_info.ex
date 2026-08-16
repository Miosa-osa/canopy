defmodule Canopy.Runtimes.ModelInfo do
  @moduledoc """
  Typed model metadata embedded inside `RuntimeModel.model_info`.

  Replaces the ad-hoc maps that previously described capabilities and pricing
  with a single struct. The Runtime Adapter Agent reads this when scoring a
  model for a task — capability matching, cost arithmetic, context-window
  fit checks all run against this struct.

  ## Fields

  - `:max_tokens` — provider-imposed cap on response tokens.
  - `:context_window` — total prompt+response window.
  - `:supports_images` — multimodal input.
  - `:supports_prompt_cache` — provider supports prompt cache (Anthropic
    `cache_control`, etc.).
  - `:supports_reasoning` — model has a chain-of-thought / extended-thinking
    mode.
  - `:input_price` — cents per 1M input tokens (decimal).
  - `:output_price` — cents per 1M output tokens.
  - `:cache_writes_price` — cents per 1M cache-write tokens.
  - `:cache_reads_price` — cents per 1M cache-read tokens.
  - `:tiers` — list of pricing tiers, each `%{name, threshold_tokens,
    multiplier}` for usage-based rate cards.

  All cost fields are decimal so adapters can persist provider quotes
  without float drift.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  @derive Jason.Encoder

  embedded_schema do
    field :max_tokens, :integer
    field :context_window, :integer
    field :supports_images, :boolean, default: false
    field :supports_prompt_cache, :boolean, default: false
    field :supports_reasoning, :boolean, default: false
    field :input_price, :decimal
    field :output_price, :decimal
    field :cache_writes_price, :decimal
    field :cache_reads_price, :decimal

    embeds_many :tiers, Tier, on_replace: :delete, primary_key: false do
      @derive Jason.Encoder
      field :name, :string
      field :threshold_tokens, :integer
      field :multiplier, :decimal
    end
  end

  @fields ~w(max_tokens context_window supports_images supports_prompt_cache supports_reasoning
            input_price output_price cache_writes_price cache_reads_price)a

  @type t :: %__MODULE__{}

  @doc "Changeset for an embedded ModelInfo. Tiers nested via cast_embed/3."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(info, attrs) do
    info
    |> cast(attrs, @fields)
    |> cast_embed(:tiers, with: &tier_changeset/2)
    |> validate_number(:context_window, greater_than: 0)
    |> validate_number(:max_tokens, greater_than: 0)
  end

  defp tier_changeset(tier, attrs) do
    tier
    |> cast(attrs, [:name, :threshold_tokens, :multiplier])
    |> validate_required([:name])
    |> validate_number(:threshold_tokens, greater_than_or_equal_to: 0)
  end

  @doc """
  Builds a `ModelInfo` struct from a map (atom-keyed or string-keyed).

  Used at boundary points like JSON deserialization and adapter
  `list_models/0` returns. Invalid input collapses to an empty struct so a
  malformed provider payload never crashes the agent.
  """
  @spec from_map(map() | nil) :: t()
  def from_map(nil), do: %__MODULE__{}

  def from_map(attrs) when is_map(attrs) do
    case changeset(%__MODULE__{}, attrs) |> apply_action(:insert) do
      {:ok, info} -> info
      {:error, _} -> %__MODULE__{}
    end
  end
end
