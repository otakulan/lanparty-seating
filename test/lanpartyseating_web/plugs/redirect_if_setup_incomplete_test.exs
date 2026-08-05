defmodule LanpartyseatingWeb.RedirectIfSetupIncompleteTest do
  use LanpartyseatingWeb.ConnCase, async: false

  import Plug.Conn

  alias Lanpartyseating.Repo
  alias Lanpartyseating.Setting

  defp set_setup_state!(state) do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{setup_state: state})
    |> Repo.update!()
  end

  describe "when setup is incomplete" do
    setup do
      set_setup_state!(:not_started)
      :ok
    end

    test "redirects every browser route to /setup", %{conn: conn} do
      for path <- [~p"/", ~p"/map", ~p"/stations", ~p"/kiosk", ~p"/login", ~p"/settings"] do
        conn = get(conn, path)
        assert conn.status == 302
        assert redirected_to(conn) == ~p"/setup"
      end
    end

    test "lets /setup through", %{conn: conn} do
      conn = get(conn, ~p"/setup")
      refute redirected_from?(conn)
    end

    test "lets probe and api paths through", %{conn: conn} do
      for path <- ["/livez", "/readyz", "/healthz", "/api/openapi"] do
        conn = get(conn, path)
        refute redirected_from?(conn)
      end
    end
  end

  describe "when setup is complete" do
    setup do
      Repo.get!(Setting, 1)
      |> Setting.changeset(%{active_room_id: nil})
      |> Repo.update!()

      :ok
    end

    test "does not redirect public routes", %{conn: conn} do
      conn = get(conn, ~p"/")
      refute redirected_from?(conn)
    end
  end

  defp redirected_from?(conn) do
    conn.status == 302 and get_resp_header(conn, "location") != []
  end
end
