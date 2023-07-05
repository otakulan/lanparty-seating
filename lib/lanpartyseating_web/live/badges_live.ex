defmodule LanpartyseatingWeb.BadgesLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.SeatingLogic, as: SeatingLogic

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:message, "")

    {:ok, socket}
  end

  def handle_event("submit_reservation", %{"badge_number" => badge_number}, socket) do
    message =
      if String.length(badge_number) > 0 do
        IO.inspect(label: "******** submit_reservation entered")
        assigned_station_id = SeatingLogic.register_seat(badge_number)
        IO.inspect(label: "******** SeatingLogic.register_seat called")
        IO.inspect(label: "******** assigned id: " <> assigned_station_id)

        "Your assigned seat is: " <>
          assigned_station_id <>
          " (make this message disappear after 5 seconds with a nice fade out)"
      else
        "Empty badge number submitted"
      end

    # ??? is this
    # stations = StationLogic.get_all_stations()
    # broadcast_stations(stations)

    ## TODO: Display the ID of the reserved seat, all station have a username and password that relates to their ID
    ## The ID is the one of the next available station. People who come in group should scan their
    ## badge one after another if they want to be togheter.

    {:noreply, assign(socket, :message, message)}
  end

  def render(assigns) do
    ~H"""
    <script>
      function setFocusToTextBox(){
          document.getElementById("badge_field").focus();
      }
      setInterval(function(){setFocusToTextBox()}, 1000);
    </script>

    <div class="jumbotron">
      <h1 style="font-size:30px">Scan your badge</h1>

      <form phx-submit="submit_reservation">
        <br /><br />
        <input
          id="badge_field"
          type="text"
          placeholder="Badge number"
          class="w-full max-w-xs input input-bordered"
          name="badge_number"
          autofocus
        />

        <button for="" class="btn" type="submit">Submit</button>
      </form>

      <br />
      <br />
      <br />
      <br />
      <br />
      <br />

      <h2 style="font-size:30px"><%= assigns.message %></h2>
    </div>
    """
  end
end