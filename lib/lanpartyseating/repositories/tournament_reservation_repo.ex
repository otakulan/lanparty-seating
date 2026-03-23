defmodule Lanpartyseating.TournamentReservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "tournament_reservations" do
    belongs_to :station, Lanpartyseating.Station, foreign_key: :station_id, references: :station_number
    belongs_to :seat_slot, Lanpartyseating.SeatSlot
    belongs_to :tournament, Lanpartyseating.Tournament
    field :deleted_at, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(tournament_reservation, attrs) do
    tournament_reservation
    |> cast(attrs, [:station_id, :seat_slot_id, :tournament_id, :deleted_at])
    |> validate_required([:tournament_id])
    |> validate_reservation_target()
    |> validate_number(:tournament_id, greater_than: 0)
  end

  defp validate_reservation_target(changeset) do
    station_id = get_field(changeset, :station_id)
    seat_slot_id = get_field(changeset, :seat_slot_id)

    cond do
      is_integer(seat_slot_id) and seat_slot_id > 0 -> changeset
      is_integer(station_id) and station_id > 0 -> changeset
      true -> add_error(changeset, :seat_slot_id, "must reference a seat slot")
    end
  end
end
