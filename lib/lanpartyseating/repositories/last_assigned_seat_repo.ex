defmodule Lanpartyseating.LastAssignedSeat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "last_assigned_station" do
    field(:last_assigned_station, :integer)
    field(:last_assigned_station_date, :utc_datetime)
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:last_assigned_station, :last_assigned_station])
    |> validate_number(attrs, [:last_assigned_station, greater_than: -2])
  end
end
