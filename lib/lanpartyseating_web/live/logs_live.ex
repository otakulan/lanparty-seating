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
    <div class="container mx-auto max-w-7xl">
      <.page_header title="Reservation History" subtitle="Showing the last 100 reservations">
        <:trailing>
          <span class="text-base-content/60">{length(@reservations)} records</span>
        </:trailing>
      </.page_header>

      <.data_table>
        <:header>
          <th class="text-base-content">ID</th>
          <th class="text-base-content">Station</th>
          <th class="text-base-content">Badge</th>
          <th class="text-base-content">Duration</th>
          <th class="text-base-content">Start</th>
          <th class="text-base-content">End</th>
          <th class="text-base-content">Status</th>
          <th class="text-base-content">Incident</th>
          <th class="text-base-content">Created</th>
        </:header>
        <:row :for={reservation <- @reservations}>
          <tr class="hover:bg-base-200">
            <td class="text-base-content/50">{reservation.id}</td>
            <td class="font-mono font-semibold">{reservation.station_id}</td>
            <td class="font-mono">{reservation.badge || "-"}</td>
            <td>{reservation.duration} min</td>
            <td class="text-sm">{format_datetime(reservation.start_date)}</td>
            <td class="text-sm">{format_datetime(reservation.end_date)}</td>
            <td>
              <span class={status_class(reservation)}>{reservation_status(reservation)}</span>
            </td>
            <td class="max-w-xs truncate">{reservation.incident || "-"}</td>
            <td class="text-sm text-base-content/70">{format_datetime(reservation.inserted_at)}</td>
          </tr>
        </:row>
      </.data_table>
    </div>
    """
  end
end
