defmodule LanpartyseatingWeb.LogsLive do
  use LanpartyseatingWeb, :live_view

  def mount(_params, _session, socket) do
    # BadgeScanLogsLogic.get_all_participants()
    participants = []

    socket =
      socket
      |> assign(:participants, Enum.reverse(participants))
      |> assign(:participantsCount, length(participants))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Seats</h1>

      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>badge id</th>
              <!-- badge uid -->
              <th>last scan</th>
              <!-- scan date that triggered the creation of the user in the AD -->

              <th>minutes left</th>
              <!-- minutes left until the user can't login or is logged off -->

              <th>expiry</th>

              <th>station number</th>

              <th>deactivated</th>
              <!-- a boolean that's true once the user has been successfully deleted from the AD -->
              <th>username</th>
              <!-- username as the temporary login credential -->
            </tr>
          </thead>
        <%= for participant <- @participants do %>
          <tr>
            <th><%= participant.badge_number %></th>
            <!-- badge uid -->
            <th><%= participant.date_scanned %></th>
            <!-- scan date that triggered the creation of the user in the AD -->

            <th><%=case DateTime.diff(participant.session_expiry, DateTime.utc_now(), :minute) do
              x when x < 0 -> 0
              x -> x
            end %></th>
            <!-- minutes left until the user can't login or is logged off -->

            <th><%= participant.session_expiry %></th>

            <th><%= participant.assigned_station_number %></th>

            <th>?</th>
            <!-- a boolean that's true once the user has been successfully deleted from the AD -->
            <th>?</th>
            <!-- username as the temporary login credential -->
          </tr>
          <% end %>
        </table>
      </div>
    </div>
    """
  end
end
