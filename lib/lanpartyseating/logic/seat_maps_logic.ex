defmodule Lanpartyseating.SeatMapsLogic do
  import Ecto.Query

  require Logger

  alias Ecto.Multi
  alias Lanpartyseating.PcAsset
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.Repo
  alias Lanpartyseating.Reservation
  alias Lanpartyseating.Room
  alias Lanpartyseating.SeatMap
  alias Lanpartyseating.SeatMapVersion
  alias Lanpartyseating.SeatSlot
  alias Lanpartyseating.SeatSlotAssignment
  alias Lanpartyseating.SeatSlotStatus
  alias Lanpartyseating.Setting
  alias Lanpartyseating.SettingsLogic
  alias Lanpartyseating.TournamentsLogic

  @endpoint LanpartyseatingWeb.Endpoint

  # ---------------------------------------------------------------------------
  # Rooms
  # ---------------------------------------------------------------------------

  @doc """
  Returns the Active Room the application currently serves, or `{:error, :no_room}` on a
  fresh install with no Active Room set (so callers can render an empty state).
  """
  def get_active_room do
    case SettingsLogic.get_settings() do
      %Setting{active_room_id: nil} ->
        {:error, :no_room}

      %Setting{active_room_id: id} ->
        case Repo.get(Room, id) do
          nil -> {:error, :no_room}
          room -> {:ok, Repo.preload(room, :published_version)}
        end
    end
  end

  @doc "Non-deleted Rooms, for the catalogue dropdown and the General settings page."
  def list_rooms do
    Room
    |> where([room], is_nil(room.deleted_at))
    |> order_by([room], asc: room.name)
    |> Repo.all()
  end

  @animals ~w(
    alpaca anteater badger beaver bison bobcat buffalo camel cheetah chipmunk
    cobra condor cougar coyote crane cricket crocodile dingo dolphin donkey
    dragonfly eagle eel elephant elk falcon ferret flamingo fox frog gazelle
    gecko gerbil gibbon giraffe gopher gorilla hamster hare hawk hedgehog heron
    hippo hornet hummingbird hyena ibex iguana impala jackal jaguar jellyfish
    kangaroo koala lemur leopard lion llama lynx macaw manatee marmot marten
    meerkat mongoose moose moth narwhal newt ocelot octopus okapi opossum
    orangutan orca ostrich otter owl panda pangolin panther parrot partridge
    peacock pelican penguin pheasant pigeon platypus porcupine puma python
    quail rabbit raccoon raven reindeer rhino roadrunner robin salamander
    salmon scallop scorpion seagull seahorse seal shark sheep shrew skunk
    sloth snail snake spider squid squirrel starfish stork swan tapir tarantula
    tiger toad tortoise toucan turkey turtle vulture wallaby walrus warthog
    weasel whale wildebeest wolf wolverine wombat woodpecker yak zebra
  )

  @doc """
  Generates a memorable random room name from three animals, e.g. `"zebra-unicorn-goat"`.
  """
  def random_room_name do
    @animals
    |> Enum.shuffle()
    |> Enum.take(3)
    |> Enum.join("-")
  end

  @doc """
  Creates a Room plus its first (unpublished, empty) Seat Map. Sets `active_room_id` on the
  settings singleton only when none was set, so the first Room becomes the Active Room.
  """
  def create_room(attrs) when is_map(attrs) do
    attrs = atomize_keys(attrs)
    width = parse_dimension(attrs[:width], 1920)
    height = parse_dimension(attrs[:height], 1080)
    first_map_name = attrs[:first_map_name] || "Main Layout"

    Multi.new()
    |> Multi.insert(:room, %Room{} |> Room.create_changeset(%{name: attrs[:name], width: width, height: height}))
    |> Multi.run(:seat_map, fn repo, %{room: room} ->
      %SeatMap{}
      |> SeatMap.create_changeset(%{room_id: room.id, name: first_map_name})
      |> repo.insert()
    end)
    |> Multi.run(:version, fn repo, %{seat_map: seat_map, room: room} ->
      %SeatMapVersion{}
      |> SeatMapVersion.changeset(%{
        seat_map_id: seat_map.id,
        revision: 1,
        width: room.width,
        height: room.height,
        background_kind: "none",
        background_value: nil,
        data: empty_map_data()
      })
      |> repo.insert()
    end)
    |> Multi.run(:activate, fn repo, %{room: room} ->
      if is_nil(SettingsLogic.get_settings().active_room_id) do
        repo.get!(Setting, 1)
        |> Setting.changeset(%{active_room_id: room.id})
        |> repo.update()
      else
        {:ok, :noop}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{room: room}} -> {:ok, room}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  Switches the Active Room. Follows the same rules as a cross-map publish: refuses while a
  Tournament is underway, otherwise cancels active reservations, switches, and broadcasts
  `seat_map_changed` so desktop clients disconnect.
  """
  def set_active_room(room_id) when is_integer(room_id) do
    case Repo.get(Room, room_id) do
      nil ->
        {:error, :not_found}

      room ->
        case TournamentsLogic.tournament_underway_name() do
          nil ->
            if SettingsLogic.get_settings().active_room_id == room.id do
              {:ok, :already_active}
            else
              cancel_all_active_reservations("room changed")
              SettingsLogic.get_settings() |> Setting.changeset(%{active_room_id: room.id}) |> Repo.update!()
              broadcast_map_update(nil, [])
              @endpoint.broadcast("desktop:all", "seat_map_changed", %{})
              {:ok, room}
            end

          tournament_name ->
            {:error, {:tournament_in_progress, tournament_name}}
        end
    end
  end

  @doc """
  Soft-deletes a Room. Refuses when it is the Active Room.
  """
  def delete_room(room_id) when is_integer(room_id) do
    case Repo.get(Room, room_id) do
      nil ->
        {:error, :not_found}

      room ->
        if SettingsLogic.get_settings().active_room_id == room.id do
          {:error, :active}
        else
          room
          |> Room.changeset(%{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})
          |> Repo.update()
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Seat Map catalogue
  # ---------------------------------------------------------------------------

  @doc """
  Non-deleted Seat Maps for a Room, each annotated with its newest Version and whether the
  map owns the Room's published Version.
  """
  def list_seat_maps(room_id) when is_integer(room_id) do
    room = Repo.get(Room, room_id) |> Repo.preload(:published_version)
    published_map_id = if room && room.published_version, do: room.published_version.seat_map_id

    SeatMap
    |> where([seat_map], seat_map.room_id == ^room_id and is_nil(seat_map.deleted_at))
    |> order_by([seat_map], asc: seat_map.name)
    |> Repo.all()
    |> Enum.map(fn map ->
      newest = newest_version(map.id)

      %{
        id: map.id,
        name: map.name,
        public_id: map.public_id,
        version_id: newest && newest.id,
        version_revision: newest && newest.revision,
        updated_at: newest && newest.updated_at,
        published: published_map_id == map.id
      }
    end)
  end

  @doc "Fetches a Seat Map by its `public_id`. Returns `{:ok, map}` or `{:error, :not_found}`."
  def get_seat_map_by_public_id(public_id) when is_binary(public_id) do
    case Repo.one(from(seat_map in SeatMap, where: seat_map.public_id == ^public_id and is_nil(seat_map.deleted_at))) do
      nil -> {:error, :not_found}
      seat_map -> {:ok, seat_map}
    end
  end

  defp get_seat_map(id) when is_integer(id) do
    case Repo.get(SeatMap, id) do
      nil -> {:error, :not_found}
      %SeatMap{deleted_at: deleted_at} when not is_nil(deleted_at) -> {:error, :not_found}
      seat_map -> {:ok, seat_map}
    end
  end

  @doc "Creates a new Seat Map with one empty Version at revision 1."
  def create_seat_map(attrs) when is_map(attrs) do
    attrs = atomize_keys(attrs)

    with {:ok, room} <- {:ok, Repo.get(Room, attrs[:room_id]) || :none} do
      if room == :none do
        {:error, :no_room}
      else
        %SeatMap{}
        |> SeatMap.create_changeset(%{room_id: room.id, name: attrs[:name]})
        |> Repo.insert()
        |> case do
          {:ok, seat_map} ->
            %SeatMapVersion{}
            |> SeatMapVersion.changeset(%{
              seat_map_id: seat_map.id,
              revision: 1,
              width: room.width,
              height: room.height,
              background_kind: "none",
              background_value: nil,
              data: empty_map_data()
            })
            |> Repo.insert()

            {:ok, seat_map}

          error ->
            error
        end
      end
    end
  end

  @doc "Renames a Seat Map. Never creates a Version. Returns `{:error, changeset}` on collision."
  def rename_seat_map(seat_map_id, name) when is_binary(name) do
    with {:ok, seat_map} <- get_seat_map(seat_map_id) do
      seat_map
      |> SeatMap.changeset(%{name: name})
      |> Repo.update()
    end
  end

  @doc "Soft-deletes a Seat Map. Refuses when it owns the Room's published Version."
  def delete_seat_map(seat_map_id) when is_integer(seat_map_id) do
    with {:ok, seat_map} <- get_seat_map(seat_map_id) do
      if published_seat_map?(seat_map) do
        {:error, :published}
      else
        seat_map
        |> SeatMap.changeset(%{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})
        |> Repo.update()
      end
    end
  end

  @doc """
  Duplicates a Seat Map from a chosen Version, without leaving the catalogue. Copies the
  selected Version's data / width / height / background into a new map named `"<name> (n)"`.
  """
  def duplicate_seat_map(seat_map_id, version_id) when is_integer(seat_map_id) and is_integer(version_id) do
    with {:ok, source_map} <- get_seat_map(seat_map_id) do
      case Repo.get(SeatMapVersion, version_id) do
        nil ->
          {:error, :not_found}

        version ->
          new_name = next_duplicate_name(source_map.room_id, source_map.name)

          %SeatMap{}
          |> SeatMap.create_changeset(%{room_id: source_map.room_id, name: new_name})
          |> Repo.insert()
          |> case do
            {:ok, new_map} ->
              %SeatMapVersion{}
              |> SeatMapVersion.changeset(%{
                seat_map_id: new_map.id,
                revision: 1,
                width: version.width,
                height: version.height,
                background_kind: version.background_kind,
                background_value: version.background_value,
                data: version.data
              })
              |> Repo.insert()

              {:ok, new_map}

            error ->
              error
          end
      end
    end
  end

  @doc "Versions for a Seat Map, newest first, for the row dropdown."
  def list_versions(seat_map_id) when is_integer(seat_map_id) do
    SeatMapVersion
    |> where([version], version.seat_map_id == ^seat_map_id and is_nil(version.deleted_at))
    |> order_by([version], desc: version.revision)
    |> Repo.all()
  end

  @doc """
  Publishes a Seat Map by pointing its Room at the map's newest Version. Same-map publishes
  keep the per-seat guard; cross-map publishes cancel active reservations and broadcast to
  desktop clients. Returns the published Version, or `{:error, reason}`.
  """
  def publish_seat_map(seat_map_id) when is_integer(seat_map_id) do
    with {:ok, map} <- get_seat_map(seat_map_id),
         {:ok, room} <- get_active_room() do
      newest = newest_version(map.id)

      if is_nil(newest) do
        {:error, :no_version}
      else
        current_published = room.published_version
        same_map? = not is_nil(current_published) and current_published.seat_map_id == map.id
        tournament_name = TournamentsLogic.tournament_underway_name()

        multi =
          Multi.new()
          |> Multi.run(:check, fn _repo, _changes ->
            cond do
              same_map? ->
                case ensure_publishable_with_data(current_published, normalize_map_data(newest.data)) do
                  :ok -> {:ok, :same}
                  {:error, {:active_reservations, ids}} -> {:error, {:active_reservations, ids}}
                end

              not is_nil(tournament_name) ->
                {:error, {:tournament_in_progress, tournament_name}}

              true ->
                {:ok, :cross}
            end
          end)
          |> Multi.run(:cancel, fn repo, %{check: check} ->
            if check == :same do
              {:ok, :noop}
            else
              cancel_all_active_reservations_in_repo(repo, "seat map changed")
              {:ok, :cancelled}
            end
          end)
          |> Multi.run(:publish, fn repo, _changes ->
            now = DateTime.utc_now() |> DateTime.truncate(:second)

            repo.get!(Room, room.id)
            |> Ecto.Changeset.change(%{published_version_id: newest.id})
            |> repo.update!()

            newest =
              repo.get!(SeatMapVersion, newest.id)
              |> Ecto.Changeset.change(%{published_at: now})
              |> repo.update!()

            {:ok, newest}
          end)

        case Repo.transaction(multi) do
          {:ok, %{check: check, publish: published_version}} ->
            broadcast_map_update(published_version.id, [])
            if check == :cross, do: @endpoint.broadcast("desktop:all", "seat_map_changed", %{})
            {:ok, published_version}

          {:error, _operation, reason, _changes} ->
            {:error, reason}
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Editor save (append-only Versions)
  # ---------------------------------------------------------------------------

  @doc "Loads the editor state for a Seat Map identified by `public_id`."
  def get_editor_payload(public_id) when is_binary(public_id) do
    with {:ok, map} <- get_seat_map_by_public_id(public_id),
         {:ok, newest} <- {:ok, newest_version(map.id) || :none} do
      if newest == :none do
        {:error, :no_version}
      else
        {:ok, build_editor_payload(map, newest)}
      end
    end
  end

  @doc """
  Appends a new immutable Version. Rejects with `{:error, {:stale, latest}}` when the map's
  newest revision differs from `base_revision`. Otherwise syncs Seats and inserts a Version
  at `latest + 1`.
  """
  def save_version(seat_map_id, attrs, base_revision) when is_map(attrs) do
    with {:ok, map} <- get_seat_map(seat_map_id),
         {:ok, newest} <- {:ok, newest_version(map.id) || :none} do
      if newest == :none do
        {:error, :no_version}
      else
        if newest.revision != parse_int(base_revision) do
          {:error, {:stale, newest.revision}}
        else
          attrs = normalize_editor_attrs(attrs)

          case sync_slots_and_build_data(map.room_id, attrs[:data] || %{}) do
            {:ok, synced_data, touched_slot_ids} ->
              version =
                %SeatMapVersion{}
                |> SeatMapVersion.changeset(%{
                  seat_map_id: map.id,
                  revision: newest.revision + 1,
                  width: attrs[:width] || newest.width,
                  height: attrs[:height] || newest.height,
                  background_kind: attrs[:background_kind] || newest.background_kind,
                  background_value: attrs[:background_value],
                  data: synced_data
                })
                |> Repo.insert!()

              broadcast_map_update(version.id, touched_slot_ids)
              {:ok, version}

            error ->
              error
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Published payload (display / kiosk)
  # ---------------------------------------------------------------------------

  @doc """
  Resolves the Active Room's published Version. Returns `{:error, :no_room}` / `{:error, :none_published}`.
  """
  def get_published_version do
    with {:ok, room} <- get_active_room() do
      case room.published_version do
        nil -> {:error, :none_published}
        version -> {:ok, version}
      end
    end
  end

  @doc """
  Builds the runtime payload for the published Version. Returns `{:error, :no_room}` /
  `{:error, :none_published}` so callers can render an empty state.
  """
  def get_map_payload(now \\ DateTime.utc_now()) do
    with {:ok, version} <- get_published_version() do
      {:ok, build_payload(version, now)}
    end
  end

  @doc "Resolves a single Seat Slot's runtime status."
  def get_seat_slot(seat_slot_id, now \\ DateTime.utc_now()) do
    status = seat_status_index(now)

    case Map.get(status, seat_slot_id) do
      nil -> {:error, :not_found}
      seat -> {:ok, seat}
    end
  end

  # ---------------------------------------------------------------------------
  # Seat / PC management (kept)
  # ---------------------------------------------------------------------------

  def set_seat_slot_broken(seat_slot_id, is_broken, reason \\ nil) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset =
      %SeatSlotStatus{}
      |> SeatSlotStatus.changeset(%{seat_slot_id: seat_slot_id, is_broken: is_broken, reason: reason})

    result =
      Repo.insert(
        changeset,
        on_conflict: [set: [is_broken: is_broken, reason: reason, updated_at: now]],
        conflict_target: :seat_slot_id
      )

    case result do
      {:ok, status} ->
        broadcast_map_update(nil, [seat_slot_id])
        {:ok, status}

      error ->
        error
    end
  end

  def reserve_seat_slot(seat_slot_id, badge_uid) do
    Logger.info("reserve_seat_slot seat_slot_id=#{inspect(seat_slot_id)} badge_uid=#{inspect(badge_uid)}")
    {:ok, nil}
  end

  def current_pc_target_for_slot(seat_slot_id) do
    SeatSlotAssignment
    |> where([assignment], assignment.seat_slot_id == ^seat_slot_id and is_nil(assignment.deleted_at))
    |> join(:inner, [assignment], pc in assoc(assignment, :pc_asset))
    |> where([_assignment, pc], is_nil(pc.deleted_at))
    |> preload([_assignment, pc], pc_asset: pc)
    |> Repo.one()
  end

  def move_pc_asset(pc_asset_id, seat_slot_id) do
    Multi.new()
    |> Multi.update_all(
      :clear_existing_slot,
      from(
        a in SeatSlotAssignment,
        where: a.seat_slot_id == ^seat_slot_id and is_nil(a.deleted_at)
      ),
      set: [deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
    |> Multi.update_all(
      :clear_existing_pc,
      from(
        a in SeatSlotAssignment,
        where: a.pc_asset_id == ^pc_asset_id and is_nil(a.deleted_at)
      ),
      set: [deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
    |> Multi.insert(
      :new_assignment,
      SeatSlotAssignment.changeset(%SeatSlotAssignment{}, %{seat_slot_id: seat_slot_id, pc_asset_id: pc_asset_id})
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{new_assignment: assignment}} ->
        broadcast_map_update(nil, [seat_slot_id])
        {:ok, assignment}

      {:error, _op, reason, _changes} ->
        {:error, reason}
    end
  end

  def transfer_reservation(reservation_id, target_seat_slot_id) do
    case Repo.get(Reservation, reservation_id) do
      nil ->
        {:error, :not_found}

      reservation ->
        reservation
        |> Reservation.changeset(%{seat_slot_id: target_seat_slot_id})
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            broadcast_map_update(nil, [updated.seat_slot_id, target_seat_slot_id])
            {:ok, updated}

          error ->
            error
        end
    end
  end

  @spec broadcast_map_update(integer() | nil, [integer()]) :: :ok
  def broadcast_map_update(version_id, touched_slot_ids) do
    payload = %{version_id: version_id, touched_slot_ids: Enum.uniq(touched_slot_ids)}
    Phoenix.PubSub.broadcast(PubSub, "seat_map_update", {:seat_map_updated, payload})
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp newest_version(seat_map_id) when is_integer(seat_map_id) do
    SeatMapVersion
    |> where([version], version.seat_map_id == ^seat_map_id and is_nil(version.deleted_at))
    |> order_by([version], desc: version.revision)
    |> limit(1)
    |> Repo.one()
  end

  defp published_seat_map?(seat_map) do
    case get_active_room() do
      {:ok, %Room{published_version: %SeatMapVersion{seat_map_id: seat_map_id}}} ->
        seat_map_id == seat_map.id

      _ ->
        false
    end
  end

  defp next_duplicate_name(room_id, base_name) when is_binary(base_name) do
    existing =
      SeatMap
      |> where([seat_map], seat_map.room_id == ^room_id and is_nil(seat_map.deleted_at))
      |> select([seat_map], seat_map.name)
      |> Repo.all()
      |> MapSet.new()

    find_suffix(existing, base_name, 2)
  end

  defp find_suffix(existing, base_name, n) do
    candidate = "#{base_name} (#{n})"

    if MapSet.member?(existing, candidate) do
      find_suffix(existing, base_name, n + 1)
    else
      candidate
    end
  end

  defp build_editor_payload(map, version) do
    data = normalize_map_data(version.data)
    label_index = seat_label_index(map.room_id)

    %{
      seat_map_id: map.id,
      public_id: map.public_id,
      name: map.name,
      version_id: version.id,
      revision: version.revision,
      width: version.width,
      height: version.height,
      background_kind: version.background_kind,
      background_value: version.background_value,
      meta: data.meta,
      seats: Enum.map(data.seats, &editor_seat_payload(&1, label_index)),
      objects: data.objects
    }
  end

  defp build_payload(version, now) do
    data = normalize_map_data(version.data)
    seat_index = seat_status_index(now)

    seats =
      data.seats
      |> Enum.map(
        fn seat ->
          seat_slot_id = seat.seat_slot_id
          runtime = Map.get(seat_index, seat_slot_id, %{})

          %{
            seat_slot_id: seat_slot_id,
            label: runtime[:label] || seat.label,
            x: seat.x,
            y: seat.y,
            width: seat.width,
            height: seat.height,
            rotation: seat.rotation,
            shape: seat.shape,
            status: Atom.to_string(runtime[:status] || :available),
            reservation_end_date: datetime_to_iso(runtime[:reservation_end_date]),
            legacy_station_number: runtime[:legacy_station_number],
            pc_asset_code: runtime[:pc_asset_code],
            pc_hostname: runtime[:pc_hostname]
          }
        end
      )

    %{
      id: version.id,
      width: version.width,
      height: version.height,
      background_kind: version.background_kind,
      background_value: version.background_value,
      meta: data.meta,
      seats: seats,
      objects: data.objects,
      revision: version.revision
    }
  end

  defp ensure_publishable_with_data(published, new_data) do
    changed_slot_ids = changed_slot_ids_from_data(published, new_data)

    active_ids = live_hold_slot_ids()
    conflicting_ids = MapSet.intersection(active_ids, changed_slot_ids)

    if MapSet.size(conflicting_ids) == 0 do
      :ok
    else
      {:error, {:active_reservations, Enum.sort(MapSet.to_list(conflicting_ids))}}
    end
  end

  defp changed_slot_ids_from_data(published, new_data) do
    published_seats =
      published.data |> normalize_map_data() |> Map.fetch!(:seats) |> Map.new(&seat_signature/1)

    new_seats = new_data.seats |> Map.new(&seat_signature/1)

    Map.keys(published_seats)
    |> Enum.concat(Map.keys(new_seats))
    |> Enum.uniq()
    |> Enum.reduce(
      MapSet.new(),
      fn seat_slot_id, acc ->
        if Map.get(published_seats, seat_slot_id) == Map.get(new_seats, seat_slot_id) do
          acc
        else
          MapSet.put(acc, seat_slot_id)
        end
      end
    )
  end

  defp seat_label_index(room_id) do
    SeatSlot
    |> where([seat_slot], seat_slot.room_id == ^room_id and is_nil(seat_slot.deleted_at))
    |> select([seat_slot], {seat_slot.id, seat_slot.label})
    |> Repo.all()
    |> Map.new()
  end

  defp editor_seat_payload(seat, label_index) do
    %{
      seat_slot_id: seat.seat_slot_id,
      label: Map.get(label_index, seat.seat_slot_id) || seat.label,
      x: seat.x,
      y: seat.y,
      width: seat.width,
      height: seat.height,
      rotation: seat.rotation,
      shape: seat.shape,
      locked: seat.locked,
      status: "available",
      reservation_end_date: nil
    }
  end

  defp seat_signature(seat) do
    seat = normalize_seat(seat)

    {seat.seat_slot_id,
     %{
       label: seat.label,
       x: seat.x,
       y: seat.y,
       width: seat.width,
       height: seat.height,
       rotation: seat.rotation,
       shape: seat.shape
     }}
  end

  defp live_hold_slot_ids do
    now = DateTime.utc_now()
    buffer_minutes = SettingsLogic.get_settings().tournament_buffer_minutes
    tournament_buffer = DateTime.add(now, buffer_minutes, :minute)

    reservation_ids =
      Reservation
      |> where([reservation], is_nil(reservation.deleted_at))
      |> where([reservation], reservation.start_date <= ^now and reservation.end_date > ^now)
      |> where([reservation], not is_nil(reservation.seat_slot_id))
      |> select([reservation], reservation.seat_slot_id)
      |> Repo.all()

    tournament_ids =
      from(
        tr in Lanpartyseating.TournamentReservation,
        join: tournament in assoc(tr, :tournament),
        where: is_nil(tr.deleted_at) and is_nil(tournament.deleted_at),
        where: tournament.start_date < ^tournament_buffer and tournament.end_date > ^now,
        where: not is_nil(tr.seat_slot_id),
        select: tr.seat_slot_id
      )
      |> Repo.all()

    reservation_ids
    |> Enum.concat(tournament_ids)
    |> MapSet.new()
  end

  defp seat_status_index(now) do
    buffer_minutes = SettingsLogic.get_settings().tournament_buffer_minutes
    tournament_buffer = DateTime.add(now, buffer_minutes, :minute)

    SeatSlot
    |> where([seat_slot], is_nil(seat_slot.deleted_at))
    |> preload(
      [
        :status,
        assignment: :pc_asset,
        reservations:
          ^from(
            reservation in Reservation,
            where: is_nil(reservation.deleted_at),
            where: reservation.start_date <= ^now,
            where: reservation.end_date > ^now,
            order_by: [desc: reservation.inserted_at]
          ),
        tournament_reservations:
          ^from(
            tr in Lanpartyseating.TournamentReservation,
            where: is_nil(tr.deleted_at),
            join: t in assoc(tr, :tournament),
            where: is_nil(t.deleted_at),
            where: t.start_date < ^tournament_buffer,
            where: t.end_date > ^now,
            preload: [tournament: t]
          )
      ]
    )
    |> Repo.all()
    |> Enum.into(
      %{},
      fn seat_slot ->
        reservation = List.first(seat_slot.reservations)
        tournament_reservation = List.first(seat_slot.tournament_reservations)

        status =
          cond do
            seat_slot.status && seat_slot.status.is_broken -> :broken
            tournament_reservation -> :reserved
            reservation -> :occupied
            true -> :available
          end

        assignment = seat_slot.assignment && seat_slot.assignment.pc_asset

        {seat_slot.id,
         %{
           status: status,
           label: seat_slot.label,
           reservation_end_date: reservation && reservation.end_date,
           legacy_station_number: seat_slot.legacy_station_number,
           pc_asset_code: assignment && assignment.code,
           pc_hostname: assignment && assignment.hostname
         }}
      end
    )
  end

  defp cancel_all_active_reservations(reason) do
    cancel_all_active_reservations_in_repo(Repo, reason)
  end

  defp cancel_all_active_reservations_in_repo(repo, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(r in Reservation,
      where: is_nil(r.deleted_at),
      where: r.start_date <= ^now and r.end_date > ^now,
      where: not is_nil(r.seat_slot_id)
    )
    |> repo.update_all(set: [deleted_at: now, incident: reason])
  end

  @doc "Counts reservations currently in use (active), for the cross-map publish confirm modal."
  def active_reservation_count do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Reservation
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.start_date <= ^now and r.end_date > ^now)
    |> where([r], not is_nil(r.seat_slot_id))
    |> Repo.aggregate(:count, :id)
  end

  defp sync_slots_and_build_data(room_id, data) do
    data = normalize_map_data(data)
    seats = data.seats

    case upsert_slots(room_id, seats) do
      {:ok, slot_ids_by_key, touched_slot_ids} ->
        seats =
          Enum.map(
            seats,
            fn seat ->
              label = normalize_label(seat.label)
              seat_slot_id = Map.get(slot_ids_by_key, seat.seat_slot_id || label)
              %{seat | seat_slot_id: seat_slot_id, label: label}
            end
          )

        {:ok,
         %{
           meta: data.meta,
           seats: seats,
           objects: data.objects
         }, touched_slot_ids}

      error ->
        error
    end
  end

  defp upsert_slots(room_id, seats) do
    existing_slots =
      SeatSlot
      |> where([seat_slot], seat_slot.room_id == ^room_id and is_nil(seat_slot.deleted_at))
      |> Repo.all()

    slots_by_id = Map.new(existing_slots, &{&1.id, &1})
    slots_by_label = Map.new(existing_slots, &{&1.label, &1})

    Enum.reduce_while(
      seats,
      {:ok, %{}, []},
      fn seat, {:ok, slot_ids_by_key, touched_slot_ids} ->
        label = normalize_label(seat.label)
        seat_slot_id = seat.seat_slot_id

        slot_result =
          cond do
            is_integer(seat_slot_id) and Map.has_key?(slots_by_id, seat_slot_id) ->
              slot = Map.fetch!(slots_by_id, seat_slot_id)
              slot |> SeatSlot.changeset(%{label: label}) |> Repo.update()

            Map.has_key?(slots_by_label, label) ->
              {:ok, Map.fetch!(slots_by_label, label)}

            true ->
              create_slot_with_pc(room_id, label)
          end

        case slot_result do
          {:ok, seat_slot} ->
            updated_slot_ids_by_key =
              slot_ids_by_key
              |> Map.put(label, seat_slot.id)
              |> Map.put(seat_slot.id, seat_slot.id)
              |> maybe_put_original_slot_key(seat_slot_id, seat_slot.id)

            {:cont, {:ok, updated_slot_ids_by_key, [seat_slot.id | touched_slot_ids]}}

          {:error, changeset} ->
            {:halt, {:error, changeset}}
        end
      end
    )
  end

  defp maybe_put_original_slot_key(index, seat_slot_id, persisted_id) when is_integer(seat_slot_id) do
    Map.put(index, seat_slot_id, persisted_id)
  end

  defp maybe_put_original_slot_key(index, _seat_slot_id, _persisted_id), do: index

  defp create_slot_with_pc(room_id, label) do
    asset_code = String.downcase(label)

    Multi.new()
    |> Multi.insert(:seat_slot, SeatSlot.changeset(%SeatSlot{}, %{room_id: room_id, label: label}))
    |> Multi.run(
      :pc_asset,
      fn repo, _changes ->
        case repo.one(from(pc_asset in PcAsset, where: pc_asset.code == ^asset_code and is_nil(pc_asset.deleted_at))) do
          nil ->
            %PcAsset{}
            |> PcAsset.changeset(%{code: asset_code, hostname: asset_code, remote_identifier: asset_code})
            |> repo.insert()

          pc_asset ->
            {:ok, pc_asset}
        end
      end
    )
    |> Multi.update_all(
      :clear_existing_assignment,
      fn %{pc_asset: pc_asset} ->
        from(
          assignment in SeatSlotAssignment,
          where: assignment.pc_asset_id == ^pc_asset.id and is_nil(assignment.deleted_at)
        )
      end,
      set: [deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
    |> Multi.run(
      :assignment,
      fn repo, %{seat_slot: seat_slot, pc_asset: pc_asset} ->
        %SeatSlotAssignment{}
        |> SeatSlotAssignment.changeset(%{seat_slot_id: seat_slot.id, pc_asset_id: pc_asset.id})
        |> repo.insert()
      end
    )
    |> Multi.insert(
      :status,
      fn %{seat_slot: seat_slot} ->
        SeatSlotStatus.changeset(%SeatSlotStatus{}, %{seat_slot_id: seat_slot.id, is_broken: false})
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{seat_slot: seat_slot}} -> {:ok, seat_slot}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  defp empty_map_data do
    %{
      meta: %{zoom: 1, minScale: 0.4, maxScale: 4},
      seats: [],
      objects: []
    }
  end

  defp normalize_editor_attrs(attrs) do
    attrs = atomize_keys(attrs)

    data =
      attrs[:data] ||
        %{
          meta: attrs[:meta] || %{},
          seats: attrs[:seats] || [],
          objects: attrs[:objects] || []
        }

    attrs
    |> Map.put(:data, data)
    |> Map.update(:width, nil, &parse_int/1)
    |> Map.update(:height, nil, &parse_int/1)
  end

  defp normalize_map_data(nil), do: empty_map_data()

  defp normalize_map_data(data) when is_map(data) do
    data = atomize_keys(data)

    %{
      meta: data[:meta] || %{},
      seats: Enum.map(data.seats, &normalize_seat/1),
      objects: Enum.map(data.objects, &normalize_object/1)
    }
  end

  defp normalize_seat(seat) do
    seat = atomize_keys(seat)

    %{
      seat_slot_id: parse_optional_int(seat[:seat_slot_id]),
      label: normalize_label(seat.label),
      x: seat.x,
      y: seat.y,
      width: seat.width,
      height: seat.height,
      rotation: seat.rotation,
      shape: seat.shape,
      locked: normalize_locked(seat[:locked])
    }
  end

  defp normalize_object(object) do
    object = atomize_keys(object)

    %{
      id: object[:id] || Ecto.UUID.generate(),
      type: object.type,
      x: object.x,
      y: object.y,
      width: object.width,
      height: object.height,
      rotation: object.rotation,
      text: object[:text],
      font_size: parse_optional_int(object[:font_size]),
      fill: object[:fill],
      fill_secondary: object[:fill_secondary],
      stroke: object[:stroke],
      locked: normalize_locked(object[:locked]),
      front: normalize_front(object[:front])
    }
  end

  defp normalize_locked(true), do: true
  defp normalize_locked("true"), do: true
  defp normalize_locked(_), do: false

  defp normalize_front(true), do: true
  defp normalize_front("true"), do: true
  defp normalize_front(_), do: false

  defp normalize_label(nil), do: "A01"
  defp normalize_label(label) when is_binary(label), do: label |> String.trim() |> String.upcase()
  defp normalize_label(label), do: label |> to_string() |> normalize_label()

  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(""), do: nil
  defp parse_optional_int(value), do: parse_int(value)

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_float(value), do: round(value)
  defp parse_int(value) when is_binary(value), do: value |> Float.parse() |> elem(0) |> round()
  defp parse_int(_value), do: 0

  defp parse_dimension(value, default) do
    case parse_int(value) do
      parsed when is_integer(parsed) and parsed > 0 -> parsed
      _ -> default
    end
  end

  defp atomize_keys(%_{} = struct), do: struct |> Map.from_struct() |> atomize_keys()

  defp atomize_keys(map) when is_map(map) do
    Map.new(
      map,
      fn
        {key, value} when is_binary(key) ->
          atom =
            try do
              String.to_existing_atom(key)
            rescue
              ArgumentError -> key
            end

          {atom, atomize_value(value)}

        {key, value} ->
          {key, atomize_value(value)}
      end
    )
  end

  defp atomize_keys(other), do: other

  defp atomize_value(%_{} = struct), do: struct |> Map.from_struct() |> atomize_keys()
  defp atomize_value(value) when is_map(value), do: atomize_keys(value)
  defp atomize_value(value) when is_list(value), do: Enum.map(value, &atomize_value/1)
  defp atomize_value(value), do: value

  defp datetime_to_iso(nil), do: nil
  defp datetime_to_iso(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
