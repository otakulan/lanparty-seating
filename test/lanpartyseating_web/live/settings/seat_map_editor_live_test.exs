defmodule LanpartyseatingWeb.Settings.SeatMapEditorLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lanpartyseating.AccountsFixtures
  import LanpartyseatingWeb.ConnCase

  alias Lanpartyseating.Repo
  alias Lanpartyseating.RoomsLogic
  alias Lanpartyseating.SeatMap
  alias Lanpartyseating.SeatMapsLogic
  alias Lanpartyseating.Setting

  # ============================================================================
  # Setup helpers
  # ============================================================================

  defp create_room!(attrs \\ %{}) do
    base = %{
      name: "Room #{System.unique_integer([:positive])}",
      width: 500,
      height: 500,
      first_map_name: "Main Layout"
    }

    {:ok, room} = RoomsLogic.create_room(Map.merge(base, attrs))
    room
  end

  defp set_active_room_id!(room_id) do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{active_room_id: room_id})
    |> Repo.update!()
  end

  defp first_map(room) do
    [map] = SeatMapsLogic.list_seat_maps(room.id)
    Repo.get!(SeatMap, map.id)
  end

  setup %{conn: conn} do
    room = create_room!()
    set_active_room_id!(room.id)
    map = first_map(room)

    {:ok, conn: log_in_user(conn, user_fixture()), room: room, map: map}
  end

  # ============================================================================
  # Loading
  # ============================================================================

  describe "mount" do
    test "loads the editor for a map", %{conn: conn, map: map} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps/#{map.public_id}/edit")

      assert has_element?(view, "h1", "Seat Map Editor")
      assert render(view) =~ map.name
    end

    test "redirects to the catalogue for an unknown map", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/settings/seat-maps/nosuchid/edit")
      assert path == ~p"/settings/seat-maps"
    end
  end

  # ============================================================================
  # Rename
  # ============================================================================

  describe "rename" do
    test "the pencil swaps the name for an input", %{conn: conn, map: map} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps/#{map.public_id}/edit")

      refute has_element?(view, ~s|input[phx-blur="rename_map"]|)

      view |> element(~s|button[phx-click="edit_map_name"]|) |> render_click()

      assert has_element?(view, ~s|input[name="value"][value="#{map.name}"][phx-blur="rename_map"]|)
    end

    test "blurring saves the new name", %{conn: conn, map: map} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps/#{map.public_id}/edit")

      view |> element(~s|button[phx-click="edit_map_name"]|) |> render_click()

      # phx-blur reports the element's value under "value", never "name"
      html =
        view
        |> element(~s|input[phx-blur="rename_map"]|)
        |> render_blur(%{"value" => "Renamed Layout"})

      assert html =~ "Renamed Layout"
      assert Repo.get!(SeatMap, map.id).name == "Renamed Layout"
      refute has_element?(view, ~s|input[phx-blur="rename_map"]|)
    end

    test "a duplicate name flashes an error and keeps the old name", %{conn: conn, room: room, map: map} do
      {:ok, _other} = SeatMapsLogic.create_seat_map(%{room_id: room.id, name: "Taken Layout"})

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps/#{map.public_id}/edit")

      view |> element(~s|button[phx-click="edit_map_name"]|) |> render_click()

      html =
        view
        |> element(~s|input[phx-blur="rename_map"]|)
        |> render_blur(%{"value" => "Taken Layout"})

      assert html =~ "has already been taken"
      assert Repo.get!(SeatMap, map.id).name == "Main Layout"
    end
  end
end
