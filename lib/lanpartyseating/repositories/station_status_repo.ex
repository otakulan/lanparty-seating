defmodule Lanpartyseating.StationStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:station_id, :integer, autogenerate: false}
  @foreign_key_type :integer

  schema "stations_status" do
    field(:is_assigned, :boolean, default: false)
    field(:is_broken, :boolean, default: false)
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:station_id, :is_assigned, :is_broken])
    |> validate_required([:station_id])
  end
end
