defmodule Lanpartyseating.StationSwap do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "station_swaps" do
    field :this, :integer
    field :that, :integer
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:this, :that])
    |> validate_required([:this, :that])
    |> validate_number(:this, not_equal: :that)
    |> unique_constraint(:that)
    |> unique_constraint(:this)
  end
end
