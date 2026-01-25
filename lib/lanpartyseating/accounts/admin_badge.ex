defmodule Lanpartyseating.Accounts.AdminBadge do
  @moduledoc """
  Schema for admin badges that allow emergency backdoor authentication.
  Badge-authenticated sessions have limited permissions (cannot manage users/badges).
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "admin_badges" do
    field :badge_number, :string
    field :label, :string
    field :enabled, :boolean, default: true

    timestamps()
  end

  @doc """
  Changeset for creating or updating an admin badge.
  """
  def changeset(admin_badge, attrs) do
    admin_badge
    |> cast(attrs, [:badge_number, :label, :enabled])
    |> validate_required([:badge_number, :label])
    |> validate_length(:badge_number, min: 1, max: 100)
    |> validate_length(:label, min: 1, max: 255)
    |> unique_constraint(:badge_number)
  end
end
