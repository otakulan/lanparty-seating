defmodule CancellationModalComponent do
  use Phoenix.Component
  import LanpartyseatingWeb.Components.UI, only: [countdown: 1, station_button: 1]

  attr(:error, :string, required: false)
  attr(:station, :any, required: true)
  attr(:status, :any, required: true)
  attr(:reservation, :any, required: true)

  def modal(assigns) do
    case assigns.status do
      :available ->
        ~H"""
        <div x-data class="h-full">
          <.station_button
            status={:available}
            station_number={@station.station_number}
            on_click={"$refs.station_modal_#{@station.station_number}.showModal()"}
            class="w-full"
          />

          <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
            <div class="modal-box">
              <form method="dialog">
                <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
              </form>
              <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>
              <p class="text-base-content/80">Do you want to mark this station as broken/closed?</p>

              <%= if !is_nil(@error) do %>
                <div class="alert alert-error mt-4">
                  <span>{@error}</span>
                </div>
              <% end %>

              <form phx-submit="close_station" class="mt-6">
                <input type="hidden" name="station_number" value={"#{@station.station_number}"} />
                <div class="modal-action">
                  <button
                    class="btn btn-error"
                    x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                    type="submit"
                  >
                    Mark as Broken
                  </button>
                </div>
              </form>
            </div>
          </dialog>
        </div>
        """

      :occupied ->
        assigns =
          assign(assigns, :end_date, List.first(assigns.station.reservations).end_date)

        ~H"""
        <div x-data class="h-full">
          <.station_button
            status={:occupied}
            station_number={@station.station_number}
            end_date={@end_date}
            on_click={"$refs.station_modal_#{@station.station_number}.showModal()"}
            class="w-full"
          />

          <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
            <div class="modal-box">
              <form method="dialog">
                <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
              </form>
              <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>

              <div class="bg-base-200 p-4 rounded-lg mb-4">
                <div class="flex justify-between items-center">
                  <span class="text-base-content/70">Badge:</span>
                  <span class="font-bold">{@reservation.badge}</span>
                </div>
                <div class="flex justify-between items-center mt-2">
                  <span class="text-base-content/70">Time remaining:</span>
                  <.countdown end_date={@end_date} class="font-mono font-bold text-lg" />
                </div>
              </div>

              <div class="divider">Extend Reservation</div>

              <form phx-submit="extend_reservation">
                <input type="hidden" name="station_number" value={"#{@station.station_number}"} />
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Minutes to add</span>
                  </label>
                  <input
                    type="number"
                    value="5"
                    min="1"
                    class="input input-bordered w-full"
                    name="minutes_increment"
                  />
                </div>
                <div class="modal-action">
                  <button
                    class="btn btn-success"
                    x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                    type="submit"
                  >
                    Extend Time
                  </button>
                </div>
              </form>

              <div class="divider">Cancel Reservation</div>

              <form phx-submit="cancel_station">
                <input type="hidden" name="station_number" value={"#{@station.station_number}"} />
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Reason for cancellation</span>
                  </label>
                  <input
                    type="text"
                    placeholder="Reason"
                    value="Leaving early"
                    class="input input-bordered w-full"
                    name="cancel_reason"
                  />
                </div>
                <div class="modal-action">
                  <button
                    class="btn btn-error"
                    x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                    type="submit"
                  >
                    Cancel Reservation
                  </button>
                </div>
              </form>
            </div>
          </dialog>
        </div>
        """

      :broken ->
        ~H"""
        <div x-data class="h-full">
          <.station_button
            status={:broken}
            station_number={@station.station_number}
            on_click={"$refs.station_modal_#{@station.station_number}.showModal()"}
            class="w-full"
          />

          <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
            <div class="modal-box">
              <form method="dialog">
                <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
              </form>
              <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>
              <p class="text-base-content/80">This station is currently marked as broken. Do you want to re-open it?</p>

              <%= if !is_nil(@error) do %>
                <div class="alert alert-error mt-4">
                  <span>{@error}</span>
                </div>
              <% end %>

              <form phx-submit="open_station" class="mt-6">
                <input type="hidden" name="station_number" value={"#{@station.station_number}"} />
                <div class="modal-action">
                  <button
                    class="btn btn-success"
                    x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                    type="submit"
                  >
                    Re-open Station
                  </button>
                </div>
              </form>
            </div>
          </dialog>
        </div>
        """

      :reserved ->
        ~H"""
        <div class="h-full">
          <.station_button status={:reserved} station_number={@station.station_number} class="w-full" />
        </div>
        """
    end
  end
end
