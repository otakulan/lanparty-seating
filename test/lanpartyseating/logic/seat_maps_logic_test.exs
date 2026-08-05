defmodule Lanpartyseating.SeatMapsLogicTest do
  use Lanpartyseating.DataCase, async: false

  alias Lanpartyseating.Repo
  alias Lanpartyseating.RoomsLogic
  alias Lanpartyseating.Reservation
  alias Lanpartyseating.Room
  alias Lanpartyseating.SeatMapsLogic
  alias Lanpartyseating.Setting
  alias Lanpartyseating.Tournament

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

  defp first_map_id(room) do
    SeatMapsLogic.list_seat_maps(room.id)
    |> List.first()
    |> Map.fetch!(:id)
  end

  defp set_active_room_id!(room_id) do
    Repo.get!(Setting, 1)
    |> Setting.changeset(%{active_room_id: room_id})
    |> Repo.update!()
  end

  defp newest_version(seat_map_id) do
    SeatMapsLogic.list_versions(seat_map_id) |> List.first()
  end

  defp first_seat(map_id) do
    newest_version(map_id).data["seats"] |> List.first()
  end

  defp first_seat_slot_id(map_id) do
    case first_seat(map_id)["seat_slot_id"] do
      id when is_integer(id) -> id
      id when is_binary(id) -> String.to_integer(id)
    end
  end

  defp reload_room(room) do
    Repo.get!(Room, room.id) |> Repo.preload(:published_version)
  end

  defp seat_payload(label, x, y) do
    %{
      label: label,
      x: x,
      y: y,
      width: 88,
      height: 88,
      rotation: 0,
      shape: "rect",
      locked: false
    }
  end

  defp editor_attrs(seats, opts \\ %{}) do
    %{
      "revision" => 1,
      "seats" => seats,
      "objects" => [],
      "meta" => %{zoom: 1, minScale: 0.4, maxScale: 4},
      "width" => Map.get(opts, :width, 500),
      "height" => Map.get(opts, :height, 500),
      "background_kind" => "none",
      "background_value" => nil
    }
  end

  defp insert_active_reservation!(seat_slot_id) do
    now = DateTime.utc_now()

    %Reservation{}
    |> Reservation.changeset(%{
      badge: "SERIAL-#{System.unique_integer([:positive])}",
      seat_slot_id: seat_slot_id,
      start_date: DateTime.add(now, -10, :minute),
      end_date: DateTime.add(now, 10, :minute),
      duration: 20
    })
    |> Repo.insert!()
  end

  defp insert_tournament_underway!(name) do
    now = DateTime.utc_now()

    %Tournament{}
    |> Tournament.changeset(%{
      name: name,
      start_date: DateTime.add(now, -30, :minute),
      end_date: DateTime.add(now, 30, :minute)
    })
    |> Repo.insert!()
  end

  # ============================================================================
  # Rooms
  # ============================================================================

  describe "create_room/1" do
    test "produces a Room plus one unpublished empty Seat Map" do
      {:ok, room} = RoomsLogic.create_room(%{name: "Main Room", width: 640, height: 480, first_map_name: "Main Layout"})

      assert room.name == "Main Room"
      assert room.width == 640
      assert room.height == 480

      [map] = SeatMapsLogic.list_seat_maps(room.id)
      assert map.name == "Main Layout"
      refute map.published

      version = newest_version(map.id)
      assert version.revision == 1
      assert version.data["seats"] == []
    end

    test "sets active_room_id only when none was set" do
      set_active_room_id!(nil)

      {:ok, room} = RoomsLogic.create_room(%{name: "First Room", width: 100, height: 100})
      assert Repo.get!(Setting, 1).active_room_id == room.id

      # A second room must not steal the Active Room slot
      {:ok, _other} = RoomsLogic.create_room(%{name: "Second Room", width: 100, height: 100})
      assert Repo.get!(Setting, 1).active_room_id == room.id
    end
  end

  describe "set_active_room/1" do
    test "switches the Active Room and cancels reservations" do
      room1 = create_room!()
      set_active_room_id!(room1.id)
      map1 = first_map_id(room1)

      {:ok, _} = SeatMapsLogic.save_version(map1, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      {:ok, _} = SeatMapsLogic.publish_seat_map(map1)

      reservation = insert_active_reservation!(first_seat_slot_id(map1))

      room2 = create_room!()
      assert {:ok, %Room{id: id}} = RoomsLogic.set_active_room(room2.id)
      assert id == room2.id
      assert Repo.get!(Setting, 1).active_room_id == room2.id

      assert Repo.get!(Reservation, reservation.id).deleted_at != nil
    end

    test "is refused while a Tournament is underway" do
      insert_tournament_underway!("Ongoing Match")

      room1 = create_room!()
      set_active_room_id!(room1.id)
      room2 = create_room!()

      assert {:error, {:tournament_in_progress, "Ongoing Match"}} = RoomsLogic.set_active_room(room2.id)
      assert Repo.get!(Setting, 1).active_room_id == room1.id
    end
  end

  describe "rename_room/2" do
    test "trims and applies the new name" do
      room = create_room!(%{name: "Old Name"})

      assert {:ok, renamed} = RoomsLogic.rename_room(room.id, "  New Name  ")
      assert renamed.name == "New Name"
    end

    test "refuses a blank name" do
      room = create_room!(%{name: "Keeper"})

      assert {:error, :blank_name} = RoomsLogic.rename_room(room.id, "   ")
      assert Repo.get!(Room, room.id).name == "Keeper"
    end

    test "refuses a name another live Room already answers to, ignoring case" do
      _taken = create_room!(%{name: "Taken Name"})
      room = create_room!(%{name: "Keeper"})

      assert {:error, :name_taken} = RoomsLogic.rename_room(room.id, "taken name")
      assert Repo.get!(Room, room.id).name == "Keeper"
    end

    test "keeping its own name is allowed" do
      room = create_room!(%{name: "Same Name"})

      assert {:ok, renamed} = RoomsLogic.rename_room(room.id, "Same Name")
      assert renamed.name == "Same Name"
    end
  end

  describe "delete_room/1" do
    test "refuses to delete the Active Room" do
      room = create_room!()
      set_active_room_id!(room.id)
      assert {:error, :active} = RoomsLogic.delete_room(room.id)
    end

    test "soft-deletes a non-active Room" do
      room1 = create_room!()
      set_active_room_id!(room1.id)
      room2 = create_room!()

      assert {:ok, deleted} = RoomsLogic.delete_room(room2.id)
      assert deleted.deleted_at != nil
      refute Enum.any?(RoomsLogic.list_rooms(), &(&1.id == room2.id))
    end

    test "refuses to delete the last remaining Room" do
      room = create_room!()
      set_active_room_id!(nil)

      assert [%Room{}] = RoomsLogic.list_rooms()
      assert {:error, :last_room} = RoomsLogic.delete_room(room.id)
    end

    test "cascades the soft delete to the Room's Seat Maps and Versions" do
      room1 = create_room!()
      set_active_room_id!(room1.id)

      room2 = create_room!()
      map_id = first_map_id(room2)
      {:ok, _second} = SeatMapsLogic.create_seat_map(%{room_id: room2.id, name: "Second Layout"})

      assert {:ok, _deleted} = RoomsLogic.delete_room(room2.id)

      assert SeatMapsLogic.list_seat_maps(room2.id) == []
      assert SeatMapsLogic.list_versions(map_id) == []
      assert SeatMapsLogic.list_seat_maps(room1.id) != []
    end
  end

  # ============================================================================
  # Versions & saves
  # ============================================================================

  describe "save_version/3" do
    test "appends a Version and increments the revision" do
      room = create_room!()
      map_id = first_map_id(room)

      assert {:ok, version} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      assert version.revision == 2

      assert newest_version(map_id).revision == 2
    end

    test "rejects a stale base_revision without appending" do
      room = create_room!()
      map_id = first_map_id(room)

      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 0, 0)]), 1)

      # The map is now at revision 2; saving with base 1 must be rejected
      assert {:error, {:stale, 2}} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 5, 5)]), 1)

      assert newest_version(map_id).revision == 2
    end
  end

  # ============================================================================
  # Publishing
  # ============================================================================

  describe "publish_seat_map/1" do
    test "points the Room at the map's newest Version" do
      room = create_room!()
      set_active_room_id!(room.id)
      map_id = first_map_id(room)

      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 0, 0)]), 1)

      {:ok, version} = SeatMapsLogic.publish_seat_map(map_id)

      room = reload_room(room)
      assert room.published_version.id == version.id
      assert room.published_version.revision == 2
      assert version.published_at != nil
    end

    test "same-map republish that moves a live-reservation Seat is refused" do
      room = create_room!()
      set_active_room_id!(room.id)
      map_id = first_map_id(room)

      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)

      seat_slot_id = first_seat_slot_id(map_id)
      insert_active_reservation!(seat_slot_id)

      # Move the seat then attempt to republish the same map
      moved = seat_payload("A01", 100, 100) |> Map.put(:seat_slot_id, seat_slot_id)
      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([moved]), 2)

      assert {:error, {:active_reservations, [^seat_slot_id]}} = SeatMapsLogic.publish_seat_map(map_id)
    end

    test "cross-map publish soft-deletes active reservations with an incident" do
      room = create_room!()
      set_active_room_id!(room.id)
      map_a = first_map_id(room)

      {:ok, _} = SeatMapsLogic.save_version(map_a, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_a)

      reservation = insert_active_reservation!(first_seat_slot_id(map_a))

      {:ok, %{id: map_b}} = SeatMapsLogic.create_seat_map(%{room_id: room.id, name: "Second Layout"})

      {:ok, _} = SeatMapsLogic.publish_seat_map(map_b)

      updated = Repo.get!(Reservation, reservation.id)
      assert updated.deleted_at != nil
      assert updated.incident == "seat map changed"

      room = reload_room(room)
      assert room.published_version.seat_map_id == map_b
    end

    test "publishing a map of a non-active Room leaves the Active Room and its reservations alone" do
      active = create_room!()
      set_active_room_id!(active.id)
      active_map = first_map_id(active)

      {:ok, _} = SeatMapsLogic.save_version(active_map, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      {:ok, published} = SeatMapsLogic.publish_seat_map(active_map)

      reservation = insert_active_reservation!(first_seat_slot_id(active_map))

      offstage = create_room!()
      offstage_map = first_map_id(offstage)

      assert {:ok, _version} = SeatMapsLogic.publish_seat_map(offstage_map)

      assert reload_room(active).published_version.id == published.id
      assert Repo.get!(Reservation, reservation.id).deleted_at == nil
      assert reload_room(offstage).published_version.seat_map_id == offstage_map
    end

    test "cross-map publish is refused while a Tournament is underway" do
      room = create_room!()
      set_active_room_id!(room.id)
      map_a = first_map_id(room)

      {:ok, _} = SeatMapsLogic.save_version(map_a, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_a)

      reservation = insert_active_reservation!(first_seat_slot_id(map_a))
      insert_tournament_underway!("Ongoing Match")

      {:ok, %{id: map_b}} = SeatMapsLogic.create_seat_map(%{room_id: room.id, name: "Second Layout"})
      assert {:error, {:tournament_in_progress, "Ongoing Match"}} = SeatMapsLogic.publish_seat_map(map_b)

      assert Repo.get!(Reservation, reservation.id).deleted_at == nil
    end
  end

  describe "get_published_version/0" do
    test "returns {:error, :no_room} when active_room_id is nil" do
      set_active_room_id!(nil)
      assert {:error, :no_room} = SeatMapsLogic.get_published_version()
    end
  end

  # ============================================================================
  # Catalogue actions
  # ============================================================================

  describe "list_seat_maps/1" do
    test "a map whose newest Version is already published is not publishable" do
      room = create_room!()
      set_active_room_id!(room.id)
      map_id = first_map_id(room)

      assert [%{publishable: true, published: false}] = SeatMapsLogic.list_seat_maps(room.id)

      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)
      assert [%{publishable: false, published: true}] = SeatMapsLogic.list_seat_maps(room.id)
    end

    test "saving a Version makes the published map publishable again" do
      room = create_room!()
      set_active_room_id!(room.id)
      map_id = first_map_id(room)

      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)
      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 0, 0)]), 1)

      assert [%{publishable: true, published: true}] = SeatMapsLogic.list_seat_maps(room.id)
    end
  end

  describe "delete_seat_map/1" do
    test "refuses to delete the published map" do
      room = create_room!()
      set_active_room_id!(room.id)
      map_id = first_map_id(room)

      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      {:ok, _} = SeatMapsLogic.publish_seat_map(map_id)

      assert {:error, :published} = SeatMapsLogic.delete_seat_map(map_id)
    end

    test "soft-deletes an unpublished map" do
      room = create_room!()
      map_id = first_map_id(room)

      assert {:ok, deleted} = SeatMapsLogic.delete_seat_map(map_id)
      assert deleted.deleted_at != nil
    end
  end

  describe "duplicate_seat_map/2" do
    test "copies the selected Version, not the newest, and auto-suffixes the name" do
      room = create_room!(%{first_map_name: "Test"})
      map_id = first_map_id(room)

      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 0, 0)]), 1)
      {:ok, _} = SeatMapsLogic.save_version(map_id, editor_attrs([seat_payload("A01", 200, 200)]), 2)

      versions = SeatMapsLogic.list_versions(map_id) # newest first
      v1 = List.last(versions)
      v2 = Enum.find(versions, &(&1.revision == 2))
      v3 = List.first(versions)

      assert v1.revision == 1
      assert v2.revision == 2
      assert v3.revision == 3

      # Duplicate the selected (middle) Version, not the newest
      assert {:ok, new_map} = SeatMapsLogic.duplicate_seat_map(map_id, v2.id)
      assert new_map.name == "Test (2)"

      [dup_version] = SeatMapsLogic.list_versions(new_map.id)
      assert dup_version.revision == 1

      copied_seat = dup_version.data["seats"] |> List.first()
      assert copied_seat["x"] == 0
      refute copied_seat["x"] == 200
    end
  end

  describe "rename_seat_map/2" do
    test "rejects a duplicate name in the same Room" do
      room = create_room!(%{first_map_name: "One"})
      map1 = first_map_id(room)

      {:ok, map2} = SeatMapsLogic.create_seat_map(%{room_id: room.id, name: "Two"})

      assert {:error, %Ecto.Changeset{}} = SeatMapsLogic.rename_seat_map(map2.id, "One")

      assert {:ok, renamed} = SeatMapsLogic.rename_seat_map(map2.id, "Three")
      assert renamed.name == "Three"
      assert map1 != nil
    end
  end
end
