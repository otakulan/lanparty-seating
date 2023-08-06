defmodule ModalComponent do
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
          <!-- The button to open modal -->
          <label for={"station-modal-#{@station.station_number}"} class="btn btn-info"><%= @station.station_number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"station-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected station <%= @station.station_number %></h3>
              <p class="py-4">Select the duration of the reservation</p>

              <form phx-submit="reserve_station">
                <input type="hidden" name="station_number" value={"#{@station.station_number}"}>
                <input type="number" placeholder="Reservation duration" min="1" max="60" class="w-16 max-w-xs input input-bordered input-xs" name="duration" value="45"/> minutes
                <%= if !is_nil(@error) do %>
                  <p class="text-error"><%= @error %></p>
                <% end %>
                <%!-- <p>@error</p> --%>
                <br/><br/>
                <input type="text" placeholder="Badge number" class="w-full max-w-xs input input-bordered" name="badge_number" autofocus/>

                <div class="modal-action">
                  <label for={"station-modal-#{@station.station_number}"} class="btn btn-error">Close</label>
                  <button for={"station-modal-#{@station.station_number}"} class="btn btn-success" type="submit">Confirm reservation</button>
                </div>
              </form>
            </div>
          </div>
        """

      :occupied ->
        ~H"""
          <!-- The button to open modal -->
        <label for={"station-modal-#{@station.station_number}"} class="btn btn-warning flex flex-col" >
          <div >
            <%= @station.station_number %>
          </div>
          Until <%= Calendar.strftime(
            List.first(@station.reservations).end_date |> Timex.to_datetime("America/Montreal"),
                "%H:%M"
              ) %>
        </label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"station-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected station <%= @station.station_number %></h3>
              <p class="py-4">Occupied by badge <b>#<%= @reservation.badge %></b> *REPLACE WITH NAME*</p>
              <p>The reservation will end at
              <b><%= Calendar.strftime(
                @reservation.end_date |> Timex.to_datetime("America/Montreal"),
                "%H:%M"
              ) %> *REPLACE WITH COUNTDOWN*</b>
              </p>
              <p class="py-4">Enter a reason for canceling the reservation</p>

              <form phx-submit="cancel_station">
                <input type="hidden" name="station_id" value={"#{@station.id}"}>
                <input type="hidden" name="station_number" value={"#{@station.station_number}"}>
                <input type="text" placeholder="Reason" value="Leaving early" class="w-full max-w-xs input input-bordered" name="cancel_reason"/>

                <div class="modal-action">
                  <label for={"station-modal-#{@station.station_number}"} class="btn btn-error">Close</label>
                  <button for={"station-modal-#{@station.station_number}"} class="btn btn-success" type="submit" onclick={"document.getElementById('station-modal-#{@station.station_number}').checked=false"}>Confirm cancelation</button>
                </div>
              </form>
            </div>
          </div>
        """

      :broken ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"station-modal-#{@station.station_number}"} class="btn btn-error"><%= @station.station_number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"station-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected station <%= @station.station_number %></h3>
              <p class="py-4">This computer is broken and cannot be reserved</p>

              <div class="modal-action">
                <label for={"station-modal-#{@station.station_number}"} class="btn btn-error">Close</label>
              </div>
            </div>
          </div>
        """

      :reserved ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"station-modal-#{@station.station_number}"} class="btn btn-active"><%= @station.station_number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"station-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected station <%= @station.station_number %></h3>
              <p class="py-4">This computer is reserved for a tournament and may not be used for another purpose until the tournament is finished</p>

              <div class="modal-action">
                <label for={"station-modal-#{@station.station_number}"} class="btn btn-error">Close</label>
              </div>
            </div>
          </div>
        """
    end
  end
end
