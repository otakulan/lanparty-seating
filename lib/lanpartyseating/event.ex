defmodule Lanpartyseating.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :layout_id, :integer
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:layout_id, :name])
    |> validate_required([:layout_id, :name])
  end
end
