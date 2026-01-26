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
    |> cast(attrs, [:duration, :badge, :station_id, :start_date, :end_date, :incident, :deleted_at])
    |> validate_required([:badge, :station_id, :start_date, :end_date])
    |> validate_length(:badge, min: 1, max: 255)
    |> validate_number(:duration, greater_than: 0)
    |> validate_number(:station_id, greater_than: 0)
    |> validate_end_date_after_start_date()
  end

  defp validate_end_date_after_start_date(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && DateTime.compare(end_date, start_date) != :gt do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
  end
end
