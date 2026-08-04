defmodule Lanpartyseating.SeatMap do
  @moduledoc """
  A named, saved arrangement of a Room's Seats. A Seat Map places Seats; it does not own them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @crockford_alphabet '0123456789abcdefghjkmnpqrstvwxyz'

  schema "seat_maps" do
    field :name, :string
    field :public_id, :string
    field :deleted_at, :utc_datetime

    belongs_to :room, Lanpartyseating.Room

    has_many :versions, Lanpartyseating.SeatMapVersion

    timestamps()
  end

  def changeset(seat_map, attrs) do
    seat_map
    |> cast(attrs, [:name, :public_id, :room_id, :deleted_at])
    |> validate_required([:name, :public_id, :room_id])
    |> validate_length(:name, min: 1, max: 255)
    |> unique_constraint([:room_id, :name])
    |> unique_constraint([:public_id])
  end

  @doc """
  Changeset for creating a new Seat Map. Generates a unique Crockford base32 public_id.
  """
  def create_changeset(seat_map, attrs) do
    seat_map
    |> changeset(attrs)
    |> put_change(:public_id, public_id())
  end

  @doc """
  Generates an 8-character Crockford base32 public_id (used in URLs, shown muted in the UI).
  """
  def public_id do
    bytes = :crypto.strong_rand_bytes(5)

    alphabet = @crockford_alphabet

    chars =
      for <<b::5 <- bytes>> do
        :lists.nth(b + 1, alphabet)
      end

    List.to_string(chars)
    |> String.pad_trailing(8, "0")
  end
end
