defmodule DisplayModalComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

  def modal(assigns) do
    # status:
    # 1 - libre / available  (blue: btn-info)
    # 2 - occupé / occupied (yellow: btn-warning)
    # 3 - brisé / broken  (red: btn-error)
    # 4 - réserver pour un tournois / reserved for a tournament  (black: btn-active)

    cond do
      assigns.station.status.status == "available" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.station.station.station_number}"} class="btn btn-info"><%= assigns.station.station.station_number %></label>
        """
      assigns.station.status.status == "occupied" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.station.station.station_number}"} class="btn btn-warning"><%= assigns.station.station.station_number %></label>
        """
      assigns.station.status.status == "broken" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.station.station.station_number}"} class="btn btn-error"><%= assigns.station.station.station_number %></label>
        """
      assigns.station.status.status == "reserved" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.station.station.station_number}"} class="btn btn-active"><%= assigns.station.station.station_number %></label>
        """
    end
  end
end
