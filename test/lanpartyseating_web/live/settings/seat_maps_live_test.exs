defmodule LanpartyseatingWeb.Settings.SeatMapsLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lanpartyseating.AccountsFixtures
  import LanpartyseatingWeb.ConnCase

  alias Lanpartyseating.Repo
  alias Lanpartyseating.Room
  alias Lanpartyseating.RoomsLogic
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

  defp map_id(room, name) do
    SeatMapsLogic.list_seat_maps(room.id)
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:id)
  end

  # ============================================================================
  # Authentication
  # ============================================================================

  describe "authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/settings/seat-maps")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "accessible with user auth", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture())
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")
      assert has_element?(view, "h1", "Seat Maps")
    end
  end

  # ============================================================================
  # Catalogue rendering
  # ============================================================================

  describe "catalogue" do
    setup %{conn: conn} do
      room = create_room!()
      set_active_room_id!(room.id)
      {:ok, conn: log_in_user(conn, user_fixture()), room: room}
    end

    test "lists the Room's maps with the published one marked", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      assert has_element?(view, ~s|input[value="Main Layout"]|)
      assert has_element?(view, ~s|tr .badge.badge-success|, "Published")
    end

    test "rename updates the map name inline", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view
      |> form("#rename-map-#{map_id}", %{"value" => "New Name", "map_id" => map_id})
      |> render_submit()

      assert has_element?(view, ~s|input[value="New Name"]|)
      refute has_element?(view, ~s|input[value="Main Layout"]|)
    end

    test "blurring the map name input renames it", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      # phx-blur reports the element value as "value" and picks up phx-value-map_id
      view
      |> element(~s|#rename-map-#{map_id} input[phx-blur="rename_map"]|)
      |> render_blur(%{"value" => "Blurred Name", "map_id" => to_string(map_id)})

      assert has_element?(view, ~s|input[value="Blurred Name"]|)
    end

    test "duplicate creates a suffixed copy", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")
      versions = SeatMapsLogic.list_versions(map_id)
      [version] = versions

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view
      |> form("#duplicate-map-#{map_id}", %{"version_id" => version.id, "map_id" => map_id})
      |> render_submit()

      assert has_element?(view, ~s|input[value="Main Layout (2)"]|)
    end

    test "publish makes an unpublished map live", %{conn: conn, room: room} do
      {:ok, second} = SeatMapsLogic.create_seat_map(%{room_id: room.id, name: "Second Layout"})
      second_id = second.id

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view
      |> element(~s|button[phx-click="open_publish"][phx-value-map_id="#{second_id}"]|)
      |> render_click()

      assert has_element?(view, ~s|.modal.modal-open|)

      view
      |> element(~s|button[phx-click="confirm_publish"]|)
      |> render_click()

      # Second Layout is now the published one
      assert has_element?(view, ~s|tr .badge.badge-success|, "Published")
    end

    test "publish is disabled once the room already publishes the map's newest version", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")
      refute has_element?(view, ~s|button[phx-click="open_publish"][disabled]|)

      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")
      assert has_element?(view, ~s|button[phx-click="open_publish"][disabled]|)
    end

    test "publish is re-enabled after a new version is saved", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)
      {:ok, _} = SeatMapsLogic.save_version(map_id, %{"data" => %{"seats" => [], "objects" => []}}, 1)

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      refute has_element?(view, ~s|button[phx-click="open_publish"][disabled]|)
    end

    test "published map's delete is disabled", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      assert has_element?(view, ~s|button[phx-click="delete_map"][disabled]|)
    end
  end

  # ============================================================================
  # Room creation
  # ============================================================================

  describe "new room" do
    setup %{conn: conn} do
      {:ok, conn: log_in_user(conn, user_fixture())}
    end

    test "creates a room with a random animal name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view
      |> element(~s|button[phx-click="new_room"]|)
      |> render_click()

      names = RoomsLogic.list_rooms() |> Enum.map(& &1.name)
      assert [name] = Enum.filter(names, &String.match?(&1, ~r/^[a-z]+-[a-z]+-[a-z]+$/))

      assert render(view) =~ name
    end
  end

  # ============================================================================
  # Room deletion
  # ============================================================================

  describe "delete room" do
    setup %{conn: conn} do
      {:ok, conn: log_in_user(conn, user_fixture())}
    end

    test "is disabled while the active room is selected", %{conn: conn} do
      active = create_room!()
      set_active_room_id!(active.id)
      _other = create_room!()

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      assert has_element?(view, ~s|button[phx-click="open_delete_room"][disabled]|)
    end

    test "is disabled when only one room exists", %{conn: conn} do
      room = create_room!()
      set_active_room_id!(room.id)

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      assert has_element?(view, ~s|button[phx-click="open_delete_room"][disabled]|)
    end

    test "confirming deletes the selected room and its maps", %{conn: conn} do
      active = create_room!()
      set_active_room_id!(active.id)
      doomed = create_room!(%{name: "Doomed Room"})

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view |> form("form[phx-change='select_room']", %{"room_id" => doomed.id}) |> render_change()

      view |> element(~s|button[phx-click="open_delete_room"]|) |> render_click()
      assert render(view) =~ "Delete &quot;Doomed Room&quot;?"

      view |> element(~s|button[phx-click="confirm_delete_room"]|) |> render_click()

      refute Enum.any?(RoomsLogic.list_rooms(), &(&1.id == doomed.id))
      assert SeatMapsLogic.list_seat_maps(doomed.id) == []
    end
  end

  # ============================================================================
  # Room selection and rename
  # ============================================================================

  describe "room selector" do
    setup %{conn: conn} do
      {:ok, conn: log_in_user(conn, user_fixture())}
    end

    test "scopes the catalogue without changing the active room", %{conn: conn} do
      active = create_room!()
      set_active_room_id!(active.id)
      other = create_room!()
      {:ok, _} = SeatMapsLogic.create_seat_map(%{room_id: other.id, name: "Other Layout"})

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view |> form("form[phx-change='select_room']", %{"room_id" => other.id}) |> render_change()

      assert has_element?(view, ~s|input[value="Other Layout"]|)
      assert Repo.get!(Setting, 1).active_room_id == active.id
    end
  end

  describe "room rename" do
    setup %{conn: conn} do
      room = create_room!(%{name: "Original Room"})
      set_active_room_id!(room.id)
      {:ok, conn: log_in_user(conn, user_fixture()), room: room}
    end

    test "the edit icon swaps the title for an input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      refute has_element?(view, ~s|form[phx-submit="save_room_name"] input|)

      view |> element(~s|button[phx-click="edit_room_name"]|) |> render_click()

      assert has_element?(view, ~s|input[name="value"][value="Original Room"][phx-blur="save_room_name"]|)
    end

    test "blurring saves the new name", %{conn: conn, room: room} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view |> element(~s|button[phx-click="edit_room_name"]|) |> render_click()
      html = view |> element(~s|form[phx-submit="save_room_name"] input|) |> render_blur(%{"value" => "Renamed Room"})

      assert html =~ "Renamed Room"
      assert Repo.get!(Room, room.id).name == "Renamed Room"
      refute has_element?(view, ~s|form[phx-submit="save_room_name"] input|)
    end

    test "an empty name flashes an error and reverts the title", %{conn: conn, room: room} do
      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view |> element(~s|button[phx-click="edit_room_name"]|) |> render_click()
      html = view |> element(~s|form[phx-submit="save_room_name"] input|) |> render_blur(%{"value" => "  "})

      assert html =~ "Room name cannot be empty"
      assert html =~ "Original Room"
      assert Repo.get!(Room, room.id).name == "Original Room"
      refute has_element?(view, ~s|form[phx-submit="save_room_name"] input|)
    end

    test "a taken name flashes an error and reverts the title", %{conn: conn, room: room} do
      _other = create_room!(%{name: "Taken Room"})

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      view |> element(~s|button[phx-click="edit_room_name"]|) |> render_click()
      html = view |> element(~s|form[phx-submit="save_room_name"] input|) |> render_blur(%{"value" => "Taken Room"})

      assert html =~ "already exists"
      assert html =~ "Original Room"
      assert Repo.get!(Room, room.id).name == "Original Room"
      refute has_element?(view, ~s|form[phx-submit="save_room_name"] input|)
    end
  end
end
