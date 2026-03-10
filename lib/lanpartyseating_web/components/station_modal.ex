defmodule LanpartyseatingWeb.Components.StationModal do
  @moduledoc """
  Station modal components for the stations page.

  This module provides:
  - `station_button/1` - The clickable station button that emits a phx-click event
  - `modal_content/1` - The modal content based on station status (no dialog wrapper)

  The dialog wrapper is provided by the parent LiveView (stations_live.ex) as a
  single shared modal, which is controlled via LiveView assigns for proper
  integration with Phoenix LiveView's lifecycle.
  """
  use Phoenix.Component
  import LanpartyseatingWeb.Components.UI, only: [countdown: 1]
  alias LanpartyseatingWeb.Components.Icons

  # ============================================================================
  # Station Button Component
  # ============================================================================

  @doc """
  Renders a clickable station button that emits a phx-click event to open the modal.

  The button styling changes based on the station status (available, occupied, broken, reserved).
  For occupied stations, it displays a countdown timer.

  ## Examples

      <.station_button
        station={station}
        status={:available}
        reservation={nil}
      />

  """
  attr :station, :any, required: true
  attr :status, :atom, required: true, values: [:available, :occupied, :broken, :reserved]
  attr :reservation, :any, default: nil

  def station_button(assigns) do
    base_classes = "btn rounded-lg station-card h-full w-full"

    status_classes =
      case assigns.status do
        :available -> "btn-success station-available"
        :occupied -> "btn-warning flex flex-col justify-center gap-0"
        :broken -> "btn-error"
        :reserved -> "btn-neutral"
      end

    end_date =
      if assigns.status == :occupied and assigns.reservation do
        assigns.reservation.end_date
      else
        nil
      end

    assigns =
      assigns
      |> assign(:base_classes, base_classes)
      |> assign(:status_classes, status_classes)
      |> assign(:end_date, end_date)
      |> assign(
        :end_date_iso,
        if(end_date, do: DateTime.to_iso8601(end_date), else: nil)
      )
      |> assign(
        :end_date_unix,
        if(end_date, do: DateTime.to_unix(end_date), else: nil)
      )

    ~H"""
    <button
      type="button"
      class={[@base_classes, @status_classes]}
      phx-click="open_station_modal"
      phx-value-station={@station.station_number}
    >
      <%= if @status == :occupied do %>
        <div class="font-bold">{@station.station_number}</div>
        <div
          id={"station-countdown-#{@station.station_number}-#{@end_date_unix}"}
          class="text-xs"
          x-data={"{ endTime: new Date('#{@end_date_iso}'), remaining: '', intervalId: null }"}
          x-init="
            const update = () => {
              const now = new Date();
              const diff = Math.max(0, endTime - now);
              const mins = Math.floor(diff / 60000);
              const secs = Math.floor((diff % 60000) / 1000);
              if (mins > 0) {
                remaining = mins + 'm' + secs + 's';
              } else {
                remaining = secs + 's';
              }
            };
            update();
            intervalId = setInterval(update, 1000);
          "
          @destroy="clearInterval(intervalId)"
          x-text="remaining"
        >
        </div>
      <% else %>
        {@station.station_number}
      <% end %>
    </button>
    """
  end

  # ============================================================================
  # Modal Content Component
  # ============================================================================

  @doc """
  Renders the modal content based on station status.

  This component does NOT include the `<dialog>` wrapper - that is provided by
  the parent LiveView as a single shared modal. This content is rendered inside
  the shared modal's `modal-box`.

  ## Examples

      <.modal_content
        station={@selected_station.station}
        status={@selected_station.status}
        reservation={@selected_station.reservation}
        error={@registration_error}
        is_admin={true}
      />

  """
  attr :station, :any, required: true
  attr :status, :atom, required: true
  attr :reservation, :any, default: nil
  attr :error, :string, default: nil
  attr :is_admin, :boolean, default: false
  attr :reservation_minutes, :integer, default: 45
  attr :duplicate_warning, :any, default: nil

  def modal_content(assigns) do
    case assigns.status do
      :available -> available_content(assigns)
      :occupied -> occupied_content(assigns)
      :broken -> broken_content(assigns)
      :reserved -> reserved_content(assigns)
    end
  end

  # ============================================================================
  # Available Station Content
  # ============================================================================

  defp available_content(assigns) do
    ~H"""
    <div x-data={"{ adminOpen: #{@is_admin} }"}>
      <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>

      <%= if @duplicate_warning do %>
        <%!-- Duplicate reservation warning --%>
        <div class="alert alert-warning mb-4">
          <Icons.exclamation_triangle class="shrink-0 h-6 w-6" />
          <div>
            <p class="font-bold">
              This badge already has an active reservation at station {@duplicate_warning.station_number}!
            </p>
            <p class="text-sm">
              Are you sure you want to create another reservation?
            </p>
            <p class="font-bold mt-2">
              Ce badge a déjà une réservation active à la station {@duplicate_warning.station_number}!
            </p>
            <p class="text-sm">
              Êtes-vous sûr de vouloir créer une autre réservation?
            </p>
          </div>
        </div>

        <form phx-submit="confirm_reserve_station">
          <input type="hidden" name="station_number" value={@duplicate_warning.target_station} />
          <input type="hidden" name="uid" value={@duplicate_warning.badge_uid} />

          <div class="modal-action">
            <button type="button" class="btn btn-ghost" phx-click="close_station_modal">
              Cancel / Annuler
            </button>
            <button class="btn btn-warning" type="submit">
              Reserve Anyway / Réserver quand même
            </button>
          </div>
        </form>
      <% else %>
        <%!-- Self-service reservation section --%>
        <div class="space-y-2 text-base-content/80">
          <p>Once your badge is scanned, a {@reservation_minutes} min session will start at the chosen station.</p>
          <p class="text-sm">Une fois votre badge scanné, une session de {@reservation_minutes} min commencera à la station choisie.</p>
        </div>

        <form phx-submit="reserve_station" class="mt-6">
          <input type="hidden" name="station_number" value={@station.station_number} />

          <%= if @error do %>
            <div class="alert alert-error mb-4">
              <span>{@error}</span>
            </div>
          <% end %>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Badge number / Numéro de badge</span>
            </label>
            <input
              type="text"
              placeholder="Enter badge number..."
              class="input input-bordered w-full"
              name="uid"
              autocomplete="off"
              id={"station-badge-input-#{@station.station_number}"}
              phx-hook="AutoFocus"
            />
          </div>

          <div class="modal-action">
            <button type="button" class="btn btn-ghost" phx-click="close_station_modal">
              Cancel / Annuler
            </button>
            <button class="btn btn-success" type="submit">
              Reserve / Réserver
            </button>
          </div>
        </form>
      <% end %>

      <%!-- Admin actions collapsible section --%>
      <div class="divider"></div>

      <div class="collapse collapse-arrow bg-base-200 rounded-lg">
        <input type="checkbox" x-model="adminOpen" />
        <div class="collapse-title font-medium">
          Admin Actions / Actions admin
        </div>
        <div class="collapse-content">
          <form phx-submit="close_station">
            <input type="hidden" name="station_number" value={@station.station_number} />
            <div class="pt-2">
              <button class="btn btn-error btn-sm w-full" type="submit">
                Mark as Broken / Marquer brisée
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Occupied Station Content
  # ============================================================================

  defp occupied_content(assigns) do
    assigns = assign(assigns, :end_date, assigns.reservation.end_date)

    ~H"""
    <div x-data={"{ adminOpen: #{@is_admin} }"}>
      <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>

      <%!-- Station info --%>
      <div class="bg-base-200 p-4 rounded-lg mb-4">
        <div class="flex justify-between items-center">
          <span class="text-base-content/70">Badge:</span>
          <span class="font-bold">{@reservation.badge}</span>
        </div>
        <div class="flex justify-between items-center mt-2">
          <span class="text-base-content/70">Time remaining / Temps restant:</span>
          <.countdown end_date={@end_date} class="font-mono font-bold text-lg" />
        </div>
      </div>

      <%!-- Admin actions collapsible section --%>
      <div class="collapse collapse-arrow bg-base-200 rounded-lg">
        <input type="checkbox" x-model="adminOpen" />
        <div class="collapse-title font-medium">
          Admin Actions / Actions admin
        </div>
        <div class="collapse-content">
          <%!-- Extend reservation --%>
          <div class="pt-2">
            <div class="text-sm font-semibold mb-2 text-base-content/70">
              Extend / Prolonger
            </div>
            <form phx-submit="extend_reservation" class="flex gap-2 items-end">
              <input type="hidden" name="station_number" value={@station.station_number} />
              <div class="form-control flex-1">
                <label class="label py-1">
                  <span class="label-text text-xs">Minutes to add / Minutes à ajouter</span>
                </label>
                <input
                  type="number"
                  value="5"
                  min="1"
                  class="input input-bordered input-sm w-full"
                  name="minutes_increment"
                />
              </div>
              <button class="btn btn-success btn-sm" type="submit">
                Extend / Prolonger
              </button>
            </form>
          </div>

          <div class="divider my-2"></div>

          <%!-- Cancel reservation --%>
          <div>
            <div class="text-sm font-semibold mb-2 text-base-content/70">
              Cancel / Annuler
            </div>
            <form phx-submit="cancel_station" class="flex gap-2 items-end">
              <input type="hidden" name="station_number" value={@station.station_number} />
              <div class="form-control flex-1">
                <label class="label py-1">
                  <span class="label-text text-xs">Reason / Raison</span>
                </label>
                <input
                  type="text"
                  placeholder="Leaving early / Départ anticipé"
                  value="Leaving early"
                  class="input input-bordered input-sm w-full"
                  name="cancel_reason"
                />
              </div>
              <button class="btn btn-error btn-sm" type="submit">
                Cancel / Annuler
              </button>
            </form>
          </div>
        </div>
      </div>

      <div class="modal-action">
        <button type="button" class="btn btn-ghost" phx-click="close_station_modal">
          Close / Fermer
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Broken Station Content
  # ============================================================================

  defp broken_content(assigns) do
    ~H"""
    <div x-data={"{ adminOpen: #{@is_admin} }"}>
      <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>

      <p class="text-base-content/80">
        This station is currently marked as broken.
      </p>
      <p class="text-base-content/80 text-sm mt-1">
        Cette station est actuellement marquée comme brisée.
      </p>

      <%!-- Admin actions collapsible section --%>
      <div class="divider"></div>

      <div class="collapse collapse-arrow bg-base-200 rounded-lg">
        <input type="checkbox" x-model="adminOpen" />
        <div class="collapse-title font-medium">
          Admin Actions / Actions admin
        </div>
        <div class="collapse-content">
          <form phx-submit="open_station">
            <input type="hidden" name="station_number" value={@station.station_number} />
            <div class="pt-2">
              <button class="btn btn-success btn-sm w-full" type="submit">
                Re-open Station / Rouvrir la station
              </button>
            </div>
          </form>
        </div>
      </div>

      <div class="modal-action">
        <button type="button" class="btn btn-ghost" phx-click="close_station_modal">
          Close / Fermer
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Reserved (Tournament) Station Content
  # ============================================================================

  defp reserved_content(assigns) do
    ~H"""
    <div>
      <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>

      <p class="text-base-content/80">
        This station is reserved for a tournament.
      </p>
      <p class="text-base-content/80 text-sm mt-1">
        Cette station est réservée pour un tournoi.
      </p>

      <div class="modal-action">
        <button type="button" class="btn btn-ghost" phx-click="close_station_modal">
          Close / Fermer
        </button>
      </div>
    </div>
    """
  end
end
