defmodule Lanpartyseating.Reservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "reservations" do
    field :duration, :time, default: ~T[00:45:00]
    field :badge, :string
    field :incident, :string
    field :deleted_at, :utc_datetime
    field :station_id, :id
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:duration, :badge_number, :station_id])
    |> validate_required([:badge, :station_id])
  end
end
