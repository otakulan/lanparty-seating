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
      assigns.status == "available" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-info"><%= assigns.number %></label>
        """
      assigns.status == "occupied" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-warning"><%= assigns.number %></label>
        """
      assigns.status == "broken" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-error"><%= assigns.number %></label>
        """
      assigns.status == "reserved" ->
        ~H"""
          <!-- The button to open modal -->
          <label for={"seat-modal-#{assigns.number}"} class="btn btn-active"><%= assigns.number %></label>
        """
    end
  end
end
