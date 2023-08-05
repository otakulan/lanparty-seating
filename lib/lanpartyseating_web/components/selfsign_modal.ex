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
        <!-- The button to open modal -->
        <label for={"seat-modal-#{@station.station_number}"} class="btn btn-info">
          <%= @station.station_number %>
        </label>
        <!-- Put this part before </body> tag -->
        <input type="checkbox" id={"seat-modal-#{@station.station_number}"} class="modal-toggle" />
        <div class="modal modal-bottom sm:modal-middle">
          <div class="modal-box">
            <h3 class="text-lg font-bold">Station #<%= @station.station_number %></h3>
            <p>Once you badge is scanned, a 45min session will start at the chosen computer</p>

            <form phx-submit="reserve_seat">
              <input type="hidden" name="seat_number" value={"#{@station.station_number}"} />

              <%= if !is_nil(@error) do %>
                <p class="text-error"><%= @error %></p>
              <% end %>
              <%!-- <p>@error</p> --%>
              <br /><br />
              <input
                type="text"
                placeholder="Badge number"
                class="w-full max-w-xs input input-bordered"
                name="badge_number"
                autofocus
              />

              <div class="modal-action">
                <label for={"seat-modal-#{@station.station_number}"} class="btn btn-error">Close</label>
                <button for={"seat-modal-#{@station.station_number}"} class="btn btn-success" type="submit">
                  Confirm reservation
                </button>
              </div>
            </form>
          </div>
        </div>
        """

      :occupied ->
        ~H"""
        <!-- The button to open modal -->
        <div class="btn btn-warning flex flex-col">
          <div >
            <%= @station.station_number %>
          </div>
          Until <%= Calendar.strftime(
            List.first(@station.reservations).end_date |> Timex.to_datetime("America/Montreal"),
                "%H:%M"
              ) %>
        </div>
        """

      :broken ->
        ~H"""
        <!-- The button to open modal -->
        <label class="btn btn-error">
          <%= @station.station_number %>
        </label>
        """

      :reserved ->
        ~H"""
        <!-- The button to open modal -->
        <label class="btn btn-active">
          <%= @station.station_number %>
        </label>
        """
    end
  end
end