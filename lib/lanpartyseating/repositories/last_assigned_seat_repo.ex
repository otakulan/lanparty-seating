defmodule Lanpartyseating.LastAssignedSeat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "last_assigned_seat" do
    field :last_assigned_seat, :integer
    field :last_assigned_seat_date, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:last_assigned_seat, :last_assigned_seat])
    |> validate_number(attrs, [:last_assigned_seat, greater_than: -2])
  end
end
