defmodule LanpartyseatingWeb.LogsLive do
  use LanpartyseatingWeb, :live_view
  import Ecto.Query
  alias Lanpartyseating.Reservation
  alias Lanpartyseating.Repo

  def mount(_params, _session, socket) do
    reservations = get_reservations()

    socket =
      socket
      |> assign(:reservations, reservations)

    {:ok, socket}
  end

  defp get_reservations do
    from(r in Reservation,
      order_by: [desc: r.inserted_at],
      limit: 100
    )
    |> Repo.all()
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    dt
    |> Timex.to_datetime("America/Montreal")
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  defp reservation_status(reservation) do
    now = DateTime.utc_now()

    cond do
      reservation.deleted_at != nil -> "Cancelled"
      DateTime.compare(reservation.end_date, now) == :lt -> "Expired"
      DateTime.compare(reservation.start_date, now) == :gt -> "Upcoming"
      true -> "Active"
    end
  end

  defp status_class(reservation) do
    case reservation_status(reservation) do
      "Active" -> "badge badge-success"
      "Expired" -> "badge badge-ghost"
      "Cancelled" -> "badge badge-error"
      "Upcoming" -> "badge badge-info"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Reservation History</h1>
      <p class="text-base-content/70 mb-4">Showing the last 100 reservations</p>

      <div class="overflow-x-auto">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>ID</th>
              <th>Station</th>
              <th>Badge</th>
              <th>Duration</th>
              <th>Start</th>
              <th>End</th>
              <th>Status</th>
              <th>Incident</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={reservation <- @reservations} :key={reservation.id}>
              <td>{reservation.id}</td>
              <td class="font-mono">{reservation.station_id}</td>
              <td class="font-mono">{reservation.badge || "-"}</td>
              <td>{reservation.duration} min</td>
              <td>{format_datetime(reservation.start_date)}</td>
              <td>{format_datetime(reservation.end_date)}</td>
              <td>
                <span class={status_class(reservation)}>{reservation_status(reservation)}</span>
              </td>
              <td>{reservation.incident || "-"}</td>
              <td>{format_datetime(reservation.inserted_at)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
