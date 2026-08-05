defmodule LanpartyseatingWeb.SetupLoginControllerTest do
  use LanpartyseatingWeb.ConnCase, async: false

  import Phoenix.ConnTest

  alias Lanpartyseating.Accounts.User
  alias Lanpartyseating.Repo
  alias Lanpartyseating.Setting

  defp set_setup_state!(state) do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{setup_state: state, active_room_id: nil})
    |> Repo.update!()
  end

  defp account_params do
    %{
      "name" => "Operator",
      "email" => "operator+setup@example.com",
      "password" => "a-very-long-password",
      "password_confirmation" => "a-very-long-password",
    }
  end

  describe "POST /setup/login" do
    setup do
      set_setup_state!(:not_started)
      :ok
    end

    test "creates the admin and logs in, redirecting to /setup", %{conn: conn} do
      conn = post(conn, ~p"/setup/login", %{"user" => account_params()})

      assert redirected_to(conn, 302) == ~p"/setup"
      assert Repo.aggregate(User, :count, :id) == 1

      token = get_session(conn, :user_token)
      assert is_binary(token)

      assert {_user, _inserted_at} =
               Lanpartyseating.Accounts.get_user_by_session_token(token)
    end

    test "rejects an invalid password without creating a user", %{conn: conn} do
      conn =
        post(
          conn,
          ~p"/setup/login",
          %{
            "user" =>
              %{
                "name" => "Operator",
                "email" => "operator+setup@example.com",
                "password" => "short",
                "password_confirmation" => "short",
              },
          }
        )

      assert redirected_to(conn, 302) == ~p"/setup"
      assert Repo.aggregate(User, :count, :id) == 0
    end

    test "is rejected once setup has progressed past account creation", %{conn: conn} do
      set_setup_state!(:room_created)

      conn = post(conn, ~p"/setup/login", %{"user" => account_params()})

      assert redirected_to(conn, 302) == ~p"/setup"
      assert Repo.aggregate(User, :count, :id) == 0
    end
  end
end
