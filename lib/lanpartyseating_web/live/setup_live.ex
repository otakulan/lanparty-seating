defmodule LanpartyseatingWeb.SetupLive do
  @moduledoc """
             First-run onboarding wizard. Renders a checklist whose current step is derived
             entirely from the `setup_state` enum in the database, so progress survives reloads.
             Once setup is `:complete` the page redirects to `/settings` and the gate plug takes
             over (every route bounces to `/setup` until then).
             """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.OnboardingLogic
  alias Lanpartyseating.RoomsLogic

  @defaults %{
              reservation_duration_minutes: 50,
              tournament_buffer_minutes: 30,
              seat_picking_enabled_in_kiosk: false,
            }

  def mount(_params, _session, socket) do
    if OnboardingLogic.complete?() do
      {:ok, redirect(socket, to: ~p"/settings")}
    else
      socket =
        socket
        |> assign(:page_title, "Setup")
        |> assign(:room_name, RoomsLogic.random_room_name())
        |> assign(:layout_choice, :empty)
        |> assign(:import_json, "")
        |> assign(:just_completed, false)
        |> assign(:map_public_id, nil)
        |> assign(:settings, @defaults)
        |> reload()

      {:ok, socket}
    end
  end

  def handle_event("create_room", %{"room" => room_params}, socket) do
    room_params |> OnboardingLogic.create_room() |> resolve(socket)
  end

  def handle_event("set_layout_choice", %{"choice" => "import"}, socket) do
    {:noreply, assign(socket, :layout_choice, :import)}
  end

  def handle_event("set_layout_choice", %{"choice" => _choice}, socket) do
    {:noreply, assign(socket, :layout_choice, :empty)}
  end

  def handle_event("set_import_json", %{"json" => json}, socket) do
    {:noreply, assign(socket, :import_json, json)}
  end

  def handle_event("finish_layout", _params, socket) do
    socket.assigns
    |> publish_layout()
    |> resolve(socket)
  end

  def handle_event("configure_settings", %{"settings" => settings_params}, socket) do
    case settings_params |> settings_attrs() |> OnboardingLogic.configure_settings() do
      {:ok, _settings} ->
        {:noreply, socket |> reload() |> assign(:just_completed, true) |> load_map_public_id()}

      error ->
        resolve(error, socket)
    end
  end

  defp publish_layout(%{layout_choice: :empty}), do: OnboardingLogic.publish_empty_layout()
  defp publish_layout(%{layout_choice: :import, import_json: json}), do: OnboardingLogic.import_layout(%{"json" => json})

  defp settings_attrs(params) do
    %{
      reservation_duration_minutes: params["reservation_duration_minutes"],
      tournament_buffer_minutes: params["tournament_buffer_minutes"],
      seat_picking_enabled_in_kiosk: Map.get(params, "seat_picking_enabled_in_kiosk", "false") == "true",
    }
  end

  defp resolve({:ok, _result}, socket), do: {:noreply, reload(socket)}
  defp resolve({:error, :invalid_json}, socket), do: {:noreply, put_flash(socket, :error, "Invalid JSON")}
  defp resolve({:error, :invalid_layout}, socket), do: {:noreply, put_flash(socket, :error, "Invalid layout JSON")}

  defp resolve({:error, %Ecto.Changeset{} = changeset}, socket) do
    {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}
  end

  defp resolve({:error, reason}, socket), do: {:noreply, put_flash(socket, :error, inspect(reason))}

  defp reload(socket) do
    step_index = OnboardingLogic.step_index()

    socket
    |> assign(:steps, enrich_steps(step_index))
    |> assign(:completed_count, completed_count(step_index))
  end

  defp load_map_public_id(socket) do
    case OnboardingLogic.current_room_map() do
      {:ok, map} -> assign(socket, :map_public_id, map.public_id)
      {:error, _reason} -> socket
    end
  end

  defp enrich_steps(step_index) do
    OnboardingLogic.steps()
    |> Enum.with_index()
    |> Enum.map(fn {step, index} -> Map.put(step, :status, step_status(step_index, index)) end)
  end

  defp step_status(nil, _index), do: :done
  defp step_status(step_index, index) when index < step_index, do: :done
  defp step_status(step_index, index) when index == step_index, do: :current
  defp step_status(_step_index, _index), do: :locked

  defp completed_count(nil), do: if(OnboardingLogic.complete?(), do: 4, else: 0)
  defp completed_count(step_index), do: step_index

  def render(%{just_completed: true} = assigns) do
    ~H"""
    <div class="relative min-h-full bg-base-200">
      <.page_background />
      <div class="hero min-h-full">
        <div class="hero-content w-full max-w-xl flex-col px-4 text-center">
          <span class="grid size-16 place-items-center rounded-full bg-success/10 text-success">
            <Icons.party_popper class="size-8" />
          </span>
          <h1 class="text-2xl font-semibold sm:text-3xl">You're all set!</h1>
          <p class="text-sm text-base-content/60 sm:text-base">
            Your room is live and ready. Add seats to the layout to start accepting reservations.
          </p>
          <div class="mt-2 flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:justify-center">
            <.link
              :if={@map_public_id}
              href={~p"/settings/seat-maps/#{@map_public_id}/edit"}
              class="btn btn-primary w-full sm:w-auto"
            >
              Add seats
            </.link>
            <.link href={~p"/settings"} class="btn btn-outline w-full sm:w-auto">Go to settings</.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="relative flex min-h-full flex-col bg-base-200">
      <.page_background />
      <header class="border-b border-base-300/60 px-4 py-6 sm:px-8 lg:px-12">
        <div class="mx-auto flex w-full max-w-3xl items-start justify-between gap-4">
          <div class="min-w-0">
            <h1 class="flex items-center gap-3 text-xl font-semibold sm:text-2xl lg:text-3xl">
              <span class="grid size-10 shrink-0 place-items-center rounded-box bg-primary/10 text-primary">
                <Icons.rocket class="size-5" />
              </span>
              Get started
            </h1>
            <p class="mt-3 max-w-sm text-sm text-base-content/60">
              Four steps and this event is ready to take reservations.
            </p>
          </div>
          <.progress_meter completed_count={@completed_count} />
        </div>
      </header>

      <main class="flex-1 px-4 py-6 sm:px-8 lg:px-12 lg:py-10">
        <ol class="mx-auto w-full max-w-3xl space-y-3">
          <li
            :for={{step, index} <- Enum.with_index(@steps)}
            class={["rounded-box border p-4 sm:p-5", step_card_class(step.status)]}
          >
            <div class="flex items-start gap-3 sm:gap-4">
              <.step_indicator status={step.status} number={index + 1} />
              <div class="min-w-0 flex-1">
                <h2 class={step_title_class(step.status)}>{step.title}</h2>
                <p :if={step.status == :current} class="mt-1 text-sm text-base-content/60">
                  {step.description}
                </p>
                <div :if={step.status == :current} class="mt-4">
                  {step_form(step.id, @room_name, @layout_choice, @import_json, @settings)}
                </div>
              </div>
            </div>
          </li>
        </ol>
      </main>
    </div>
    """
  end

  defp step_form(:account, _room_name, _layout_choice, _import_json, _settings) do
    assigns = %{}

    ~H"""
    <form id="account-form" action={to_string(~p"/setup/login")} method="post" class="space-y-4">
      <input name="_csrf_token" type="hidden" value={Plug.CSRFProtection.get_csrf_token()} />
      <div class="grid gap-x-4 sm:grid-cols-2">
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Name</legend>
          <input name="user[name]" class="input w-full" required />
        </fieldset>
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Email</legend>
          <input name="user[email]" type="email" class="input w-full" required />
        </fieldset>
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Password</legend>
          <input name="user[password]" type="password" class="input w-full" required minlength="12" />
          <p class="label">At least 12 characters</p>
        </fieldset>
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Confirm password</legend>
          <input name="user[password_confirmation]" type="password" class="input w-full" required />
        </fieldset>
      </div>
      <.step_actions>
        <button class="btn btn-primary w-full sm:w-auto">Create account</button>
      </.step_actions>
    </form>
    """
  end

  defp step_form(:room, room_name, _layout_choice, _import_json, _settings) do
    assigns = %{room_name: room_name}

    ~H"""
    <.form for={%{}} as={:room} id="room-form" phx-submit="create_room" class="space-y-4">
      <fieldset class="fieldset max-w-sm">
        <legend class="fieldset-legend">Room name</legend>
        <input name="room[name]" value={@room_name} class="input w-full" required />
        <p class="label">Rename it later from the seat map catalogue.</p>
      </fieldset>
      <.step_actions>
        <button class="btn btn-primary w-full sm:w-auto">Create room</button>
      </.step_actions>
    </.form>
    """
  end

  defp step_form(:layout, _room_name, layout_choice, import_json, _settings) do
    assigns = %{layout_choice: layout_choice, import_json: import_json}

    ~H"""
    <div class="space-y-4">
      <div class="join w-full sm:w-auto">
        <button
          type="button"
          phx-click="set_layout_choice"
          phx-value-choice="empty"
          aria-pressed={to_string(@layout_choice == :empty)}
          class={["btn join-item flex-1 sm:w-44 sm:flex-none", layout_choice_class(@layout_choice == :empty)]}
        >
          <Icons.layout_grid class="size-4" /> Empty layout
        </button>
        <button
          type="button"
          phx-click="set_layout_choice"
          phx-value-choice="import"
          aria-pressed={to_string(@layout_choice == :import)}
          class={["btn join-item flex-1 sm:w-44 sm:flex-none", layout_choice_class(@layout_choice == :import)]}
        >
          <Icons.file_json class="size-4" /> Import JSON
        </button>
      </div>

      <.form :if={@layout_choice == :import} for={%{}} phx-change="set_import_json">
        <textarea
          name="json"
          class="textarea w-full font-mono text-xs sm:text-sm"
          rows="6"
          placeholder="Paste a layout exported from another event's editor"
        >{@import_json}</textarea>
      </.form>

      <.step_actions>
        <button phx-click="finish_layout" class="btn btn-primary w-full sm:w-auto">
          {if @layout_choice == :empty, do: "Publish empty layout", else: "Import & publish"}
        </button>
      </.step_actions>
    </div>
    """
  end

  defp step_form(:settings, _room_name, _layout_choice, _import_json, settings) do
    assigns = %{settings: settings}

    ~H"""
    <.form for={%{}} as={:settings} id="settings-form" phx-submit="configure_settings" class="space-y-4">
      <div class="grid gap-x-4 sm:grid-cols-2">
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Reservation duration (minutes)</legend>
          <input
            name="settings[reservation_duration_minutes]"
            type="number"
            min="5"
            max="480"
            value={@settings.reservation_duration_minutes}
            class="input w-full"
          />
        </fieldset>
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Tournament buffer (minutes)</legend>
          <input
            name="settings[tournament_buffer_minutes]"
            type="number"
            min="5"
            max="480"
            value={@settings.tournament_buffer_minutes}
            class="input w-full"
          />
        </fieldset>
      </div>
      <fieldset class="fieldset">
        <label class="fieldset-label text-base-content">
          <input
            type="checkbox"
            name="settings[seat_picking_enabled_in_kiosk]"
            value="true"
            class="toggle toggle-primary"
            checked={@settings.seat_picking_enabled_in_kiosk}
          /> Seat picking enabled in kiosk
        </label>
      </fieldset>
      <.step_actions>
        <button class="btn btn-primary w-full sm:w-auto">Finish setup</button>
      </.step_actions>
    </.form>
    """
  end

  slot :inner_block, required: true

  defp step_actions(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp page_background(assigns) do
    ~H"""
    <div
      aria-hidden="true"
      class="pointer-events-none absolute inset-0 -z-10 bg-linear-to-br from-base-200 via-base-200 to-base-300"
    >
    </div>
    """
  end

  defp progress_meter(assigns) do
    assigns = assign(assigns, :dash_offset, 100 - round(assigns.completed_count / 4 * 100))

    ~H"""
    <div class="flex shrink-0 items-center gap-3">
      <svg
        class="size-9 shrink-0 -rotate-90"
        viewBox="0 0 14 14"
        role="img"
        aria-label={"#{@completed_count} of 4 steps completed"}
      >
        <circle class="stroke-base-300" cx="7" cy="7" fill="none" pathLength="100" r="6" stroke-width="2" />
        <circle
          class="stroke-primary"
          cx="7"
          cy="7"
          fill="none"
          pathLength="100"
          r="6"
          stroke-dasharray="100"
          stroke-linecap="round"
          stroke-width="2"
          style={"stroke-dashoffset: #{@dash_offset}"}
        />
      </svg>
      <span class="whitespace-nowrap text-sm text-base-content/60">
        <span class="font-medium text-base-content">{@completed_count}</span> / 4 <span class="hidden sm:inline">completed</span>
      </span>
    </div>
    """
  end

  defp step_indicator(%{status: :done} = assigns) do
    ~H"""
    <Icons.circle_check_big class="mt-0.5 size-6 shrink-0 text-success" />
    """
  end

  defp step_indicator(%{status: :current} = assigns) do
    ~H"""
    <span class="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-primary text-xs font-semibold text-primary-content">
      {@number}
    </span>
    """
  end

  defp step_indicator(assigns) do
    ~H"""
    <span class="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full border border-base-300 text-xs font-semibold text-base-content/40">
      {@number}
    </span>
    """
  end

  defp layout_choice_class(true), do: "btn-primary"
  defp layout_choice_class(false), do: "btn-outline"

  defp step_card_class(:done), do: "border-base-300/60 bg-base-100/60"
  defp step_card_class(:current), do: "border-primary/40 bg-base-100 shadow-md"
  defp step_card_class(:locked), do: "border-base-300/60 bg-base-100/40"

  defp step_title_class(:current), do: "font-semibold text-primary"
  defp step_title_class(_status), do: "font-semibold text-base-content/50"
end
