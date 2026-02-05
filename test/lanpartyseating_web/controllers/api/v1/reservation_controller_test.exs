defmodule LanpartyseatingWeb.Api.V1.ReservationControllerTest do
  # async: false because ScannerAuth spawns a Task that needs DB access
  use LanpartyseatingWeb.ConnCase, async: false

  alias Lanpartyseating.Repo
  alias Lanpartyseating.Badge
  alias Lanpartyseating.Station
  alias Lanpartyseating.StationLayout
  alias Lanpartyseating.Reservation

  import Lanpartyseating.ScannerFixtures

  # ============================================================================
  # Setup Helpers
  # ============================================================================

  defp create_test_badge(uid) do
    %Badge{}
    |> Badge.changeset(%{uid: String.upcase(uid), serial_key: "SERIAL-#{uid}"})
    |> Repo.insert!()
  end

  defp create_test_station(station_number) do
    # Create layout first (required by foreign key)
    # Use station_number as x coordinate to ensure uniqueness
    %StationLayout{}
    |> StationLayout.changeset(%{station_number: station_number, x: station_number, y: 0})
    |> Repo.insert!()

    %Station{}
    |> Station.changeset(%{station_number: station_number})
    |> Repo.insert!()
  end

  defp create_reservation(badge, station_number) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    end_time = DateTime.add(now, 60, :minute)

    %Reservation{}
    |> Reservation.changeset(%{
      badge: badge.serial_key,
      station_id: station_number,
      duration: 60,
      start_date: now,
      end_date: end_time,
    })
    |> Repo.insert!()
  end

  setup do
    wifi_config_fixture()
    :ok
  end

  # Note: Authentication edge cases (missing token, invalid token, revoked token)
  # are tested in ScannerAuthTest. This file focuses on business logic.

  describe "POST /api/v1/reservations/cancel" do
    setup %{conn: conn} do
      {_scanner, token} = scanner_fixture()
      conn = put_req_header(conn, "authorization", "Bearer #{token}")
      %{conn: conn}
    end

    test "returns 200 and cancels reservation for valid badge", %{conn: conn} do
      badge = create_test_badge("TEST123")
      station = create_test_station(1)
      _reservation = create_reservation(badge, station.station_number)

      conn = post(conn, ~p"/api/v1/reservations/cancel", %{"badge_uid" => "test123"})

      response = json_response(conn, 200)
      assert response["status"] == "ok"
      assert response["message"] =~ "Reservation cancelled"

      # Verify reservation was soft-deleted
      reservation = Repo.one(Reservation)
      assert reservation.deleted_at != nil
    end

    test "returns 404 for unknown badge", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/reservations/cancel", %{"badge_uid" => "NONEXISTENT"})

      assert json_response(conn, 404) == %{
               "status" => "error",
               "message" => "Unknown badge",
             }
    end

    test "returns 404 for badge with no active reservation", %{conn: conn} do
      _badge = create_test_badge("NORESERVATION")

      conn = post(conn, ~p"/api/v1/reservations/cancel", %{"badge_uid" => "noreservation"})

      assert json_response(conn, 404) == %{
               "status" => "error",
               "message" => "No active reservation found for this badge",
             }
    end

    test "returns 400 for missing badge_uid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/reservations/cancel", %{})

      assert json_response(conn, 400) == %{
               "status" => "error",
               "message" => "badge_uid is required",
             }
    end

    test "returns 400 for empty badge_uid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/reservations/cancel", %{"badge_uid" => ""})

      assert json_response(conn, 400) == %{
               "status" => "error",
               "message" => "badge_uid is required",
             }
    end

    test "badge_uid is case-insensitive", %{conn: conn} do
      badge = create_test_badge("UPPERCASE")
      station = create_test_station(2)
      _reservation = create_reservation(badge, station.station_number)

      # Send lowercase
      conn = post(conn, ~p"/api/v1/reservations/cancel", %{"badge_uid" => "uppercase"})

      response = json_response(conn, 200)
      assert response["status"] == "ok"
    end

    test "does not cancel already cancelled reservation", %{conn: conn} do
      badge = create_test_badge("CANCELLED")
      station = create_test_station(3)
      reservation = create_reservation(badge, station.station_number)

      # Manually soft-delete the reservation
      reservation
      |> Reservation.changeset(%{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})
      |> Repo.update!()

      conn = post(conn, ~p"/api/v1/reservations/cancel", %{"badge_uid" => "cancelled"})

      assert json_response(conn, 404) == %{
               "status" => "error",
               "message" => "No active reservation found for this badge",
             }
    end

    test "cancels all reservations for badge with multiple active reservations", %{conn: conn} do
      badge = create_test_badge("MULTI")
      station1 = create_test_station(10)
      station2 = create_test_station(11)
      _reservation1 = create_reservation(badge, station1.station_number)
      _reservation2 = create_reservation(badge, station2.station_number)

      conn = post(conn, ~p"/api/v1/reservations/cancel", %{"badge_uid" => "MULTI"})

      response = json_response(conn, 200)
      assert response["status"] == "ok"
      assert response["message"] =~ "Reservations cancelled"
      assert response["message"] =~ "10"
      assert response["message"] =~ "11"

      # Verify both reservations were soft-deleted
      import Ecto.Query
      reservations = Repo.all(from r in Reservation, where: r.badge == ^badge.serial_key)
      assert length(reservations) == 2
      assert Enum.all?(reservations, &(&1.deleted_at != nil))
    end
  end
end
