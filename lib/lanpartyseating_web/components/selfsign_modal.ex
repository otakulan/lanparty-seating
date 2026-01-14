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
    # 1 - libre / available  (blue: btn-info)
    # 2 - occupé / occupied (yellow: btn-warning)
    # 3 - brisé / broken  (red: btn-error)
    # 4 - réserver pour un tournois / reserved for a tournament  (black: btn-active)
    case assigns.status do
      :available ->
        ~H"""
        <div class="flex flex-col h-14 flex-1 grow mx-1" x-data>
          <!-- The button to open modal -->
          <label
            x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}
            class="btn btn-info"
          >
            {@station.station_number}
          </label>
          <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
            <div class="modal-box">
              <h3 class="text-lg font-bold">Station #{@station.station_number}</h3>
              <p>Once your badge is scanned, a 45 min session will start at the chosen station</p>
              <br />
              <p>Une fois votre badge scanné, une session de 45 min commencera à la station choisie</p>
              <form method="dialog">
                <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
              </form>
              <form phx-submit="reserve_station">
                <input type="hidden" name="station_number" value={"#{@station.station_number}"} />

                <%= if !is_nil(@error) do %>
                  <p class="text-error">{@error}</p>
                <% end %>
                <%!-- <p>@error</p> --%>
                <br /><br />
                <input
                  type="text"
                  placeholder="Badge number / Numéro de badge"
                  class="w-full max-w-xs input"
                  name="uid"
                  autocomplete="off"
                  autofocus
                />

                <div class="modal-action">
                  <button class="btn btn-success" type="submit">
                    ✓
                  </button>
                </div>
              </form>
            </div>
          </dialog>
        </div>
        """

      :occupied ->
        ~H"""
        <div class="flex flex-col h-14 flex-1 grow mx-1" x-data>
          <!-- The button to open modal -->
          <div
            class="btn btn-warning flex flex-col"
            x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}
          >
            <div>
              {@station.station_number}
            </div>
            Until {Calendar.strftime(
              List.first(@station.reservations).end_date |> Timex.to_datetime("America/Montreal"),
              "%H:%M"
            )}
          </div>
        </div>
        """

      :broken ->
        ~H"""
        <div class="flex flex-col h-14 flex-1 grow mx-1" x-data>
          <!-- The button to open modal -->
          <label class="btn btn-error">
            {@station.station_number}
          </label>
        </div>
        """

      :reserved ->
        ~H"""
        <div class="flex flex-col h-14 flex-1 grow mx-1" x-data>
          <!-- The button to open modal -->
          <label
            class="btn btn-active"
            x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}
          >
            {@station.station_number}
          </label>
        </div>
        """
    end
  end
end
