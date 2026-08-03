defmodule Lanpartyseating.SeatMapsLogic do
  import Ecto.Query

  require Logger

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

  def get_or_create_main_map do
    case Repo.one(from(seat_map in SeatMap, where: seat_map.slug == ^@default_slug and is_nil(seat_map.deleted_at))) do
      nil ->
        SeatMap.changeset(%{}, %{name: @default_map_name, slug: @default_slug})
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
         meta: data.meta,
         seats: Enum.map(data.seats, &editor_seat_payload(&1, label_index)),
         objects: data.objects,
         groups: data.groups,
         team_assignments: editor_team_assignment_index(draft.id),
         revision: draft.revision,
         published_revision: published.revision,
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
      groups = normalize_map_data(version.data).groups

      {:ok,
       Enum.map(
         groups,
         fn group ->
           %{
             id: group.id,
             name: group.name || group.id,
             seat_slot_ids: group.seat_slot_ids || [],
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

      case sync_slots_and_build_data(seat_map.id, attrs[:data] || %{}) do
        {:ok, synced_data, touched_slot_ids} ->
          result =
            try do
              draft
              |> SeatMapVersion.changeset(
                %{
                  name: attrs[:name] || draft.name,
                  width: attrs[:width] || draft.width,
                  height: attrs[:height] || draft.height,
                  background_kind: attrs[:background_kind] || draft.background_kind,
                  background_value: attrs[:background_value],
                  data: synced_data,
                }
              )
              |> Repo.update()
            rescue
              Ecto.StaleEntryError -> {:error, :stale_draft}
            end

          case result do
            {:ok, version} ->
              case replace_team_assignments(version.id, attrs[:team_assignments] || []) do
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
      result =
        try do
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
        rescue
          Ecto.StaleEntryError -> {:error, :stale_draft}
        end

      case result do
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
      attrs = atomize_keys(attrs)

      %TournamentTeamAssignment{}
      |> TournamentTeamAssignment.changeset(
        %{
          tournament_id: parse_int(attrs[:tournament_id]),
          seat_map_version_id: draft.id,
          group_id: attrs[:group_id],
          team_name: attrs[:team_name],
          color: attrs[:color],
          label_x: parse_optional_int(attrs[:label_x]),
          label_y: parse_optional_int(attrs[:label_y]),
          deleted_at: nil,
        }
      )
      |> Repo.insert(
        on_conflict:
          [
            set:
              [
                team_name: attrs[:team_name],
                color: attrs[:color],
                label_x: parse_optional_int(attrs[:label_x]),
                label_y: parse_optional_int(attrs[:label_y]),
                deleted_at: nil,
                updated_at: DateTime.utc_now() |> DateTime.truncate(:second),
              ],
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

  def save_and_publish_draft(attrs, expected_revision) when is_map(attrs) do
    with {:ok, seat_map} <- get_or_create_main_map(),
         {:ok, draft} <- get_draft_version(),
         {:ok, published} <- get_published_version(),
         :ok <- validate_revision(draft, expected_revision) do
      attrs = normalize_editor_attrs(attrs)

      with {:ok, synced_data, touched_slot_ids} <-
             sync_slots_and_build_data(seat_map.id, attrs[:data] || %{}),
           :ok <- ensure_publishable_with_data(published, synced_data) do
        team_assignments =
          (attrs[:team_assignments] || [])
          |> Enum.map(&normalize_team_assignment/1)
          |> Enum.reject(&is_nil/1)

        do_publish_with_data(
          draft,
          published,
          synced_data,
          attrs,
          seat_map.id,
          team_assignments,
          touched_slot_ids
        )
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

  @spec broadcast_map_update(integer(), [integer()]) :: :ok
  def broadcast_map_update(version_id, touched_slot_ids) do
    payload = %{version_id: version_id, touched_slot_ids: Enum.uniq(touched_slot_ids)}
    Phoenix.PubSub.broadcast(PubSub, "seat_map_update", {:seat_map_updated, payload})
    :ok
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
    from version in SeatMapVersion,
      where: version.seat_map_id == ^seat_map_id,
      where: version.status == ^status,
      where: is_nil(version.deleted_at),
      preload: [:seat_map],
      order_by: [desc: version.revision],
      limit: 1
  end

  defp create_empty_version(seat_map, status, name) do
    %SeatMapVersion{}
    |> SeatMapVersion.changeset(
      %{
        seat_map_id: seat_map.id,
        name: name,
        status: status,
        revision: 1,
        background_kind: "none",
        background_value: nil,
        data: empty_map_data(),
        published_at: if(status == "published", do: DateTime.utc_now() |> DateTime.truncate(:second), else: nil),
      }
    )
    |> Repo.insert()
  end

  # Creates a new draft by cloning `source_version`. Called by `get_draft_version/0`
  # when no draft exists, and by the legacy publish path as a fallback.
  # The new draft starts at source_version.revision + 1 so it is always ahead of
  # the published version it was cloned from.
  defp create_draft_from_version(%SeatMap{id: seat_map_id}, source_version) do
    %SeatMapVersion{}
    |> SeatMapVersion.changeset(
      %{
        seat_map_id: seat_map_id,
        name: "Working Draft",
        status: "draft",
        revision: source_version.revision + 1,
        width: source_version.width,
        height: source_version.height,
        background_kind: source_version.background_kind,
        background_value: source_version.background_value,
        data: source_version.data,
      }
    )
    |> Repo.insert()
  end

  defp build_payload(version, now) do
    data = normalize_map_data(version.data)
    seat_index = seat_status_index(now)
    team_assignments = team_assignment_index(version.id, now)

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
            pc_hostname: runtime[:pc_hostname],
          }
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
      meta: data.meta,
      seats: seats,
      objects: data.objects,
      groups: data.groups,
      revision: version.revision,
      team_assignments: team_assignments,
    }
  end

  defp do_publish_with_data(draft, published, synced_data, attrs, seat_map_id, team_assignments, touched_slot_ids) do
    effective_width = attrs[:width] || draft.width
    effective_height = attrs[:height] || draft.height
    effective_bg_kind = attrs[:background_kind] || draft.background_kind
    effective_bg_value = Map.get(attrs, :background_value, draft.background_value)
    effective_name = attrs[:name] || draft.name
    draft_id = draft.id

    Multi.new()
    |> Multi.update(
      :publish_draft,
      SeatMapVersion.save_data_changeset(
        draft,
        %{
          name: effective_name,
          status: "published",
          width: effective_width,
          height: effective_height,
          background_kind: effective_bg_kind,
          background_value: effective_bg_value,
          data: synced_data,
          published_at: DateTime.utc_now() |> DateTime.truncate(:second),
        }
      )
    )
    |> Multi.update(
      :retire_published,
      SeatMapVersion.status_changeset(published, %{status: "draft", published_at: nil})
    )
    |> Multi.insert(
      :new_draft,
      SeatMapVersion.changeset(
        %SeatMapVersion{},
        %{
          seat_map_id: seat_map_id,
          name: "Working Draft",
          status: "draft",
          revision: draft.revision + 1,
          width: effective_width,
          height: effective_height,
          background_kind: effective_bg_kind,
          background_value: effective_bg_value,
          data: synced_data,
        }
      )
    )
    |> Multi.run(
      :replace_draft_assignments,
      fn repo, _changes ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        from(
          team in TournamentTeamAssignment,
          where: team.seat_map_version_id == ^draft_id,
          where: is_nil(team.deleted_at)
        )
        |> repo.update_all(set: [deleted_at: now])

        team_assignments
        |> Enum.reduce_while(
          {:ok, nil},
          fn assignment, {:ok, _} ->
            changeset =
              TournamentTeamAssignment.changeset(
                %TournamentTeamAssignment{},
                Map.put(assignment, :seat_map_version_id, draft_id)
              )

            case repo.insert(changeset) do
              {:ok, _} -> {:cont, {:ok, nil}}
              {:error, changeset} -> {:halt, {:error, changeset}}
            end
          end
        )
      end
    )
    |> Multi.run(
      :replicate_assignments,
      fn repo, %{publish_draft: published_version, new_draft: new_draft} ->
        source_id = published_version.id
        target_id = new_draft.id
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        from(
          team in TournamentTeamAssignment,
          where: team.seat_map_version_id == ^target_id,
          where: is_nil(team.deleted_at)
        )
        |> repo.update_all(set: [deleted_at: now])

        from(
          team in TournamentTeamAssignment,
          where: team.seat_map_version_id == ^source_id,
          where: is_nil(team.deleted_at)
        )
        |> repo.all()
        |> Enum.each(
          fn team ->
            %TournamentTeamAssignment{}
            |> TournamentTeamAssignment.changeset(
              %{
                tournament_id: team.tournament_id,
                seat_map_version_id: target_id,
                group_id: team.group_id,
                team_name: team.team_name,
                color: team.color,
                label_x: team.label_x,
                label_y: team.label_y,
              }
            )
            |> repo.insert!()
          end
        )

        {:ok, :ok}
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{publish_draft: version}} ->
        broadcast_map_update(version.id, touched_slot_ids)
        {:ok, version}

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
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

  defp seat_label_index(seat_map_id) do
    SeatSlot
    |> where([seat_slot], seat_slot.seat_map_id == ^seat_map_id and is_nil(seat_slot.deleted_at))
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
      status: "available",
      reservation_end_date: nil,
    }
  end

  defp validate_revision(_draft, nil), do: :ok

  defp validate_revision(draft, expected_revision) do
    if draft.revision == parse_int(expected_revision) do
      :ok
    else
      {:error, :stale_draft}
    end
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
       shape: seat.shape,
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
          TournamentTeamAssignment.changeset(
            %TournamentTeamAssignment{},
            Map.put(assignment, :seat_map_version_id, version_id)
          )

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
    seats = data.seats

    case upsert_slots(seat_map_id, seats) do
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

        groups =
          Enum.map(
            data.groups,
            fn group ->
              seat_slot_ids =
                (group.seat_slot_ids || [])
                |> Enum.map(
                  fn id_or_label ->
                    Map.get(slot_ids_by_key, id_or_label) ||
                      Map.get(slot_ids_by_key, normalize_label(id_or_label))
                  end
                )
                |> Enum.reject(&is_nil/1)

              %{group | id: group.id || Ecto.UUID.generate(), name: group.name || "Group", seat_slot_ids: Enum.uniq(seat_slot_ids)}
            end
          )

        {:ok,
         %{
           meta: data.meta,
           seats: seats,
           objects: data.objects,
           groups: groups,
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
      meta: %{zoom: 1, minScale: 0.4, maxScale: 4},
      seats: [],
      objects: [],
      groups: [],
    }
  end

  defp normalize_editor_attrs(attrs) do
    attrs = atomize_keys(attrs)

    data =
      attrs[:data] ||
        %{
          meta: attrs[:meta] || %{},
          seats: attrs[:seats] || [],
          objects: attrs[:objects] || [],
          groups: attrs[:groups] || [],
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
      objects: Enum.map(data.objects, &normalize_object/1),
      groups: Enum.map(data.groups, &normalize_group/1),
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
      text: object.text,
      font_size: parse_optional_int(object.font_size),
      fill: object.fill,
      fill_secondary: object.fill_secondary,
      stroke: object.stroke,
    }
  end

  defp normalize_group(group) do
    group = atomize_keys(group)

    %{
      id: group[:id] || Ecto.UUID.generate(),
      name: group.name,
      seat_slot_ids: Enum.map(group.seat_slot_ids, &parse_group_member/1),
      color: group.color,
      label_x: group.label_x,
      label_y: group.label_y,
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
    assignment = atomize_keys(assignment)
    tournament_id = parse_optional_int(assignment.tournament_id)
    group_id = assignment.group_id
    team_name = assignment.team_name

    if is_nil(tournament_id) or is_nil(group_id) or blank?(team_name) do
      raise ArgumentError, "Invalid team assignment: #{inspect(assignment)}"
    else
      %{
        tournament_id: tournament_id,
        group_id: group_id,
        team_name: team_name,
        color: assignment[:color],
        label_x: parse_optional_int(assignment[:label_x]),
        label_y: parse_optional_int(assignment[:label_y]),
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
