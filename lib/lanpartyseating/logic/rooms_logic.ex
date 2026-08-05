defmodule Lanpartyseating.RoomsLogic do
  @moduledoc """
  Room lifecycle: the Active Room, the room catalogue, and room creation / switching /
  deletion. Rooms own Seat Maps, so cross-cutting operations that touch both live here and
  call into `Lanpartyseating.SeatMapsLogic` where needed.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.Repo
  alias Lanpartyseating.Reservation
  alias Lanpartyseating.Room
  alias Lanpartyseating.SeatMap
  alias Lanpartyseating.SeatMapLayout
  alias Lanpartyseating.SeatMapVersion
  alias Lanpartyseating.Setting
  alias Lanpartyseating.SettingsLogic
  alias Lanpartyseating.TournamentsLogic

  @endpoint LanpartyseatingWeb.Endpoint

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
  Returns the Active Room the application currently serves, or `{:error, :no_room}` on a
  fresh install with no Active Room set (so callers can render an empty state).
  """
  def get_active_room do
    with %Setting{active_room_id: active_room_id} when not is_nil(active_room_id) <- SettingsLogic.get_settings(),
         %Room{} = room <- Repo.get(Room, active_room_id) do
      {:ok, Repo.preload(room, :published_version)}
    else
      _error -> {:error, :no_room}
    end
  end

  @doc "Non-deleted Rooms, for the catalogue dropdown and the General settings page."
  def list_rooms do
    Room
    |> where([room], is_nil(room.deleted_at))
    |> order_by([room], asc: room.name)
    |> Repo.all()
  end

  @doc """
  Creates a Room plus its first (unpublished, empty) Seat Map. Sets `active_room_id` on the
  settings singleton only when none was set, so the first Room becomes the Active Room.
  """
  def create_room(attrs) when is_map(attrs) do
    attrs = SeatMapLayout.atomize_keys(attrs)
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
  `seat_map_changed` so desktop clients disconnect. The cancel + switch run in one
  transaction.
  """
  def set_active_room(room_id) when is_integer(room_id) do
    with {:ok, room} <- fetch_room(room_id),
         :ok <- ensure_no_tournament() do
      if SettingsLogic.get_settings().active_room_id == room.id do
        {:ok, :already_active}
      else
        switch_active_room(room)
      end
    end
  end

  @doc """
  Renames a Room. Refuses a blank name (`{:error, :blank_name}`) and a name another live Room
  already answers to (`{:error, :name_taken}`).
  """
  def rename_room(room_id, name) when is_integer(room_id) and is_binary(name) do
    name = String.trim(name)

    with {:ok, room} <- fetch_room(room_id),
         :ok <- ensure_name_available(room, name) do
      room
      |> Room.changeset(%{name: name})
      |> Repo.update()
    end
  end

  @doc """
  Soft-deletes a Room and cascades the soft delete to its Seat Maps and their Versions.
  Refuses when it is the Active Room (`{:error, :active}`) or the only Room left
  (`{:error, :last_room}`).
  """
  def delete_room(room_id) when is_integer(room_id) do
    with {:ok, room} <- fetch_room(room_id),
         :ok <- ensure_not_active(room),
         :ok <- ensure_not_last_room() do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      room_map_ids = from(seat_map in SeatMap, where: seat_map.room_id == ^room.id, select: seat_map.id)

      Multi.new()
      |> Multi.update(:room, Room.changeset(room, %{deleted_at: now}))
      |> Multi.update_all(
        :versions,
        from(version in SeatMapVersion,
          where: version.seat_map_id in subquery(room_map_ids) and is_nil(version.deleted_at)
        ),
        set: [deleted_at: now]
      )
      |> Multi.update_all(
        :seat_maps,
        from(seat_map in SeatMap, where: seat_map.room_id == ^room.id and is_nil(seat_map.deleted_at)),
        set: [deleted_at: now]
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{room: room}} ->
          broadcast_map_update()
          {:ok, room}

        {:error, _op, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Soft-deletes active reservations, scoped to the given repo so it can run inside a
  transaction (used when switching rooms or publishing across maps).
  """
  def cancel_all_active_reservations_in_repo(repo, reason) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(r in Reservation,
      where: is_nil(r.deleted_at),
      where: r.start_date <= ^now and r.end_date > ^now,
      where: not is_nil(r.seat_slot_id)
    )
    |> repo.update_all(set: [deleted_at: now, incident: reason])
  end

  defp fetch_room(room_id) do
    case Repo.get(Room, room_id) do
      nil -> {:error, :not_found}
      room -> {:ok, room}
    end
  end

  defp ensure_no_tournament do
    case TournamentsLogic.tournament_underway_name() do
      nil -> :ok
      name -> {:error, {:tournament_in_progress, name}}
    end
  end

  defp ensure_not_active(room) do
    if SettingsLogic.get_settings().active_room_id == room.id do
      {:error, :active}
    else
      :ok
    end
  end

  defp ensure_name_available(_room, ""), do: {:error, :blank_name}

  defp ensure_name_available(room, name) do
    taken? =
      Room
      |> where([other], is_nil(other.deleted_at) and other.id != ^room.id)
      |> where([other], fragment("lower(?)", other.name) == ^String.downcase(name))
      |> Repo.exists?()

    if taken?, do: {:error, :name_taken}, else: :ok
  end

  defp ensure_not_last_room do
    count =
      Room
      |> where([room], is_nil(room.deleted_at))
      |> Repo.aggregate(:count, :id)

    if count > 1, do: :ok, else: {:error, :last_room}
  end

  defp switch_active_room(room) do
    result =
      Repo.transaction(fn repo ->
        cancel_all_active_reservations_in_repo(repo, "room changed")

        repo.get!(Setting, 1)
        |> Setting.changeset(%{active_room_id: room.id})
        |> repo.update!()
      end)

    case result do
      {:ok, _settings} ->
        broadcast_map_update()
        @endpoint.broadcast("desktop:all", "seat_map_changed", %{})
        {:ok, room}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp broadcast_map_update do
    Phoenix.PubSub.broadcast(PubSub, "seat_map_update", {:seat_map_updated, %{version_id: nil, touched_slot_ids: []}})
  end

  defp empty_map_data do
    %{
      meta: %{zoom: 1, minScale: 0.4, maxScale: 4},
      seats: [],
      objects: []
    }
  end

  defp parse_dimension(value, default) do
    case parse_int(value) do
      parsed when is_integer(parsed) and parsed > 0 -> parsed
      _ -> default
    end
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_float(value), do: round(value)
  defp parse_int(value) when is_binary(value), do: value |> Float.parse() |> elem(0) |> round()
  defp parse_int(_value), do: 0
end
