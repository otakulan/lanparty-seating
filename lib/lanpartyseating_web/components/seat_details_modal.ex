defmodule LanpartyseatingWeb.Components.SeatDetailsModal do
  use LanpartyseatingWeb, :live_component

  alias Lanpartyseating.SeatMapsLogic

  # Keeps the modal open long enough for the unlock animation to play out
  # before the parent closes it.
  @unlock_animation_ms 900

  def mount(socket) do
    {:ok,
     assign(socket,
       seat: nil,
       show: false,
       badge_input: false,
       badge_form: false,
       reserving: false,
       on_close: "close_modal",
       actions: []
     )}
  end

  def update(assigns, socket) do
    opening? = assigns.show and not socket.assigns.show

    socket =
      socket
      |> assign(retain_seat(assigns))
      |> reset_reserving(opening?)

    socket = assign(socket, :badge_form, badge_form?(socket.assigns))

    {:ok, socket}
  end

  def handle_event("reserve", %{"badge_uid" => badge_uid}, socket) do
    %{legacy_station_number: seat_slot_id} = socket.assigns.seat
    {:ok, _} = SeatMapsLogic.reserve_seat_slot(seat_slot_id, badge_uid)
    Process.send_after(self(), {:seat_reserved, seat_slot_id}, @unlock_animation_ms)

    {:noreply, assign(socket, :reserving, true)}
  end

  def render(assigns) do
    ~H"""
    <dialog
      id={@id}
      class={["modal", @show && "modal-open"]}
      phx-window-keydown={@show && @on_close}
      phx-key="Escape"
    >
      <.focus_wrap :if={@seat} id={"#{@id}-focus"} class="modal-box max-w-md relative">
        <div class="space-y-4">
          <div class="flex items-center gap-2">
            <span class="text-tiny uppercase text-base-content/60">
              Détails du poste / Seat Details
            </span>
          </div>

          <div class="flex items-center justify-between gap-2">
            <h2 class="text-4xl font-bold text-base-content">{@seat.label}</h2>
            <span class={[
              "flex items-center gap-1.5 rounded border px-3 py-1.5 text-sm font-mono uppercase tracking-wider",
              status_classes(@seat.status)
            ]}>
              <.status_icon status={@seat.status} />
              {status_text(@seat.status)}
            </span>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div class="rounded-lg border border-base-300 bg-base-200 p-3">
              <p class="text-tiny uppercase text-base-content/60 mb-1">
                PC
              </p>
              <p class="font-mono text-lg text-success">{@seat.pc_asset_code}</p>
            </div>
            <div class="rounded-lg border border-base-300 bg-base-200 p-3">
              <p class="text-tiny uppercase text-base-content/60 mb-1">
                Nom d'hôte / Hostname
              </p>
              <p class="font-mono text-lg text-info truncate">{@seat.pc_hostname}</p>
            </div>
          </div>

          <%= if @seat.reservation_end_date do %>
            <div class="rounded-lg border border-warning/50 bg-warning/10 p-3">
              <p class="text-sm text-warning">
                <span class="font-semibold">Réservé jusqu'à:</span> {format_iso_datetime(@seat.reservation_end_date)}
                <span class="font-semibold">Reserved until:</span> {format_iso_datetime(@seat.reservation_end_date)}
              </p>
            </div>
          <% end %>

          <form :if={@badge_form} phx-submit="reserve" phx-target={@myself} class="form-control gap-2">
            <fieldset class="fieldset bg-base-200 border-base-300 rounded-box border p-4 w-full">
              <legend class="fieldset-legend">Réserver / Reserve</legend>
              <div class="join w-full">
                <%!-- This input will only be autofocused by the browser if its the first input (including buttons) in the dialog --%>
                <input
                  type="text"
                  id={"#{@id}-badge-uid"}
                  name="badge_uid"
                  class="input input-bordered join-item flex-1"
                  placeholder="Badge ID"
                  autocomplete="off"
                  phx-hook="AutoFocus"
                  required
                  disabled={@reserving}
                />
                <button type="submit" class="btn btn-primary join-item"  disabled={@reserving}>
                  <label class={["swap swap-rotate inline-flex h-4 w-4", @reserving && "swap-active"]}>
                    <Icons.lock class="swap-on absolute inset-0 h-4 w-4" />
                    <Icons.lock_open class="swap-off absolute inset-0 h-4 w-4" />
                  </label>
                </button>
              </div>
            </fieldset>
          </form>

          <%= if @actions != [] do %>
            <div class="mt-4 flex justify-end gap-2">
              {render_slot(@actions)}
            </div>
          <% end %>
        </div>

        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click={@on_close}
        >
          <Icons.x class="h-4 w-4" />
        </button>
      </.focus_wrap>
      <div class="modal-backdrop" phx-click={@on_close}></div>
    </dialog>
    """
  end

  # The parent clears its selection as soon as the modal closes; the component
  # keeps the last seat on screen so the closing animation has content to fade out.
  # defp retain_seat(%{seat: nil} = assigns), do: Map.delete(assigns, :seat)
  defp retain_seat(assigns), do: assigns

  defp reset_reserving(socket, true), do: assign(socket, :reserving, false)
  defp reset_reserving(socket, false), do: socket

  defp badge_form?(%{badge_input: true, seat: %{status: :available}}), do: true
  defp badge_form?(_assigns), do: false

  defp status_classes(:available), do: "border-success bg-success/10 text-success"
  defp status_classes(:occupied), do: "border-warning bg-warning/10 text-warning"
  defp status_classes(:reserved), do: "border-base-400 bg-base-300/50 text-base-content/70"
  defp status_classes(:unavailable), do: "border-error bg-error/10 text-error"
  defp status_classes(:tournament), do: "border-info bg-info/10 text-info"
  defp status_classes(_), do: "border-base-300 bg-base-200 text-base-content/60"

  defp status_icon(assigns) do
    ~H"""
    <%= case @status do %>
      <% :available -> %><Icons.circle_check_big class="h-4 w-4" />
      <% :occupied -> %><Icons.clock class="h-4 w-4" />
      <% :unavailable -> %><Icons.octagon_x class="h-4 w-4" />
      <% :tournament -> %><Icons.trophy class="h-4 w-4" />
      <% :reserved -> %><Icons.lock class="h-4 w-4" />
      <% _ -> %><Icons.help_circle class="h-4 w-4" />
    <% end %>
    """
  end

  defp status_text(:available), do: "Disponible / Available"
  defp status_text(:occupied), do: "Occupé / Occupied"
  defp status_text(:reserved), do: "Réservé / Reserved"
  defp status_text(:unavailable), do: "Hors service / Unavailable"
  defp status_text(:tournament), do: "Tournoi / Tournament"
  defp status_text(status) when is_binary(status), do: String.capitalize(status)
  defp status_text(_), do: "Unknown"

  defp format_iso_datetime(iso_value) do
    case DateTime.from_iso8601(iso_value) do
      {:ok, datetime, _offset} -> Calendar.strftime(datetime, "%H:%M")
      _ -> iso_value
    end
  end
end
