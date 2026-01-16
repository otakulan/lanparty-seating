defmodule LanpartyseatingWeb.CancellationLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic
  alias Lanpartyseating.ReservationLogic, as: ReservationLogic
  alias Lanpartyseating.PubSub, as: PubSub

  def assign_stations(socket, station_list) do
    {stations, {columns, rows}} = StationLogic.stations_by_xy(station_list)

    socket
    |> assign(:columns, columns)
    |> assign(:rows, rows)
    |> assign(:stations, stations)
  end

  def mount(_params, _session, socket) do
    {:ok, settings} = SettingsLogic.get_settings()
    {:ok, station_list} = StationLogic.get_all_stations()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PubSub, "station_update")
    end

    socket =
      socket
      |> assign(:col_trailing, settings.vertical_trailing)
      |> assign(:row_trailing, settings.horizontal_trailing)
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign_stations(station_list)
      |> assign(:registration_error, nil)

    {:ok, socket}
  end

  def handle_event(
        "reserve_station",
        %{
          "station_number" => station_number,
          "duration" => duration,
          "badge_number" => badge_number,
        },
        socket
      ) do
    registration_error = nil

    {:ok, _} =
      ReservationLogic.create_reservation(
        String.to_integer(station_number),
        String.to_integer(duration),
        badge_number
      )

    socket =
      socket
      |> assign(:registration_error, registration_error)

    {:noreply, socket}
  end

  def handle_event(
        "extend_reservation",
        %{"station_number" => id, "minutes_increment" => minutes},
        socket
      ) do
    {:ok, _} =
      ReservationLogic.extend_reservation(
        String.to_integer(id),
        String.to_integer(minutes)
      )

    {:noreply, socket}
  end

  def handle_event(
        "cancel_station",
        %{"station_number" => id, "cancel_reason" => reason},
        socket
      ) do
    {:ok, _} =
      ReservationLogic.cancel_reservation(
        String.to_integer(id),
        reason
      )

    {:noreply, socket}
  end

  def handle_event(
        "close_station",
        %{"station_number" => station_number},
        socket
      ) do
    {:ok, _} =
      StationLogic.set_station_broken(
        String.to_integer(station_number),
        true
      )

    {:noreply, socket}
  end

  def handle_event(
        "open_station",
        %{"station_number" => station_number},
        socket
      ) do
    {:ok, _} =
      StationLogic.set_station_broken(
        String.to_integer(station_number),
        false
      )

    {:noreply, socket}
  end

  def handle_info({:stations, stations}, socket) do
    {:noreply, assign_stations(socket, stations)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.page_header
        title="Station Management"
        subtitle="Click on a station to manage reservations, extend time, or mark as broken."
      />

      <.station_legend class="mb-6" />

      <.station_grid
        stations={@stations}
        rows={@rows}
        columns={@columns}
        rowpad={@rowpad}
        colpad={@colpad}
        row_trailing={@row_trailing}
        col_trailing={@col_trailing}
      >
        <:cell :let={station_data}>
          <CancellationModalComponent.modal
            error={@registration_error}
            reservation={station_data.reservation}
            station={station_data.station}
            status={station_data.status}
          />
        </:cell>
      </.station_grid>
    </div>
    """
  end
end
