defmodule Lanpartyseating.SeatMapVersion do
  @moduledoc """
  An immutable snapshot of a Seat Map's contents. Every save appends a new one; none is
  ever modified after creation. Versions are numbered per Seat Map by `revision`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "seat_map_versions" do
    field :revision, :integer, default: 1
    field :width, :integer, default: 1920
    field :height, :integer, default: 1080
    field :background_kind, :string, default: "none"
    field :background_value, :string
    field :data, :map, default: %{}
    field :published_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :seat_map, Lanpartyseating.SeatMap

    timestamps()
  end

  @doc """
  Full changeset for content saves. Versions are insert-only; this is used when appending
  a new immutable Version.
  """
  def changeset(version, attrs) do
    version
    |> cast(
      attrs,
      [
        :seat_map_id,
        :revision,
        :width,
        :height,
        :background_kind,
        :background_value,
        :data,
        :published_at,
        :deleted_at,
      ]
    )
    |> validate_required([:seat_map_id, :width, :height, :background_kind, :data])
    |> validate_inclusion(:background_kind, ["none", "image", "svg"])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
  end
end
