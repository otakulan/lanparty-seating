defmodule Lanpartyseating.TournamentReservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tournament_reservations" do
    field :station_id, :string
    field :tournament_id, :string
    field :deleted_at, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:UID, :row, :column])
    |> validate_required([:UID, :row, :column])
    |> validate_number(:row, greater_than: -1)
    |> validate_number(:column, greater_than: -1)
  end
end
