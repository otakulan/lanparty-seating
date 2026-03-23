defmodule Lanpartyseating.SeatMap do
  use Ecto.Schema
  import Ecto.Changeset

  schema "seat_maps" do
    field :name, :string
    field :slug, :string
    field :deleted_at, :utc_datetime

    has_many :versions, Lanpartyseating.SeatMapVersion
    has_many :seat_slots, Lanpartyseating.SeatSlot

    timestamps()
  end

  def changeset(seat_map, attrs) do
    seat_map
    |> cast(attrs, [:name, :slug, :deleted_at])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:slug, min: 1, max: 255)
    |> unique_constraint(:slug)
  end
end
