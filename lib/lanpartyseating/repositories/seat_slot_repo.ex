defmodule Lanpartyseating.SeatSlot do
  @moduledoc """
  A physical place an attendee can sit, owned by the Room and identified by a label.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "seat_slots" do
    field :label, :string
    field :legacy_station_number, :integer
    field :metadata, :map, default: %{}
    field :deleted_at, :utc_datetime

    belongs_to :room, Lanpartyseating.Room
    has_many :reservations, Lanpartyseating.Reservation
    has_many :tournament_reservations, Lanpartyseating.TournamentReservation
    has_one :status, Lanpartyseating.SeatSlotStatus
    has_one :assignment, Lanpartyseating.SeatSlotAssignment

    timestamps()
  end

  def changeset(seat_slot, attrs) do
    seat_slot
    |> cast(attrs, [:room_id, :label, :legacy_station_number, :metadata, :deleted_at])
    |> validate_required([:room_id, :label])
    |> validate_format(:label, ~r/^[A-Z][0-9]{2}$/)
    |> unique_constraint([:room_id, :label])
  end
end
