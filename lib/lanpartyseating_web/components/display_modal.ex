defmodule DisplayModalComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

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
          <label class="btn btn-info"><%= assigns.station.station_number %></label>
        """

      :occupied ->
        ~H"""
          <!-- The button to open modal -->
          <label class="btn btn-warning flex flex-col">
            <div >
              <%= assigns.station.station_number %>
            </div>
            Until <%= Calendar.strftime(
              List.first(assigns.station.reservations).end_date |> Timex.to_datetime("America/Montreal"),
                  "%H:%M"
                ) %>
          </label>
        """

      :broken ->
        ~H"""
          <!-- The button to open modal -->
          <label class="btn btn-error"><%= assigns.station.station_number %></label>
        """

      :reserved ->
        ~H"""
          <!-- The button to open modal -->
          <label class="btn btn-active"><%= assigns.station.station_number %></label>
        """
    end
  end
end
