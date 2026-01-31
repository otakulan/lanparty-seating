defmodule Lanpartyseating.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "settings" do
    field :row_padding, :integer, default: 1
    field :column_padding, :integer, default: 1
    timestamps()
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:row_padding, :column_padding])
    |> validate_number(:row_padding, greater_than_or_equal_to: 0)
    |> validate_number(:column_padding, greater_than_or_equal_to: 0)
  end
end
