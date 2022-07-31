defmodule Lanpartyseating.Tournament do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "tournaments" do
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :name, :string
    field :deleted_at, :utc_datetime
    has_many :tournament_reservations, Lanpartyseating.TournamentReservation
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:start_date, :end_date, :name])
    |> validate_required([:start_date, :end_date, :name])
  end
end
