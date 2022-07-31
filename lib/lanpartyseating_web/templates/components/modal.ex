defmodule ModalComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

  def modal(assigns) do
    # status:
    # 1 - libre / free  (blue: btn-info)
    # 2 - occupé ou réservé / occupied or reserved  (yellow: btn-warning)
    # 3 - brisé / broken  (red: btn-error)
    # 4 - réserver pour un tournois / reserved for a tournament  (black: btn-active)

    cond do
      assigns.status == "1" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-info"><%= assigns.number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{assigns.number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="font-bold text-lg">You have selected seat <%= assigns.number %></h3>
              <p class="py-4">Select the duration of the reservation</p>

              <form phx-submit="reserve_seat">
                <input type="hidden" name="seat_number" value={"#{assigns.number}"}>
                <input type="number" placeholder="Reservation duration" min="15" max="60" class="w-16 max-w-xs input input-bordered input-xs" name="duration" value="45"/> minutes
                <br/><br/>
                <input type="text" placeholder="Badge number" class="input input-bordered w-full max-w-xs" name="badge_number"/>

                <div class="modal-action">
                  <label for={"seat-modal-#{assigns.number}"} class="btn">Close</label>
                  <button for={"seat-modal-#{assigns.number}"} class="btn" type="submit" onclick={"document.getElementById('seat-modal-#{assigns.number}').checked=false"}>Confirm reservation</button>
                </div>
              </form>
            </div>
          </div>
        """
      assigns.status == "2" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-warning"><%= assigns.number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{assigns.number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="font-bold text-lg">You have selected seat <%= assigns.number %></h3>
              <p class="py-4">Enter a reason for canceling the reservation</p>

              <form phx-submit="cancel_seat">
                <input type="hidden" name="seat_number" value={"#{assigns.number}"}>
                <input type="text" placeholder="Reason" class="input input-bordered w-full max-w-xs" name="cancel_reason"/>

                <div class="modal-action">
                  <label for={"seat-modal-#{assigns.number}"} class="btn">Close</label>
                  <button for={"seat-modal-#{assigns.number}"} class="btn" type="submit" onclick={"document.getElementById('seat-modal-#{assigns.number}').checked=false"}>Confirm cancelation</button>
                </div>
              </form>
            </div>
          </div>
        """
      assigns.status == "3" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-error"><%= assigns.number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{assigns.number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="font-bold text-lg">You have selected seat <%= assigns.number %></h3>
              <p class="py-4">This computer is broken and cannot be reserved</p>

              <div class="modal-action">
                <label for={"seat-modal-#{assigns.number}"} class="btn">Close</label>
              </div>
            </div>
          </div>
        """
      assigns.status == "4" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-active"><%= assigns.number %></label>

          <!-- Put this part before </body> tag -->
          <input type="checkbox" id={"seat-modal-#{assigns.number}"} class="modal-toggle" />
          <div class="modal modal-bottom sm:modal-middle">
            <div class="modal-box">

              <h3 class="font-bold text-lg">You have selected seat <%= assigns.number %></h3>
              <p class="py-4">This computer is reserved for a tournament and may not be used for another purpose until the tournament is finished</p>

              <div class="modal-action">
                <label for={"seat-modal-#{assigns.number}"} class="btn">Close</label>
              </div>
            </div>
          </div>
        """
    end
  end
end
