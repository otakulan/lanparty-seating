defmodule Lanpartyseating.TournamentReservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "tournament_reservations" do
    belongs_to :station, Lanpartyseating.Station, foreign_key: :station_id, references: :station_number
    belongs_to :tournament, Lanpartyseating.Tournament
    field :deleted_at, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(tournament_reservation, attrs) do
    tournament_reservation
    |> cast(attrs, [:station_id, :tournament_id, :deleted_at])
    |> validate_required([:station_id, :tournament_id])
    |> validate_number(:station_id, greater_than: 0)
    |> validate_number(:tournament_id, greater_than: 0)
  end
end
