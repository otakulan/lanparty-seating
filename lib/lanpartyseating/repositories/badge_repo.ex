defmodule Lanpartyseating.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "badges" do
    field :serial_key, :string
    field :uid, :string
    field :is_banned, :boolean, default: false
    timestamps()
  end

  @doc false
  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [:serial_key, :uid, :is_banned])
    |> validate_required([:serial_key, :uid])
    |> validate_length(:serial_key, min: 1, max: 255)
    |> validate_length(:uid, min: 1, max: 255)
  end
end
