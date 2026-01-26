defmodule Lanpartyseating.StationStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:station_id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "stations_status" do
    field :is_assigned, :boolean, default: false
    field :is_broken, :boolean, default: false
    timestamps()
  end

  @doc false
  def changeset(station_status, attrs) do
    station_status
    |> cast(attrs, [:station_id, :is_assigned, :is_broken])
    |> validate_required([:station_id])
    |> validate_number(:station_id, greater_than: 0)
  end
end
