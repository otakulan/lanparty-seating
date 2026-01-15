defmodule SelfSignModalComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

  attr(:error, :string, required: false)
  attr(:station, :any, required: true)
  attr(:status, :any, required: true)
  attr(:reservation, :any, required: true)

  def modal(assigns) do
    # status:
    # 1 - libre / available  (green: btn-success)
    # 2 - occupé / occupied (amber: btn-warning)
    # 3 - brisé / broken  (red: btn-error)
    # 4 - réserver pour un tournois / reserved for a tournament  (dark: btn-neutral)
    case assigns.status do
      :available ->
        ~H"""
        <div x-data class="h-full">
          <label
            x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}
            class="btn btn-success rounded-lg station-card station-available w-full h-full"
          >
            {@station.station_number}
          </label>
          <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
            <div class="modal-box">
              <form method="dialog">
                <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
              </form>
              <h3 class="text-xl font-bold mb-4">Station {@station.station_number}</h3>
              <div class="space-y-2 text-base-content/80">
                <p>Once your badge is scanned, a 45 min session will start at the chosen station</p>
                <p class="text-sm">Une fois votre badge scanné, une session de 45 min commencera à la station choisie</p>
              </div>
              <form phx-submit="reserve_station" class="mt-6">
                <input type="hidden" name="station_number" value={"#{@station.station_number}"} />

                <%= if !is_nil(@error) do %>
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
                    autofocus
                  />
                </div>

                <div class="modal-action">
                  <button class="btn btn-success" type="submit">
                    Reserve / Réserver
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
          <div
            class="btn btn-warning rounded-lg station-card flex flex-col h-full py-1 w-full"
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
          </div>
        </div>
        """

      :broken ->
        ~H"""
        <div x-data class="h-full">
          <label class="btn btn-error rounded-lg station-card w-full h-full">
            {@station.station_number}
          </label>
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
