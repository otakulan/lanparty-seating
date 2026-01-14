defmodule Lanpartyseating.StationLayout do
  alias Lanpartyseating.Station
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:station_number, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "station_layout" do
    has_one(:stations, Station, foreign_key: :station_number)
    field(:x, :integer)
    field(:y, :integer)
  end

  @doc false
  def changeset(station, attrs) do
    station
    |> cast(attrs, [:station_number, :x, :y])
    |> validate_required([:station_number, :x, :y])
    |> validate_number(:x, greater_than: -1)
    |> validate_number(:y, greater_than: -1)
    |> unique_constraint(:x, :y)
  end
end
