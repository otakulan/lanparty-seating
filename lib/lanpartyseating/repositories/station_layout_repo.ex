defmodule Lanpartyseating.StationLayout do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:station_id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "station_layout" do
    field :x, :integer
    field :y, :integer
  end

  @doc false
  def changeset(station, attrs) do
    station
    |> cast(attrs, [:station_id, :x, :y])
    |> validate_required([:station_id, :x, :y])
    |> validate_number(:x, greater_than: -1)
    |> validate_number(:y, greater_than: -1)
    |> unique_constraint(:x, :y)
  end
end
