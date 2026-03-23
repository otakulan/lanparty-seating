defmodule Lanpartyseating.SeatMapsLogic do
  import Ecto.Query

  alias Ecto.Multi
  alias Lanpartyseating.PcAsset
  alias Lanpartyseating.PubSub
  alias Lanpartyseating.Repo
  alias Lanpartyseating.Reservation
  alias Lanpartyseating.SeatMap
  alias Lanpartyseating.SeatMapVersion
  alias Lanpartyseating.SeatSlot
  alias Lanpartyseating.SeatSlotAssignment
  alias Lanpartyseating.SeatSlotStatus
  alias Lanpartyseating.SettingsLogic
  alias Lanpartyseating.TournamentReservation
  alias Lanpartyseating.TournamentTeamAssignment

  @default_slug "main-room"
  @default_map_name "Main Room"
  @default_canvas %{width: 1920, height: 1080}

  def get_or_create_main_map do
    case Repo.one(from(seat_map in SeatMap, where: seat_map.slug == ^@default_slug and is_nil(seat_map.deleted_at))) do
      nil ->
        %SeatMap{}
        |> SeatMap.changeset(%{name: @default_map_name, slug: @default_slug})
        |> Repo.insert()

      seat_map ->
        {:ok, seat_map}
    end
  end

  def get_published_version do
    with {:ok, seat_map} <- get_or_create_main_map() do
      case version_query(seat_map.id, "published") |> Repo.one() do
        nil -> create_empty_version(seat_map, "published", "Published Layout")
        version -> {:ok, version}
      end
    end
  end

  def get_draft_version do
    with {:ok, seat_map} <- get_or_create_main_map() do
      case version_query(seat_map.id, "draft") |> Repo.one() do
        nil ->
          with {:ok, published} <- get_published_version() do
            create_draft_from_version(seat_map, published)
          end

        version ->
          {:ok, version}
      end
    end
  end

  def get_editor_state do
    with {:ok, draft} <- get_draft_version() do
      {:ok,
       %{
         id: draft.id,
         name: draft.name,
         status: draft.status,
         width: draft.width,
         height: draft.height,
         background_kind: draft.background_kind,
         background_value: draft.background_value,
         data: normalize_map_data(draft.data),
         slots: list_slots_catalog(draft.seat_map_id),
       }}
    end
  end

  def get_editor_payload do
    with {:ok, draft} <- get_draft_version(),
         {:ok, published} <- get_published_version() do
      data = normalize_map_data(draft.data)
      label_index = seat_label_index(draft.seat_map_id)

      {:ok,
       %{
         id: draft.id,
         name: draft.name,
         status: draft.status,
         width: draft.width,
         height: draft.height,
         background_kind: draft.background_kind,
         background_value: draft.background_value,
         meta: data["meta"] || %{},
         seats: Enum.map(data["seats"], &editor_seat_payload(&1, label_index)),
         objects: data["objects"] || [],
         groups: data["groups"] || [],
         team_assignments: editor_team_assignment_index(draft.id),
         revision: revision_for(draft),
         published_revision: revision_for(published),
       }}
    end
  end

  def get_map_payload(status \\ "published", now \\ DateTime.utc_now()) do
    with {:ok, version} <- get_version(status) do
      {:ok, build_payload(version, now)}
    end
  end

  def get_seat_slot(seat_slot_id, now \\ DateTime.utc_now()) do
    status = seat_status_index(now)

    case Map.get(status, seat_slot_id) do
      nil -> {:error, :not_found}
      seat -> {:ok, seat}
    end
  end

  def list_slot_options do
    with {:ok, seat_map} <- get_or_create_main_map() do
      slots = list_slots_catalog(seat_map.id)
      {:ok, slots}
    end
  end

  def list_group_options(status \\ "published") do
    with {:ok, version} <- get_version(status) do
      groups = normalize_map_data(version.data)["groups"] || []

      {:ok,
       Enum.map(
         groups,
         fn group ->
           %{
             id: value(group, "id"),
             name: value(group, "name") || value(group, "id"),
             seat_slot_ids: value(group, "seat_slot_ids") || [],
           }
         end
       )}
    end
  end

  def save_draft(attrs, expected_revision \\ nil) when is_map(attrs) do
    with {:ok, seat_map} <- get_or_create_main_map(),
         {:ok, draft} <- get_draft_version(),
         :ok <- validate_revision(draft, expected_revision) do
      attrs = normalize_editor_attrs(attrs)

      case sync_slots_and_build_data(seat_map.id, attrs["data"] || %{}) do
        {:ok, synced_data, touched_slot_ids} ->
          draft
          |> SeatMapVersion.changeset(
            %{
              name: attrs["name"] || draft.name,
              width: attrs["width"] || draft.width,
              height: attrs["height"] || draft.height,
              background_kind: attrs["background_kind"] || draft.background_kind,
              background_value: attrs["background_value"],
              data: synced_data,
            }
          )
          |> Repo.update()
          |> case do
            {:ok, version} ->
              case replace_team_assignments(version.id, attrs["team_assignments"] || []) do
                :ok ->
                  broadcast_map_update(version.id, touched_slot_ids)
                  {:ok, version}

                error ->
                  error
              end

            error ->
              error
          end

        error ->
          error
      end
    end
  end

  def reset_draft do
    with {:ok, draft} <- get_draft_version(),
         {:ok, published} <- get_published_version() do
      draft
      |> SeatMapVersion.changeset(
        %{
          name: "Working Draft",
          width: published.width,
          height: published.height,
          background_kind: published.background_kind,
          background_value: published.background_value,
          data: published.data,
        }
      )
      |> Repo.update()
      |> case do
        {:ok, updated_draft} ->
          replicate_team_assignments(published.id, updated_draft.id)
          {:ok, updated_draft}

        error ->
          error
      end
    end
  end

  def assign_team_assignment(attrs) when is_map(attrs) do
    with {:ok, draft} <- get_draft_version() do
      attrs = stringify_map(attrs)

      %TournamentTeamAssignment{}
      |> TournamentTeamAssignment.changeset(
        %{
          tournament_id: parse_int(attrs["tournament_id"]),
          seat_map_version_id: draft.id,
          group_id: attrs["group_id"],
          team_name: attrs["team_name"],
          color: attrs["color"],
          label_x: parse_optional_int(attrs["label_x"]),
          label_y: parse_optional_int(attrs["label_y"]),
          deleted_at: nil,
        }
      )
      |> Repo.insert(
        on_conflict:
          [
            set:
              [
                team_name: attrs["team_name"],
                color: attrs["color"],
                label_x: parse_optional_int(attrs["label_x"]),
                label_y: parse_optional_int(attrs["label_y"]),
                deleted_at: nil,
                updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
              ]
          ],
        conflict_target: {:unsafe_fragment, "(tournament_id, group_id) WHERE deleted_at IS NULL"}
      )
      |> case do
        {:ok, assignment} ->
          broadcast_map_update(draft.id, [])
          {:ok, assignment}

        error ->
          error
      end
    end
  end

  def remove_team_assignment(group_id, tournament_id) do
    with {:ok, draft} <- get_draft_version() do
      from(
        team in TournamentTeamAssignment,
        where: team.seat_map_version_id == ^draft.id,
        where: team.group_id == ^group_id,
        where: team.tournament_id == ^tournament_id,
        where: is_nil(team.deleted_at)
      )
      |> Repo.update_all(set: [deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)])

      broadcast_map_update(draft.id, [])
      :ok
    end
  end

  def publish_draft(expected_revision \\ nil) do
    with {:ok, draft} <- get_draft_version(),
         {:ok, published} <- get_published_version(),
         :ok <- validate_revision(draft, expected_revision),
         :ok <- ensure_publishable(published, draft) do
      Multi.new()
      |> Multi.update(
        :retire_published,
        SeatMapVersion.changeset(published, %{status: "draft", published_at: nil, name: published.name})
      )
      |> Multi.update(
        :publish_draft,
        SeatMapVersion.changeset(draft, %{status: "published", published_at: DateTime.utc_now()})
      )
      |> Repo.transaction()
      |> case do
        {:ok, %{publish_draft: version}} ->
          create_draft_from_version(version.seat_map, version)
          broadcast_map_update(version.id, [])
          {:ok, version}

        {:error, _operation, reason, _changes} ->
          {:error, reason}
      end
    end
  end

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

  def broadcast_map_update(version_id \\ nil, touched_slot_ids \\ []) do
    payload = %{version_id: version_id, touched_slot_ids: Enum.uniq(touched_slot_ids)}
    Phoenix.PubSub.broadcast(PubSub, "seat_map_update", {:seat_map_updated, payload})
  end

  defp get_version(status) do
    with {:ok, seat_map} <- get_or_create_main_map() do
      case version_query(seat_map.id, status) |> Repo.one() do
        nil when status == "published" -> get_published_version()
        nil when status == "draft" -> get_draft_version()
        version -> {:ok, version}
      end
    end
  end

  defp version_query(seat_map_id, status) do
    from(
      version in SeatMapVersion,
      where: version.seat_map_id == ^seat_map_id,
      where: version.status == ^status,
      where: is_nil(version.deleted_at),
      preload: [:seat_map],
      order_by: [desc: version.updated_at],
      limit: 1
    )
  end

  defp create_empty_version(seat_map, status, name) do
    %SeatMapVersion{}
    |> SeatMapVersion.changeset(
      %{
        seat_map_id: seat_map.id,
        name: name,
        status: status,
        width: @default_canvas.width,
        height: @default_canvas.height,
        background_kind: "none",
        background_value: nil,
        data: empty_map_data(),
        published_at: if(status == "published", do: DateTime.utc_now() |> DateTime.truncate(:second), else: nil),
      }
    )
    |> Repo.insert()
  end

  defp create_draft_from_version(%SeatMap{id: seat_map_id}, published) do
    from(
      version in SeatMapVersion,
      where: version.seat_map_id == ^seat_map_id,
      where: version.status == "draft",
      where: is_nil(version.deleted_at)
    )
    |> Repo.one()
    |> case do
      nil ->
        %SeatMapVersion{}
        |> SeatMapVersion.changeset(
          %{
            seat_map_id: seat_map_id,
            name: "Working Draft",
            status: "draft",
            width: published.width,
            height: published.height,
            background_kind: published.background_kind,
            background_value: published.background_value,
            data: published.data,
          }
        )
        |> Repo.insert()

      draft ->
        draft
        |> SeatMapVersion.changeset(
          %{
            width: published.width,
            height: published.height,
            background_kind: published.background_kind,
            background_value: published.background_value,
            data: published.data,
          }
        )
        |> Repo.update()
    end
  end

  defp build_payload(version, now) do
    data = normalize_map_data(version.data)
    seat_index = seat_status_index(now)
    groups = data["groups"] || []
    team_assignments = team_assignment_index(version.id, now)

    seats =
      data["seats"]
      |> Enum.map(
        fn seat ->
          seat_slot_id = value(seat, "seat_slot_id")
          runtime = Map.get(seat_index, seat_slot_id, %{})

          seat
          |> stringify_map()
          |> Map.put("seat_slot_id", seat_slot_id)
          |> Map.put("label", runtime[:label] || value(seat, "label"))
          |> Map.put("status", Atom.to_string(runtime[:status] || :available))
          |> Map.put("reservation_end_date", datetime_to_iso(runtime[:reservation_end_date]))
          |> Map.put("legacy_station_number", runtime[:legacy_station_number])
          |> Map.put("pc_asset_code", runtime[:pc_asset_code])
          |> Map.put("pc_hostname", runtime[:pc_hostname])
        end
      )

    %{
      id: version.id,
      name: version.name,
      status: version.status,
      width: version.width,
      height: version.height,
      background_kind: version.background_kind,
      background_value: version.background_value,
      meta: data["meta"] || %{},
      seats: seats,
      objects: data["objects"] || [],
      groups: groups,
      team_assignments: Enum.map(team_assignments, &stringify_map/1),
    }
  end

  defp seat_label_index(seat_map_id) do
    SeatSlot
    |> where([seat_slot], seat_slot.seat_map_id == ^seat_map_id and is_nil(seat_slot.deleted_at))
    |> select([seat_slot], {seat_slot.id, seat_slot.label})
    |> Repo.all()
    |> Map.new()
  end

  defp editor_seat_payload(seat, label_index) do
    seat_slot_id = value(seat, "seat_slot_id")

    seat
    |> stringify_map()
    |> Map.put("seat_slot_id", seat_slot_id)
    |> Map.put("label", Map.get(label_index, seat_slot_id) || value(seat, "label"))
    |> Map.put("status", "available")
    |> Map.put("reservation_end_date", nil)
  end

  defp validate_revision(_draft, nil), do: :ok

  defp validate_revision(draft, expected_revision) do
    if revision_for(draft) == parse_int(expected_revision) do
      :ok
    else
      {:error, :stale_draft}
    end
  end

  defp revision_for(%SeatMapVersion{updated_at: updated_at}) do
    DateTime.from_naive!(updated_at, "Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  defp ensure_publishable(published, draft) do
    changed_slot_ids = changed_slot_ids(published, draft)

    active_ids = live_hold_slot_ids()
    conflicting_ids = MapSet.intersection(active_ids, changed_slot_ids)

    if MapSet.size(conflicting_ids) == 0 do
      :ok
    else
      {:error, {:active_reservations, Enum.sort(MapSet.to_list(conflicting_ids))}}
    end
  end

  defp changed_slot_ids(published, draft) do
    published_seats = published.data |> normalize_map_data() |> Map.fetch!("seats") |> Map.new(&seat_signature/1)
    draft_seats = draft.data |> normalize_map_data() |> Map.fetch!("seats") |> Map.new(&seat_signature/1)

    Map.keys(published_seats)
    |> Enum.concat(Map.keys(draft_seats))
    |> Enum.uniq()
    |> Enum.reduce(
      MapSet.new(),
      fn seat_slot_id, acc ->
        if Map.get(published_seats, seat_slot_id) == Map.get(draft_seats, seat_slot_id) do
          acc
        else
          MapSet.put(acc, seat_slot_id)
        end
      end
    )
  end

  defp seat_signature(seat) do
    seat = stringify_map(seat)
    seat_slot_id = value(seat, "seat_slot_id")

    {seat_slot_id,
     %{
       label: value(seat, "label"),
       x: parse_int(value(seat, "x")),
       y: parse_int(value(seat, "y")),
       width: parse_int(value(seat, "width")),
       height: parse_int(value(seat, "height")),
       rotation: parse_int(value(seat, "rotation")),
       shape: value(seat, "shape"),
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
      TournamentReservation
      |> join(:inner, [tr], tournament in assoc(tr, :tournament))
      |> where([tr, tournament], is_nil(tr.deleted_at) and is_nil(tournament.deleted_at))
      |> where([_tr, tournament], tournament.start_date < ^tournament_buffer and tournament.end_date > ^now)
      |> where([tr, _tournament], not is_nil(tr.seat_slot_id))
      |> select([tr, _tournament], tr.seat_slot_id)
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
            tr in TournamentReservation,
            where: is_nil(tr.deleted_at),
            join: t in assoc(tr, :tournament),
            where: is_nil(t.deleted_at),
            where: t.start_date < ^tournament_buffer,
            where: t.end_date > ^now,
            preload: [tournament: t]
          ),
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
           pc_hostname: assignment && assignment.hostname,
         }}
      end
    )
  end

  defp team_assignment_index(version_id, now) do
    buffer_minutes = SettingsLogic.get_settings().tournament_buffer_minutes
    tournament_buffer = DateTime.add(now, buffer_minutes, :minute)

    from(
      team in TournamentTeamAssignment,
      where: team.seat_map_version_id == ^version_id,
      where: is_nil(team.deleted_at),
      join: tournament in assoc(team, :tournament),
      where: is_nil(tournament.deleted_at),
      where: tournament.start_date < ^tournament_buffer,
      where: tournament.end_date > ^now,
      select: %{group_id: team.group_id, team_name: team.team_name, color: team.color, label_x: team.label_x, label_y: team.label_y, tournament_name: tournament.name}
    )
    |> Repo.all()
  end

  defp editor_team_assignment_index(version_id) do
    from(
      team in TournamentTeamAssignment,
      where: team.seat_map_version_id == ^version_id,
      where: is_nil(team.deleted_at),
      join: tournament in assoc(team, :tournament),
      where: is_nil(tournament.deleted_at),
      order_by: [asc: tournament.start_date, asc: team.group_id],
      select:
        %{
          id: team.id,
          group_id: team.group_id,
          tournament_id: team.tournament_id,
          team_name: team.team_name,
          color: team.color,
          label_x: team.label_x,
          label_y: team.label_y,
          tournament_name: tournament.name,
        }
    )
    |> Repo.all()
    |> Enum.map(&stringify_map/1)
  end

  defp replace_team_assignments(version_id, assignments) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(
      team in TournamentTeamAssignment,
      where: team.seat_map_version_id == ^version_id,
      where: is_nil(team.deleted_at)
    )
    |> Repo.update_all(set: [deleted_at: now])

    assignments
    |> Enum.map(&normalize_team_assignment/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce_while(
      :ok,
      fn assignment, :ok ->
        changeset =
          TournamentTeamAssignment.changeset(%TournamentTeamAssignment{}, Map.put(assignment, "seat_map_version_id", version_id))

        case Repo.insert(changeset) do
          {:ok, _team_assignment} -> {:cont, :ok}
          {:error, changeset} -> {:halt, {:error, changeset}}
        end
      end
    )
  end

  defp replicate_team_assignments(source_version_id, target_version_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(
      team in TournamentTeamAssignment,
      where: team.seat_map_version_id == ^target_version_id,
      where: is_nil(team.deleted_at)
    )
    |> Repo.update_all(set: [deleted_at: now])

    from(
      team in TournamentTeamAssignment,
      where: team.seat_map_version_id == ^source_version_id,
      where: is_nil(team.deleted_at)
    )
    |> Repo.all()
    |> Enum.each(
      fn team ->
        %TournamentTeamAssignment{}
        |> TournamentTeamAssignment.changeset(
          %{
            tournament_id: team.tournament_id,
            seat_map_version_id: target_version_id,
            group_id: team.group_id,
            team_name: team.team_name,
            color: team.color,
            label_x: team.label_x,
            label_y: team.label_y,
          }
        )
        |> Repo.insert!()
      end
    )

    :ok
  end

  defp sync_slots_and_build_data(seat_map_id, data) do
    data = normalize_map_data(data)
    seats = data["seats"] || []

    case upsert_slots(seat_map_id, seats) do
      {:ok, slot_ids_by_key, touched_slot_ids} ->
        seats =
          Enum.map(
            seats,
            fn seat ->
              label = seat |> value("label") |> normalize_label()
              seat_slot_id = Map.get(slot_ids_by_key, value(seat, "seat_slot_id") || label)

              seat
              |> stringify_map()
              |> Map.put("seat_slot_id", seat_slot_id)
              |> Map.put("label", label)
            end
          )

        groups =
          data["groups"]
          |> Enum.map(
            fn group ->
              seat_slot_ids =
                group
                |> value("seat_slot_ids", [])
                |> Enum.map(
                  fn id_or_label ->
                    Map.get(slot_ids_by_key, id_or_label) || Map.get(slot_ids_by_key, normalize_label(id_or_label))
                  end
                )
                |> Enum.reject(&is_nil/1)

              group
              |> stringify_map()
              |> Map.put("id", value(group, "id") || Ecto.UUID.generate())
              |> Map.put("name", value(group, "name") || "Group")
              |> Map.put("seat_slot_ids", Enum.uniq(seat_slot_ids))
            end
          )

        {:ok,
         %{
           "meta" => stringify_map(data["meta"] || %{}),
           "seats" => seats,
           "objects" => Enum.map(data["objects"] || [], &stringify_map/1),
           "groups" => groups,
         }, touched_slot_ids}

      error ->
        error
    end
  end

  defp upsert_slots(seat_map_id, seats) do
    existing_slots =
      SeatSlot
      |> where([seat_slot], seat_slot.seat_map_id == ^seat_map_id and is_nil(seat_slot.deleted_at))
      |> Repo.all()

    slots_by_id = Map.new(existing_slots, &{&1.id, &1})
    slots_by_label = Map.new(existing_slots, &{&1.label, &1})

    Enum.reduce_while(
      seats,
      {:ok, %{}, []},
      fn seat, {:ok, slot_ids_by_key, touched_slot_ids} ->
        label = seat |> value("label") |> normalize_label()
        seat_slot_id = value(seat, "seat_slot_id")

        slot_result =
          cond do
            is_integer(seat_slot_id) and Map.has_key?(slots_by_id, seat_slot_id) ->
              slot = Map.fetch!(slots_by_id, seat_slot_id)
              slot |> SeatSlot.changeset(%{label: label}) |> Repo.update()

            Map.has_key?(slots_by_label, label) ->
              {:ok, Map.fetch!(slots_by_label, label)}

            true ->
              create_slot_with_pc(seat_map_id, label)
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

  defp create_slot_with_pc(seat_map_id, label) do
    asset_code = String.downcase(label)

    Multi.new()
    |> Multi.insert(:seat_slot, SeatSlot.changeset(%SeatSlot{}, %{seat_map_id: seat_map_id, label: label}))
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

  defp list_slots_catalog(seat_map_id) do
    SeatSlot
    |> where([seat_slot], seat_slot.seat_map_id == ^seat_map_id and is_nil(seat_slot.deleted_at))
    |> order_by([seat_slot], asc: seat_slot.label)
    |> Repo.all()
    |> Enum.map(
      fn seat_slot ->
        %{
          id: seat_slot.id,
          label: seat_slot.label,
          legacy_station_number: seat_slot.legacy_station_number,
        }
      end
    )
  end

  defp empty_map_data do
    %{
      "meta" => %{"zoom" => 1, "minScale" => 0.4, "maxScale" => 4},
      "seats" => [],
      "objects" => [],
      "groups" => [],
    }
  end

  defp normalize_editor_attrs(attrs) do
    attrs = stringify_map(attrs)

    data =
      Map.get(attrs, "data") ||
        %{
          "meta" => attrs["meta"] || %{},
          "seats" => attrs["seats"] || [],
          "objects" => attrs["objects"] || [],
          "groups" => attrs["groups"] || [],
        }

    attrs
    |> Map.put("data", data)
    |> Map.update("width", nil, &parse_int/1)
    |> Map.update("height", nil, &parse_int/1)
  end

  defp normalize_map_data(nil), do: empty_map_data()

  defp normalize_map_data(data) when is_map(data) do
    data = stringify_map(data)

    %{
      "meta" => stringify_map(data["meta"] || %{}),
      "seats" => Enum.map(data["seats"] || [], &normalize_seat/1),
      "objects" => Enum.map(data["objects"] || [], &normalize_object/1),
      "groups" => Enum.map(data["groups"] || [], &normalize_group/1),
    }
  end

  defp normalize_seat(seat) do
    seat = stringify_map(seat)

    %{
      "seat_slot_id" => parse_optional_int(seat["seat_slot_id"]),
      "label" => normalize_label(seat["label"] || "A01"),
      "x" => parse_int(seat["x"] || 0),
      "y" => parse_int(seat["y"] || 0),
      "width" => parse_int(seat["width"] || 88),
      "height" => parse_int(seat["height"] || 88),
      "rotation" => parse_int(seat["rotation"] || 0),
      "shape" => seat["shape"] || "rect",
    }
  end

  defp normalize_object(object) do
    object = stringify_map(object)

    %{
      "id" => object["id"] || Ecto.UUID.generate(),
      "type" => object["type"] || "rect",
      "x" => parse_int(object["x"] || 0),
      "y" => parse_int(object["y"] || 0),
      "width" => parse_int(object["width"] || 100),
      "height" => parse_int(object["height"] || 100),
      "rotation" => parse_int(object["rotation"] || 0),
      "text" => object["text"],
      "font_size" => parse_optional_int(object["font_size"]),
      "fill" => object["fill"] || "#d1d5db",
      "fill_secondary" => object["fill_secondary"],
      "stroke" => object["stroke"] || "#475569",
    }
  end

  defp normalize_group(group) do
    group = stringify_map(group)

    %{
      "id" => group["id"] || Ecto.UUID.generate(),
      "name" => group["name"] || "Group",
      "seat_slot_ids" => Enum.map(group["seat_slot_ids"] || [], &parse_group_member/1),
      "color" => group["color"] || "#1d4ed8",
      "label_x" => parse_optional_int(group["label_x"]),
      "label_y" => parse_optional_int(group["label_y"]),
    }
  end

  defp parse_group_member(value) when is_integer(value), do: value

  defp parse_group_member(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> parsed
      _ -> normalize_label(value)
    end
  end

  defp parse_group_member(value), do: value

  defp normalize_team_assignment(assignment) do
    assignment = stringify_map(assignment)
    tournament_id = parse_optional_int(assignment["tournament_id"])
    group_id = assignment["group_id"]
    team_name = assignment["team_name"]

    if is_nil(tournament_id) or is_nil(group_id) or blank?(team_name) do
      nil
    else
      %{
        "tournament_id" => tournament_id,
        "group_id" => group_id,
        "team_name" => team_name,
        "color" => assignment["color"],
        "label_x" => parse_optional_int(assignment["label_x"]),
        "label_y" => parse_optional_int(assignment["label_y"]),
      }
    end
  end

  defp normalize_label(nil), do: "A01"
  defp normalize_label(label) when is_binary(label), do: label |> String.trim() |> String.upcase()
  defp normalize_label(label), do: label |> to_string() |> normalize_label()

  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(""), do: nil
  defp parse_optional_int(value), do: parse_int(value)

  defp blank?(value), do: is_nil(value) or String.trim(to_string(value)) == ""

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(value) when is_float(value), do: round(value)
  defp parse_int(value) when is_binary(value), do: value |> Float.parse() |> elem(0) |> round()
  defp parse_int(_value), do: 0

  defp stringify_map(%_{} = struct), do: struct |> Map.from_struct() |> stringify_map()

  defp stringify_map(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), stringify_value(value)} end)
    |> Map.new()
  end

  defp stringify_map(other), do: other

  defp stringify_value(%_{} = struct), do: struct |> Map.from_struct() |> stringify_map()
  defp stringify_value(value) when is_map(value), do: stringify_map(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value), do: value

  defp value(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key) || Map.get(map, String.to_atom(key), default)
  end

  defp datetime_to_iso(nil), do: nil
  defp datetime_to_iso(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
