defmodule Lanpartyseating.StationStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "stations_status" do
    field :station_id, :integer
    field :is_assigned, :boolean, default: false
    field :is_out_of_order, :boolean, default: false
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:station_id, :tournament_id])
    |> validate_required([:station_id, :tournament_id])
  end
end
