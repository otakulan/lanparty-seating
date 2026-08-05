defmodule Lanpartyseating.OnboardingLogic do
  @moduledoc """
             First-run setup state machine for a fresh install.

             The wizard walks four steps in strict order — admin account, Room, layout, event
             settings — advancing the monotonic `setup_state` enum on the settings singleton.
             Each step performs its resource write and its state transition inside one
             transaction, so the enum can never drift from reality. The application is treated
             as not-live until `setup_state` is `:complete`.

             ## Invariant

             Every step refuses to run unless the current state is exactly the one it expects.
             The check is performed inside the transaction that writes the step's effects, so
             concurrent or out-of-order requests are rejected deterministically with
             `{:error, :wrong_state}` rather than corrupting the state.
             """

  alias Ecto.Multi
  require Ecto.Query
  alias Lanpartyseating.Accounts
  alias Lanpartyseating.Accounts.User
  alias Lanpartyseating.Repo
  alias Lanpartyseating.SeatMapsLogic
  alias Lanpartyseating.Setting
  alias Lanpartyseating.SettingsLogic

  @steps [
           %{
             id: :account,
             title: "Create your admin account",
             description: "The account you will use to manage seats, reservations, and settings for the event.",
           },
           %{
             id: :room,
             title: "Create your room",
             description: "A Room is the physical space that holds your Seats. You can rename it and add more rooms later.",
           },
           %{
             id: :layout,
             title: "Set up your layout",
             description: "Start from an empty canvas or paste a layout exported from another event's editor.",
           },
           %{
             id: :settings,
             title: "Review your event settings",
             description: "Reservation length, tournament buffer, and kiosk behaviour. All editable later in General settings.",
           },
         ]

  def steps, do: @steps

  @doc """
       The current setup state.

       Returns `:not_started` when the settings singleton does not exist yet (for example,
       on a freshly migrated database where seeds have not run).
       """
  def state do
    case Repo.get(Setting, 1) do
      nil -> :not_started
      settings -> settings.setup_state
    end
  end

  def complete?, do: state() == :complete

  @doc """
       Zero-based index of the step the operator should be shown, or `nil` once complete.

       The index is the position of the current state in `Setting.setup_states/0`, so it
       never depends on `@steps` ids matching the state atom names.
       """
  def step_index do
    case Enum.find_index(Setting.setup_states(), &(&1 == state())) do
      index when is_integer(index) and index < length(@steps) -> index
      _otherwise -> nil
    end
  end

  @doc "The Active Room's first Seat Map. Returns `{:ok, map}` or `{:error, reason}`."
  def current_room_map do
    with {:ok, room} <- SeatMapsLogic.get_active_room() do
      case SeatMapsLogic.list_seat_maps(room.id) do
        [] -> {:error, :no_map}
        [map | _rest] -> {:ok, map}
      end
    end
  end

  @doc "Creates and confirms the admin account, then advances to the Room step."
  def create_admin(attrs) do
    with {:ok, changes} <-
           run_transaction(
             Multi.new()
             |> Multi.run(:user, fn _repo, _changes -> Accounts.create_user(attrs) end)
             |> Multi.run(
               :confirm,
               fn repo, %{user: user} ->
                 user |> User.confirm_changeset() |> repo.update()
               end
             )
             |> guard_state(:not_started)
             |> transition(:admin_created)
           ) do
      {:ok, changes.confirm}
    end
  end

  @doc "Creates the Room (random animal name when omitted) and advances to the Layout step."
  def create_room(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :name, SeatMapsLogic.random_room_name())

    with {:ok, changes} <-
           run_transaction(
             Multi.new()
             |> Multi.run(:room, fn _repo, _changes -> SeatMapsLogic.create_room(attrs) end)
             |> guard_state(:admin_created)
             |> transition(:room_created)
           ) do
      {:ok, changes.room}
    end
  end

  @doc "Publishes the Room's first (empty) Seat Map and advances to the Settings step."
  def publish_empty_layout do
    with :ok <- ensure_state(:room_created),
         {:ok, map} <- current_room_map(),
         {:ok, changes} <-
           run_transaction(
             Multi.new()
             |> Multi.run(:publish, fn _repo, _changes -> SeatMapsLogic.publish_seat_map(map.id) end)
             |> guard_state(:room_created)
             |> transition(:layout_ready)
           ) do
      {:ok, changes.publish}
    end
  end

  @doc "Imports a JSON layout into the Room's first map, publishes it, and advances."
  def import_layout(%{"json" => json}) when is_binary(json) do
    with :ok <- ensure_state(:room_created),
         {:ok, map} <- current_room_map(),
         {:ok, decoded} <- decode_layout(json),
         {:ok, changes} <-
           run_transaction(
             Multi.new()
             |> Multi.run(:save, fn _repo, _changes -> SeatMapsLogic.save_version(map.id, decoded, 1) end)
             |> Multi.run(:publish, fn _repo, _changes -> SeatMapsLogic.publish_seat_map(map.id) end)
             |> guard_state(:room_created)
             |> transition(:layout_ready)
           ) do
      {:ok, changes.publish}
    end
  end

  def import_layout(_invalid), do: {:error, :invalid_json}

  @doc "Writes the event settings and completes onboarding."
  def configure_settings(attrs) do
    multi = SettingsLogic.settings_db_changes(attrs) |> guard_state(:layout_ready)

    with {:ok, changes} <- run_transaction(transition(multi, :complete, attrs)) do
      {:ok, changes.transition}
    end
  end

  defp ensure_state(expected) do
    if state() == expected, do: :ok, else: {:error, :wrong_state}
  end

  defp guard_state(multi, expected) do
    Multi.run(
      multi,
      :guard,
      fn repo, _changes ->
        case repo.one(Ecto.Query.from(Setting, where: [id: 1], lock: "FOR UPDATE")) do
          nil when expected == :not_started -> {:ok, :ok}
          nil -> {:error, :wrong_state}
          %Setting{setup_state: ^expected} -> {:ok, :ok}
          %Setting{} -> {:error, :wrong_state}
        end
      end
    )
  end

  defp transition(multi, next_state, attrs \\ nil) do
    Multi.run(
      multi,
      :transition,
      fn repo, _changes ->
        case repo.get(Setting, 1) do
          nil ->
            %Setting{id: 1}
            |> Setting.changeset(%{setup_state: next_state})
            |> repo.insert()

          setting ->
            setting
            |> Setting.changeset(%{setup_state: next_state})
            |> then(fn changeset -> if(attrs, do: Setting.changeset(changeset, attrs), else: changeset) end)
            |> repo.update()
        end
      end
    )
  end

  defp run_transaction(multi) do
    case Repo.transaction(multi) do
      {:ok, changes} -> {:ok, changes}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  defp decode_layout(json) do
    case Jason.decode(json) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _non_map} -> {:error, :invalid_json}
      {:error, _exception} -> {:error, :invalid_json}
    end
  end
end
