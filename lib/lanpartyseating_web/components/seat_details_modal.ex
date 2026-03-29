defmodule LanpartyseatingWeb.Components.SeatDetailsModal do
  use Phoenix.Component

  attr :id, :string, default: "seat-modal"
  attr :show, :boolean, default: false
  attr :seat, :map, default: nil
  attr :on_close, :string, default: "close_modal"

  slot :actions

  def modal(assigns) do
    ~H"""
    <dialog
      id={@id}
      class={["modal", @show && "modal-open"]}
      phx-window-keydown={@show && @on_close}
      phx-key="Escape"
    >
      <.focus_wrap :if={@seat} id={"#{@id}-focus"} class="modal-box max-w-md relative">
        <button
          type="button"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
          phx-click={@on_close}
        >
          ✕
        </button>

        <div class="space-y-4">
          <div class="flex items-center gap-2">
            <span class="text-tiny uppercase text-base-content/60">
              Détails du poste / Seat Details
            </span>
          </div>

          <div class="flex items-center justify-between gap-2">
            <h2 class="text-4xl font-bold text-base-content">{@seat["label"]}</h2>
            <span class={[
              "rounded border px-3 py-1.5 text-sm font-mono uppercase tracking-wider",
              status_classes(@seat["status"])
            ]}>
              {status_text(@seat["status"])}
            </span>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div class="rounded-lg border border-base-300 bg-base-200 p-3">
              <p class="text-tiny uppercase text-base-content/60 mb-1">
                PC
              </p>
              <p class="font-mono text-lg text-success">{@seat["pc_asset_code"]}</p>
            </div>
            <div class="rounded-lg border border-base-300 bg-base-200 p-3">
              <p class="text-tiny uppercase text-base-content/60 mb-1">
                Nom d'hôte / Hostname
              </p>
              <p class="font-mono text-lg text-info truncate">{@seat["pc_hostname"]}</p>
            </div>
          </div>

          <%= if @seat["reservation_end_date"] do %>
            <div class="rounded-lg border border-warning/50 bg-warning/10 p-3">
              <p class="text-sm text-warning">
                <span class="font-semibold">Réservé jusqu'à:</span> {format_iso_datetime(@seat["reservation_end_date"])}
                <span class="font-semibold">Reserved until:</span> {format_iso_datetime(@seat["reservation_end_date"])}
              </p>
            </div>
          <% else %>
            <%= if @seat["status"] == "available" do %>
              <div class="rounded-lg border border-success/30 bg-success/10 p-3">
                <p class="text-sm text-success">
                  <span class="font-semibold">Ce poste est disponible.</span>
                  <span class="font-semibold">This seat is available for use.</span>
                </p>
              </div>
            <% end %>
          <% end %>

          <%= if @actions != [] do %>
            <div class="mt-4 flex justify-end gap-2">
              {render_slot(@actions)}
            </div>
          <% end %>
        </div>
      </.focus_wrap>
      <div class="modal-backdrop" phx-click={@on_close}></div>
    </dialog>
    """
  end

  defp status_classes(:available), do: "border-success bg-success/10 text-success"
  defp status_classes(:occupied), do: "border-warning bg-warning/10 text-warning"
  defp status_classes(:reserved), do: "border-base-400 bg-base-300/50 text-base-content/70"
  defp status_classes(:unavailable), do: "border-error bg-error/10 text-error"
  defp status_classes(:tournament), do: "border-info bg-info/10 text-info"
  defp status_classes(_), do: "border-base-300 bg-base-200 text-base-content/60"

  defp status_text(:available), do: "Disponible"
  defp status_text(:occupied), do: "Occupé"
  defp status_text(:reserved), do: "Réservé"
  defp status_text(:unavailable), do: "Hors service"
  defp status_text(:tournament), do: "Tournoi"
  # defp status_text(:available), do: "Available"
  # defp status_text(:occupied), do: "Occupied"
  # defp status_text(:reserved), do: "Reserved"
  # defp status_text(:unavailable), do: "Offline"
  # defp status_text(:tournament), do: "Tournament"
  defp status_text(status) when is_binary(status), do: String.capitalize(status)
  defp status_text(_), do: "Unknown"

  defp format_iso_datetime(iso_value) do
    case DateTime.from_iso8601(iso_value) do
      {:ok, datetime, _offset} -> Calendar.strftime(datetime, "%H:%M")
      _ -> iso_value
    end
  end
end
