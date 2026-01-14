defmodule Lanpartyseating.Reservation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "reservations" do
    field :duration, :integer
    field :badge, :string
    field :incident, :string
    field :deleted_at, :utc_datetime

    belongs_to :station, Lanpartyseating.Station, foreign_key: :station_id, references: :station_number

    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:duration, :badge_number, :station_id, :start_time, :end_time])
    |> validate_required([:badge, :station_id])
    |> validate_number(:duration, greater_than: 0)
  end
end
