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
          <div class="flex flex-col h-14 flex-1 grow mx-1 " x-data>
            <!-- The button to open modal -->
            <label
              class="btn btn-info"
              x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}>
              <%= @station.station_number %>
            </label>

            <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
              <div class="modal-box">
                <h3 class="text-lg font-bold">You have selected station <%= @station.station_number %></h3>
                <p class="py-4">Do you want to close this station?</p>
                <form method="dialog">
                  <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
                </form>
                <form phx-submit="close_station">
                  <input type="hidden" name="station_number" value={"#{@station.station_number}"}>

                  <%= if !is_nil(@error) do %>
                    <p class="text-error"><%= @error %></p>
                  <% end %>
                  <br/><br/>

                  <div class="modal-action">
                    <button
                      class="btn btn-success"
                      x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                      type="submit">
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
          <div class="flex flex-col h-14 flex-1 grow mx-1 " x-data>
            <!-- The button to open modal -->
            <label
              class="btn btn-warning flex flex-col"
              x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}>
              <div >
                <%= @station.station_number %>
              </div>
              Until <%= Calendar.strftime(
                List.first(@station.reservations).end_date |> Timex.to_datetime("America/Montreal"),
                    "%H:%M"
                  ) %>
            </label>

            <!-- Put this part before </body> tag -->
            <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
              <div class="modal-box">
                <h3 class="text-lg font-bold">You have selected station <%= @station.station_number %></h3>
                <p class="py-4">Occupied by badge <b>#<%= @reservation.badge %></b> *REPLACE WITH NAME*</p>
                <p>The reservation will end at
                <b><%= Calendar.strftime(
                  @reservation.end_date |> Timex.to_datetime("America/Montreal"),
                  "%H:%M"
                ) %> *REPLACE WITH COUNTDOWN*</b>
                </p>
                <form method="dialog">
                  <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
                </form>

                <p class="py-4">Enter an amount of minutes to extend the reservation by</p>

                <form phx-submit="extend_reservation">
                  <input type="hidden" name="station_id" value={"#{@station.station_number}"}>
                  <input type="hidden" name="station_number" value={"#{@station.station_number}"}>
                  <input type="text" placeholder="Minutes to add" value="5" class="w-full max-w-xs input input-bordered" name="minutes_increment"/>

                  <div class="modal-action">
                    <button
                      class="btn btn-success"
                      x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                      type="submit">
                      Add time to reservation
                    </button>
                  </div>
                </form>

                <p class="py-4">Enter a reason for canceling the reservation</p>

                <form phx-submit="cancel_station">
                  <input type="hidden" name="station_id" value={"#{@station.station_number}"}>
                  <input type="hidden" name="station_number" value={"#{@station.station_number}"}>
                  <input type="text" placeholder="Reason" value="Leaving early" class="w-full max-w-xs input input-bordered" name="cancel_reason"/>

                  <div class="modal-action">
                    <button
                      class="btn btn-success"
                      x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                      type="submit">
                      Confirm cancellation
                    </button>
                  </div>
                </form>
              </div>
            </dialog>
          </div>
        """

      :broken ->
        ~H"""
          <div class="flex flex-col h-14 flex-1 grow mx-1 " x-data>
            <!-- The button to open modal -->
            <label
              class="btn btn-error"
              x-on:click={"$refs.station_modal_#{@station.station_number}.showModal()"}>
              <%= @station.station_number %>
            </label>

            <dialog class="modal" x-ref={"station_modal_#{@station.station_number}"}>
              <div class="modal-box">
                <h3 class="text-lg font-bold">You have selected station <%= @station.station_number %></h3>
                <p class="py-4">Do you want to open this station?</p>
                <form method="dialog">
                  <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
                </form>
                <form phx-submit="open_station">
                  <input type="hidden" name="station_number" value={"#{@station.station_number}"}>

                  <%= if !is_nil(@error) do %>
                    <p class="text-error"><%= @error %></p>
                  <% end %>
                  <br/><br/>

                  <div class="modal-action">
                    <button
                      class="btn btn-success"
                      x-on:click={"$refs.station_modal_#{@station.station_number}.close()"}
                      type="submit">
                      ✓
                    </button>
                  </div>
                </form>
              </div>
            </dialog>
          </div>
        """

      :reserved ->
        ~H"""
          <div class="flex flex-col h-14 flex-1 grow mx-1 " x-data>
            <!-- The button to open modal -->
            <label
              class="btn btn-active">
              <%= @station.station_number %>
            </label>
          </div>
        """
    end
  end
end
