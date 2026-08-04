defmodule LanpartyseatingWeb.Settings.SeatMapsLiveTest do
  use LanpartyseatingWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lanpartyseating.AccountsFixtures
  import LanpartyseatingWeb.ConnCase

  alias Lanpartyseating.Repo
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

    {:ok, room} = SeatMapsLogic.create_room(Map.merge(base, attrs))
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
      |> form("#rename-map-#{map_id}", %{"name" => "New Name", "map_id" => map_id})
      |> render_submit()

      assert has_element?(view, ~s|input[value="New Name"]|)
      refute has_element?(view, ~s|input[value="Main Layout"]|)
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

    test "published map's delete is disabled", %{conn: conn, room: room} do
      map_id = map_id(room, "Main Layout")
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)

      {:ok, view, _html} = live(conn, ~p"/settings/seat-maps")

      assert has_element?(view, ~s|button[disabled]|)
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

      names = SeatMapsLogic.list_rooms() |> Enum.map(& &1.name)
      assert [name] = Enum.filter(names, &String.match?(&1, ~r/^[a-z]+-[a-z]+-[a-z]+$/))

      assert render(view) =~ name
    end
  end
end
