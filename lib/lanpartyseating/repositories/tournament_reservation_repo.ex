defmodule Lanpartyseating.TournamentReservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "tournament_reservations" do
    field :station_id, :id
    field :tournament_id, :id
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
