defmodule LanpartyseatingWeb.BadgesLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.SeatingLogic, as: SeatingLogic
  alias Lanpartyseating.ReservationLogic, as: ReservationLogic

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:message, "")

    {:ok, socket}
  end

  def handle_event("submit_reservation", %{"badge_number" => badge_number}, socket) do
    message =
      if String.length(badge_number) > 0 do
        case SeatingLogic.register_seat(badge_number) do
          nil ->
            "No seat available. Please wait for a seat to be freed and scan your badge again."

          number ->
            # TODO: Handle case where create_reservation failed. It's possible that the function
            # fails to assign the requested seat.

            ReservationLogic.create_reservation(number, 45, badge_number)

            ## TODO: Create username and password in AD

            ## TODO: Display the ID of the reserved seat, all station have a username and password that relates to their ID
            ## The ID is the one of the next available station. People who come in group should scan their
            ## badge one after another if they want to be togheter.

            "Your assigned seat is: " <>
              to_string(number) <>
              " (make this message disappear after 5 seconds with a nice fade out)"
        end
      else
        "Empty badge number submitted"
      end

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
      <h1 style="font-size:30px">Scan your badge / Scannez votre badge</h1>

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

        <button for="" class="btn" type="submit">Submit / Soumettre</button>
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
