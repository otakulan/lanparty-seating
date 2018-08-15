defmodule Lanpartyseating.Reservation do
  use Ecto.Schema
  import Ecto.Changeset


  schema "reservation" do
    field :UID, :string
    field :column, :integer
    field :row, :integer

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
