defmodule Lanpartyseating.AccountsTest do
  use Lanpartyseating.DataCase

  alias Lanpartyseating.Accounts

  import Lanpartyseating.AccountsFixtures
  alias Lanpartyseating.Accounts.{User, UserToken}
  alias Lanpartyseating.Badge

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "create_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.create_user(%{password: valid_user_password()})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.create_user(%{email: "not valid", password: valid_user_password()})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.create_user(%{email: too_long, password: valid_user_password()})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.create_user(%{email: email, password: valid_user_password()})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.create_user(%{email: String.upcase(email), password: valid_user_password()})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates password length" do
      {:error, changeset} = Accounts.create_user(%{email: unique_user_email(), password: "short"})
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "creates users with name, email and password" do
      email = unique_user_email()
      name = unique_user_name()

      {:ok, user} =
        Accounts.create_user(%{name: name, email: email, password: valid_user_password()})

      assert user.name == name
      assert user.email == email
      assert user.hashed_password != nil
      assert is_nil(user.password)
    end
  end

  describe "list_users/0" do
    test "returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end
  end

  describe "delete_user/1" do
    test "deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session",
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  # Admin Badges (now using merged Badge table)

  describe "get_enabled_admin_badge/1" do
    test "returns admin badge by UID" do
      badge = admin_badge_fixture()
      assert %Badge{id: id} = Accounts.get_enabled_admin_badge(badge.uid)
      assert id == badge.id
    end

    test "returns admin badge with case-insensitive UID lookup" do
      badge = admin_badge_fixture()
      # UID is stored uppercase, but lookup should work with lowercase
      assert %Badge{id: id} = Accounts.get_enabled_admin_badge(String.downcase(badge.uid))
      assert id == badge.id
    end

    test "does not return non-admin badge" do
      badge = badge_fixture()
      refute Accounts.get_enabled_admin_badge(badge.uid)
    end

    test "does not return banned admin badge" do
      badge = admin_badge_fixture()
      {:ok, _} = Lanpartyseating.BadgesLogic.update_badge(badge, %{is_banned: true})
      refute Accounts.get_enabled_admin_badge(badge.uid)
    end

    test "returns nil for non-existent badge" do
      refute Accounts.get_enabled_admin_badge("NON-EXISTENT")
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
