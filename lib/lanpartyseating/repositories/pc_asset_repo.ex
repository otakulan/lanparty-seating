defmodule Lanpartyseating.PcAsset do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pc_assets" do
    field :code, :string
    field :hostname, :string
    field :remote_identifier, :string
    field :status, :string, default: "ready"
    field :metadata, :map, default: %{}
    field :deleted_at, :utc_datetime

    has_one :seat_slot_assignment, Lanpartyseating.SeatSlotAssignment

    timestamps()
  end

  def changeset(pc_asset, attrs) do
    pc_asset
    |> cast(attrs, [:code, :hostname, :remote_identifier, :status, :metadata, :deleted_at])
    |> validate_required([:code, :status])
    |> validate_length(:code, min: 1, max: 255)
    |> validate_inclusion(:status, ["ready", "broken", "offline"])
    |> unique_constraint(:code)
    |> unique_constraint(:hostname)
  end
end
