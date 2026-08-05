defmodule Lanpartyseating.OnboardingLogic do
  @moduledoc """
  First-run setup state machine for a fresh install.

  The wizard walks four steps in strict order — admin account, Room, layout, event
  settings — advancing the monotonic `setup_state` enum on the settings singleton.
  Each step performs its resource write and its state transition inside one
  transaction, so the enum can never drift from reality. The application is treated
  as not-live until `setup_state` is `:complete`.
  """

  alias Ecto.Multi
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
      description: "The account you will use to manage seats, reservations, and settings for the event."
    },
    %{
      id: :room,
      title: "Create your room",
      description: "A Room is the physical space that holds your Seats. You can rename it and add more rooms later."
    },
    %{
      id: :layout,
      title: "Set up your layout",
      description: "Start from an empty canvas or paste a layout exported from another event's editor."
    },
    %{
      id: :settings,
      title: "Review your event settings",
      description: "Reservation length, tournament buffer, and kiosk behaviour. All editable later in General settings."
    }
  ]

  def steps, do: @steps

  def states, do: Setting.setup_states()

  @doc "The current setup state, or `:not_started` when the settings row does not exist yet."
  def state do
    case Repo.get(Setting, 1) do
      nil -> :not_started
      settings -> settings.setup_state
    end
  end

  def complete? do
    state() == :complete
  end

  @doc "Index of the current step in the wizard (0-based), or `nil` once setup is complete."
  def step_index do
    case Enum.find_index(states(), &(&1 == state())) do
      nil -> nil
      index when index < length(@steps) -> index
      _index -> nil
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
    with :ok <- ensure_state(:not_started),
         {:ok, changes} <-
           run_transaction(
             Multi.new()
             |> Multi.run(:user, fn _repo, _changes -> Accounts.create_user(attrs) end)
             |> Multi.run(:confirm, fn repo, %{user: user} ->
               user |> User.confirm_changeset() |> repo.update()
             end)
             |> append_transition(:admin_created)
           ) do
      {:ok, changes.confirm}
    end
  end

  @doc "Creates the Room (random animal name when omitted) and advances to the Layout step."
  def create_room(attrs \\ %{}) do
    attrs = Map.put_new(attrs, :name, SeatMapsLogic.random_room_name())

    with :ok <- ensure_state(:admin_created),
         {:ok, changes} <-
           run_transaction(
             Multi.new()
             |> Multi.run(:room, fn _repo, _changes -> SeatMapsLogic.create_room(attrs) end)
             |> append_transition(:room_created)
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
             |> append_transition(:layout_ready)
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
             |> append_transition(:layout_ready)
           ) do
      {:ok, changes.publish}
    end
  end

  def import_layout(_invalid), do: {:error, :invalid_json}

  @doc "Writes the event settings and completes onboarding."
  def configure_settings(attrs) do
    with :ok <- ensure_state(:layout_ready),
         {:ok, changes} <-
           run_transaction(SettingsLogic.settings_db_changes(attrs) |> append_transition(:complete)) do
      {:ok, changes.transition}
    end
  end

  defp ensure_state(expected) do
    if state() == expected, do: :ok, else: {:error, :wrong_state}
  end

  defp append_transition(multi, next_state) do
    Multi.run(multi, :transition, fn repo, _changes ->
      repo.get!(Setting, 1)
      |> Setting.changeset(%{setup_state: next_state})
      |> repo.update()
    end)
  end

  defp run_transaction(multi) do
    case Repo.transaction(multi) do
      {:ok, changes} -> {:ok, changes}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  defp decode_layout(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _exception} -> {:error, :invalid_json}
    end
  end
end
