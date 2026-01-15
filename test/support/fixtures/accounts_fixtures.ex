defmodule Lanpartyseating.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lanpartyseating.Accounts` context.
  """

  alias Lanpartyseating.Accounts
  alias Lanpartyseating.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
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

  def admin_badge_fixture(attrs \\ %{}) do
    {:ok, badge} =
      attrs
      |> Enum.into(%{
        badge_number: "BADGE-#{System.unique_integer([:positive])}",
        label: "Test Badge",
        enabled: true,
      })
      |> Accounts.create_admin_badge()

    badge
  end

  def admin_badge_scope_fixture do
    badge = admin_badge_fixture()
    Scope.for_badge(badge)
  end
end
