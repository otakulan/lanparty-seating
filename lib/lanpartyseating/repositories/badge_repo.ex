defmodule Lanpartyseating.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "badges" do
    field :serial_key, :string
    field :uid, :string
    field :is_banned, :boolean, default: false
    field :is_admin, :boolean, default: false
    field :label, :string
    timestamps()
  end

  @doc """
  Changeset for creating or updating a badge.
  """
  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [:serial_key, :uid, :is_banned, :is_admin, :label])
    |> validate_required([:serial_key, :uid])
    |> validate_length(:serial_key, min: 1, max: 255)
    |> validate_length(:uid, min: 1, max: 255)
    |> update_change(:uid, &String.upcase/1)
    |> unique_constraint(:uid)
    |> check_constraint(:is_banned,
      name: :admin_cannot_be_banned,
      message: "admin badges cannot be banned"
    )
  end

  @doc """
  Changeset for CSV import (minimal validation, bulk insert).
  """
  def import_changeset(badge, attrs) do
    badge
    |> cast(attrs, [:serial_key, :uid])
    |> validate_required([:serial_key, :uid])
    |> update_change(:uid, &String.upcase/1)
    |> unique_constraint(:uid)
  end

  @doc """
  Returns the display label for the badge.
  Falls back to serial_key if no custom label is set.
  """
  def display_label(%__MODULE__{label: label, serial_key: serial_key}) do
    if label && label != "", do: label, else: serial_key
  end
end
