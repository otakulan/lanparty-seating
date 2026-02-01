defmodule LanpartyseatingWeb.Plugs.ScannerAuthTest do
  # async: false because ScannerAuth spawns a Task that needs DB access
  use LanpartyseatingWeb.ConnCase, async: false

  alias LanpartyseatingWeb.Plugs.ScannerAuth

  import Lanpartyseating.ScannerFixtures

  setup do
    # WiFi config required before creating scanners
    wifi_config_fixture()
    :ok
  end

  describe "call/2" do
    test "assigns scanner on valid token", %{conn: conn} do
      {scanner, token} = scanner_fixture()

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> ScannerAuth.call([])

      assert conn.assigns.scanner.id == scanner.id
      refute conn.halted
    end

    test "returns 401 with missing Authorization header", %{conn: conn} do
      conn = ScannerAuth.call(conn, [])

      assert conn.halted
      assert conn.status == 401

      assert Jason.decode!(conn.resp_body) == %{
               "status" => "error",
               "message" => "Missing or invalid Authorization header",
             }
    end

    test "returns 401 with invalid Authorization header format", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Basic sometoken")
        |> ScannerAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert Jason.decode!(conn.resp_body)["message"] == "Missing or invalid Authorization header"
    end

    test "returns 401 with invalid token", %{conn: conn} do
      scanner_fixture()

      conn =
        conn
        |> put_req_header("authorization", "Bearer lpss_invalidtoken1234567890123456789012")
        |> ScannerAuth.call([])

      assert conn.halted
      assert conn.status == 401

      assert Jason.decode!(conn.resp_body) == %{
               "status" => "error",
               "message" => "Invalid token",
             }
    end

    test "updates last_seen_at asynchronously", %{conn: conn} do
      {scanner, token} = scanner_fixture()
      assert is_nil(scanner.last_seen_at)

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> ScannerAuth.call([])

      # Give the async task time to complete
      Process.sleep(50)

      {:ok, updated} = Lanpartyseating.ScannerLogic.get_scanner(scanner.id)
      assert updated.last_seen_at != nil
    end
  end
end
