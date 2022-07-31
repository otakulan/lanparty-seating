defmodule Lanpartyseating.Reservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reservations" do
    field :start_time, :utc_datetime
    field :duration, :time, default: ~T[00:00:00]
    field :badge_number, :integer
    field :status, :string
    field :incident, :string
    field :deleted_at, :utc_datetime
    field :station_id, :string
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:UID, :start_time, :duration, :badge_number, :status, :station_id])
    |> validate_required([:UID, :start_time, :badger_number, :status, :station_id])
    |> validate_number(:row, greater_than: -1)
    |> validate_number(:column, greater_than: -1)
  end
end
