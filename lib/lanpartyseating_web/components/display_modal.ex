defmodule DisplayModalComponent do
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
          <label for={"seat-modal-#{assigns.station.station_number}"} class="btn btn-info"><%= assigns.station.station_number %></label>
        """
      :occupied ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.station.station_number}"} class="btn btn-warning"><%= assigns.station.station_number %></label>
        """
      :broken ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.station.station_number}"} class="btn btn-error"><%= assigns.station.station_number %></label>
        """
      :reserved ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.station.station_number}"} class="btn btn-active"><%= assigns.station.station_number %></label>
        """
    end
  end
end
