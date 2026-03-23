defmodule Lanpartyseating.SeatSlotStatus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "seat_slot_statuses" do
    field :is_broken, :boolean, default: false
    field :reason, :string

    belongs_to :seat_slot, Lanpartyseating.SeatSlot

    timestamps()
  end

  def changeset(status, attrs) do
    status
    |> cast(attrs, [:seat_slot_id, :is_broken, :reason])
    |> validate_required([:seat_slot_id])
    |> unique_constraint(:seat_slot_id)
  end
end
