defmodule LanpartyseatingWeb.SelfSignLive do
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
      Phoenix.PubSub.subscribe(PubSub, "station_status")
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
        %{"station_number" => station_number, "uid" => uid},
        socket
      ) do
    socket =
      case ReservationLogic.create_reservation(String.to_integer(station_number), String.to_integer("45"), uid) do
        # TODO: fix modal closing when registration_error is assigned
        {:error, error} ->
          socket
          |> put_flash(:error, error)

        {:ok, _updated} ->
          socket
          |> assign(:registration_error, nil)
          |> clear_flash(:error)
      end

    {:noreply, socket}
  end

  def handle_info({:stations, station_list}, socket) do
    {:noreply, assign_stations(socket, station_list)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.page_header
        title="Stations"
        subtitle="Please select an available station / Veuillez sélectionner une station disponible"
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
          <SelfSignModalComponent.modal
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
