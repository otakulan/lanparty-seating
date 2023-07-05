defmodule ModalComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

  attr :station, :any, required: true
  attr :status, :any, required: true
  attr :reservation, :any, required: true

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
          <label for={"seat-modal-#{@station.station_number}"} class="btn btn-info"><%= @station.station_number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected seat <%= @station.station_number %></h3>
              <p class="py-4">Select the duration of the reservation</p>

              <form phx-submit="reserve_seat">
                <input type="hidden" name="seat_number" value={"#{@station.station_number}"}>
                <input type="number" placeholder="Reservation duration" min="15" max="60" class="w-16 max-w-xs input input-bordered input-xs" name="duration" value="45"/> minutes
                <br/><br/>
                <input type="text" placeholder="Badge number" class="w-full max-w-xs input input-bordered" name="badge_number"/>

                <div class="modal-action">
                  <label for={"seat-modal-#{@station.station_number}"} class="btn">Close</label>
                  <button for={"seat-modal-#{@station.station_number}"} class="btn" type="submit">Confirm reservation</button>
                </div>
              </form>
            </div>
          </div>
        """
      :occupied ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{@station.station_number}"} class="btn btn-warning"><%= @station.station_number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected seat <%= @station.station_number %></h3>
              <p class="py-4">This Place is currently occupied by Badge #<%= @reservation.badge %></p>
              <p class="py-4">Enter a reason for canceling the reservation</p>

              <form phx-submit="cancel_seat">
                <input type="hidden" name="station_id" value={"#{@station.id}"}>
                <input type="hidden" name="station_number" value={"#{@station.station_number}"}>
                <input type="text" placeholder="Reason" class="w-full max-w-xs input input-bordered" name="cancel_reason"/>

                <div class="modal-action">
                  <label for={"seat-modal-#{@station.station_number}"} class="btn">Close</label>
                  <button for={"seat-modal-#{@station.station_number}"} class="btn" type="submit" onclick={"document.getElementById('seat-modal-#{@station.station_number}').checked=false"}>Confirm cancelation</button>
                </div>
              </form>
            </div>
          </div>
        """
      :broken ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{@station.station_number}"} class="btn btn-error"><%= @station.station_number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected seat <%= @station.station_number %></h3>
              <p class="py-4">This computer is broken and cannot be reserved</p>

              <div class="modal-action">
                <label for={"seat-modal-#{@station.station_number}"} class="btn">Close</label>
              </div>
            </div>
          </div>
        """
      :reserved ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{@station.station_number}"} class="btn btn-active"><%= @station.station_number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{@station.station_number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="text-lg font-bold">You have selected seat <%= @station.station_number %></h3>
              <p class="py-4">This computer is reserved for a tournament and may not be used for another purpose until the tournament is finished</p>

              <div class="modal-action">
                <label for={"seat-modal-#{@station.station_number}"} class="btn">Close</label>
              </div>
            </div>
          </div>
        """
    end
  end
end
