defmodule Lanpartyseating.Tournament do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tournaments" do
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :name, :string
    field :deleted_at, :utc_datetime
    has_many :tournament_reservations, Lanpartyseating.TournamentReservation
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
