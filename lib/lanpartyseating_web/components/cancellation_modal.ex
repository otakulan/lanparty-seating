defmodule CancellationModalComponent do
  use Phoenix.Component

  attr(:error, :string, required: false)
  attr(:station, :any, required: true)
  attr(:status, :any, required: true)
  attr(:reservation, :any, required: true)

  def modal(assigns) do
    case assigns.status do
      :available ->
        ~H"""
        <div x-data class="h-full">
          <label
            class="btn btn-success rounded-lg station-card station-available w-full h-full"
            x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}
          >
            {@station.station_number}
          </label>

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
          assign(
            assigns,
            :end_date_iso,
            List.first(assigns.station.reservations).end_date
            |> DateTime.to_iso8601()
          )

        ~H"""
        <div x-data class="h-full">
          <label
            class="btn btn-warning rounded-lg station-card flex flex-col h-full py-1 w-full"
            x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}
            x-data={"{ endTime: new Date('#{@end_date_iso}'), remaining: '' }"}
            x-init="
              const update = () => {
                const now = new Date();
                const diff = Math.max(0, endTime - now);
                const mins = Math.floor(diff / 60000);
                const secs = Math.floor((diff % 60000) / 1000);
                remaining = mins + ':' + secs.toString().padStart(2, '0');
              };
              update();
              setInterval(update, 1000);
            "
          >
            <div class="font-bold">{@station.station_number}</div>
            <div class="text-xs" x-text="remaining"></div>
          </label>

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
                <div
                  class="flex justify-between items-center mt-2"
                  x-data={"{ endTime: new Date('#{@end_date_iso}'), remaining: '' }"}
                  x-init="
                    const update = () => {
                      const now = new Date();
                      const diff = Math.max(0, endTime - now);
                      const mins = Math.floor(diff / 60000);
                      const secs = Math.floor((diff % 60000) / 1000);
                      remaining = mins + ':' + secs.toString().padStart(2, '0');
                    };
                    update();
                    setInterval(update, 1000);
                  "
                >
                  <span class="text-base-content/70">Time remaining:</span>
                  <span class="font-mono font-bold text-lg" x-text="remaining"></span>
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
          <label
            class="btn btn-error rounded-lg station-card w-full h-full"
            x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}
          >
            {@station.station_number}
          </label>

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
        <div x-data class="h-full">
          <label class="btn btn-neutral rounded-lg station-card w-full h-full">
            {@station.station_number}
          </label>
        </div>
        """
    end
  end
end
