defmodule Lanpartyseating.SeatSlotAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "seat_slot_assignments" do
    field :deleted_at, :utc_datetime

    belongs_to :seat_slot, Lanpartyseating.SeatSlot
    belongs_to :pc_asset, Lanpartyseating.PcAsset

    timestamps()
  end

  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:seat_slot_id, :pc_asset_id, :deleted_at])
    |> validate_required([:seat_slot_id, :pc_asset_id])
    |> unique_constraint(:seat_slot_id)
    |> unique_constraint(:pc_asset_id)
  end
end
