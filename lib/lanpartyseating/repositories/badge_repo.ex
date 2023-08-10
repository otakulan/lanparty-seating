defmodule Lanpartyseating.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "badges" do
    field(:serial_key, :string)
    field(:uid, :string)
    field(:is_banned, :boolean, default: false)
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:serial_key, :uid])
    |> validate_required([:serial_key, :uid])
  end
end
