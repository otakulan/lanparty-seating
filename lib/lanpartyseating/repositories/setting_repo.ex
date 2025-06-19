defmodule Lanpartyseating.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "settings" do
    field :row_padding, :integer, default: 1
    field :column_padding, :integer, default: 1
    field :horizontal_trailing, :integer
    field :vertical_trailing, :integer
    field :deleted_at, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:row_padding, :column_padding, :horizontal_trailing, :vertical_trailing, :deleted_at])
    |> validate_number(:row_padding, greater_than: -1)
    |> validate_number(:column_padding, greater_than: -1)
  end
end
