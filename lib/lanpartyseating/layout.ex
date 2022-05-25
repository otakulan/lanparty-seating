defmodule Lanpartyseating.Layout do
  use Ecto.Schema
  import Ecto.Changeset

  schema "layouts" do
    field :cols, :integer
    field :rows, :integer

    timestamps()
  end

  @doc false
  def changeset(layout, attrs) do
    layout
    |> cast(attrs, [:rows, :cols])
    |> validate_required([:rows, :cols])
  end
end
