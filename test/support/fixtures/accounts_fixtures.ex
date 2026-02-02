defmodule Lanpartyseating.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lanpartyseating.Accounts` context.
  """

  alias Lanpartyseating.Accounts
  alias Lanpartyseating.Accounts.Scope
  alias Lanpartyseating.BadgesLogic

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def unique_user_name, do: "Test User #{System.unique_integer([:positive])}"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_user_name(),
      email: unique_user_email(),
      password: valid_user_password(),
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.create_user()

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  @doc """
  Creates an admin badge (a badge with is_admin: true).
  """
  def admin_badge_fixture(attrs \\ %{}) do
    uid = "BADGE-#{System.unique_integer([:positive])}"

    {:ok, badge} =
      attrs
      |> Enum.into(%{
        serial_key: uid,
        uid: uid,
        label: "Test Badge",
        is_admin: true,
        is_banned: false,
      })
      |> BadgesLogic.create_badge()

    badge
  end

  def admin_badge_scope_fixture do
    badge = admin_badge_fixture()
    Scope.for_badge(badge)
  end

  @doc """
  Creates a regular attendee badge (non-admin).
  """
  def badge_fixture(attrs \\ %{}) do
    uid = "ATTENDEE-#{System.unique_integer([:positive])}"

    {:ok, badge} =
      attrs
      |> Enum.into(%{
        serial_key: uid,
        uid: uid,
        is_admin: false,
        is_banned: false,
      })
      |> BadgesLogic.create_badge()

    badge
  end
end
