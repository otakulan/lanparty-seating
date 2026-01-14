defmodule LanpartyseatingWeb.AutoAssignLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.AutoAssignLogic, as: AutoAssignLogic
  alias Lanpartyseating.ReservationLogic, as: ReservationLogic

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:message, "")

    {:ok, socket}
  end

  def handle_event("submit_reservation", %{"uid" => ""}, socket) do
    {:noreply, assign(socket, :message, "Empty badge number submitted")}
  end

  def handle_event("submit_reservation", %{"uid" => uid}, socket) do
    message =
      case AutoAssignLogic.register_station(uid) do
        {:error, error} ->
          "No station available. Please wait for a station to be freed and scan your badge again. (#{error})"

        {:ok, number} ->
          {:ok, _} = ReservationLogic.create_reservation(number, 45, uid)

          "Your assigned station is: #{to_string(number)} (make this message disappear after 5 seconds with a nice fade out)"
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
          class="w-full max-w-xs input"
          name="uid"
          autocomplete="off"
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

      <h2 style="font-size:30px">{assigns.message}</h2>
    </div>
    """
  end
end
