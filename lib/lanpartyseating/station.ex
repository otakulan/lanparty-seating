defmodule Lanpartyseating.Station do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "stations" do
    field :station_number, :integer
    field :display_order, :integer
    field :is_closed, :boolean
    field :deleted_at, :utc_datetime
    has_many :reservations, Lanpartyseating.Reservation
    has_many :tournament_reservations, Lanpartyseating.TournamentReservation
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:station_number, :display_order, :is_closed, :deleted_at])
    |> validate_required([:station_number, :display_order])
    |> validate_number(:station_number, greater_than: 0)
  end
end
