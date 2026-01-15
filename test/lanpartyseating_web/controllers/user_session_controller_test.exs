defmodule LanpartyseatingWeb.UserSessionControllerTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Lanpartyseating.AccountsFixtures
  import LanpartyseatingWeb.ConnCase

  setup do
    %{user: user_fixture()}
  end

  describe "GET /login" do
    test "renders login page", %{conn: conn} do
      conn = get(conn, ~p"/login")
      response = html_response(conn, 200)
      assert response =~ "Admin Login"
      assert response =~ "Connexion admin"
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/login")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /login - email and password" do
    test "logs the user in with valid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()},
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "sets remember me cookie", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true",
          },
        })

      assert conn.resp_cookies["_lanpartyseating_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to return_to path when set", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/tournaments")
        |> post(~p"/login", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
          },
        })

      assert redirected_to(conn) == "/tournaments"
    end

    test "shows error with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => "wrong_password"},
        })

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
      assert response =~ "Courriel ou mot de passe invalide"
    end

    test "shows error with non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => "nobody@example.com", "password" => "any_password"},
        })

      response = html_response(conn, 200)
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /logout" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/logout")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out"
    end

    test "succeeds even if not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/logout")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end
  end
end
