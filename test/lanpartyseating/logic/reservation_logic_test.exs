defmodule Lanpartyseating.ReservationLogicTest do
  use Lanpartyseating.DataCase, async: false

  alias Lanpartyseating.ReservationLogic
  alias Lanpartyseating.Repo
  alias Lanpartyseating.Badge
  alias Lanpartyseating.Station
  alias Lanpartyseating.StationLayout
  alias Lanpartyseating.Setting

  # ============================================================================
  # Setup Helpers
  # ============================================================================

  defp create_badge(attrs) do
    uid = attrs[:uid] || "BADGE-#{System.unique_integer([:positive])}"

    %Badge{}
    |> Badge.changeset(
      Map.merge(
        %{uid: String.upcase(uid), serial_key: "SERIAL-#{uid}", is_banned: false, is_admin: false},
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp create_station do
    # Use unique station number to avoid conflicts with seed data or parallel tests
    station_number = System.unique_integer([:positive])

    # Create layout first (required by foreign key)
    %StationLayout{}
    |> StationLayout.changeset(%{station_number: station_number, x: station_number, y: 0})
    |> Repo.insert!()

    %Station{}
    |> Station.changeset(%{station_number: station_number})
    |> Repo.insert!()
  end

  defp create_settings do
    %Setting{}
    |> Setting.changeset(%{row_padding: 2, column_padding: 1})
    |> Repo.insert!()
  end

  setup do
    create_settings()
    :ok
  end

  # ============================================================================
  # create_reservation/3 Tests
  # ============================================================================

  describe "create_reservation/3" do
    test "creates reservation for valid badge and station" do
      badge = create_badge(%{uid: "VALID001"})
      station = create_station()

      assert {:ok, reservation} = ReservationLogic.create_reservation(station.station_number, 45, badge.uid)
      assert reservation.badge == badge.serial_key
      assert reservation.station_id == station.station_number
      assert reservation.duration == 45
    end

    test "rejects reservation for banned badge" do
      badge = create_badge(%{uid: "BANNED001", is_banned: true})
      station = create_station()

      assert {:error, message} = ReservationLogic.create_reservation(station.station_number, 45, badge.uid)
      assert message == "This badge has been banned and cannot make reservations"
    end

    test "rejects reservation for unknown badge" do
      station = create_station()

      assert {:error, message} = ReservationLogic.create_reservation(station.station_number, 45, "NONEXISTENT")
      assert message == "Unknown badge serial number"
    end

    test "rejects reservation with empty badge uid" do
      station = create_station()

      assert {:error, message} = ReservationLogic.create_reservation(station.station_number, 45, "")
      assert message == "Please fill all the fields"
    end
  end
end
