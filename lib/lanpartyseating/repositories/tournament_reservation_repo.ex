defmodule Lanpartyseating.TournamentReservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "tournament_reservations" do
    belongs_to :station, Lanpartyseating.Station
    belongs_to :tournament, Lanpartyseating.Tournament
    field :deleted_at, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:station_id, :tournament_id])
    |> validate_required([:station_id, :tournament_id])
  end
end
