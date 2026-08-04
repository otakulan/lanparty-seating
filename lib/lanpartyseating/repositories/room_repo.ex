defmodule Lanpartyseating.Room do
  @moduledoc """
  A physical space that holds Seats. Several may exist; only the Active Room is served.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "rooms" do
    field :name, :string
    field :public_id, :string
    field :width, :integer, default: 1920
    field :height, :integer, default: 1080
    field :deleted_at, :utc_datetime

    belongs_to :published_version, Lanpartyseating.SeatMapVersion,
      foreign_key: :published_version_id,
      references: :id

    has_many :seat_slots, Lanpartyseating.SeatSlot
    has_many :seat_maps, Lanpartyseating.SeatMap

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :public_id, :width, :height, :deleted_at])
    |> validate_required([:name, :public_id, :width, :height])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> unique_constraint([:public_id])
  end

  def create_changeset(room, attrs) do
    room
    |> changeset(Map.put(attrs, :public_id, Lanpartyseating.SeatMap.public_id()))
  end
end
