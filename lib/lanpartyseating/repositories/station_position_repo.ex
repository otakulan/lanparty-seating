defmodule Lanpartyseating.StationPosition do
  use Ecto.Schema
  import Ecto.Changeset
  alias Lanpartyseating.Station, as: Station

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "stations" do
    has_one :station_number, Station, foreign_key: :station_number
    field :row, :integer
    field :column, :integer
  end

  @doc false
  def changeset(station_position, attrs) do
    station_position
    |> cast(attrs, [:station_number, :row, :column])
    |> validate_required([:station_number, :row, :column])
    |> validate_number(:station_number, greater_than: 0)
  end
end
