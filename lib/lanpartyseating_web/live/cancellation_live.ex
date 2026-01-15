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
      <h1 class="text-3xl font-bold mb-4">Station Management</h1>
      <p class="text-base-content/70 mb-4">
        Click on a station to manage reservations, extend time, or mark as broken.
      </p>

      <%!-- LEGEND --%>
      <div class="flex flex-wrap gap-4 mb-6 p-3 bg-base-200 rounded-lg">
        <div class="flex items-center gap-2 text-sm">
          <span class="w-4 h-4 rounded-full bg-success inline-block"></span>
          <span>Available / Disponible</span>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <span class="w-4 h-4 rounded-full bg-warning inline-block"></span>
          <span>Occupied / Occupée</span>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <span class="w-4 h-4 rounded-full bg-error inline-block"></span>
          <span>Broken / Brisée</span>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <span class="w-4 h-4 rounded-full bg-neutral inline-block"></span>
          <span>Tournament / Tournoi</span>
        </div>
      </div>

      <div class="flex flex-col gap-4 w-full">
        <%!-- Group rows into table rows (separated by rowpad) --%>
        <% row_groups = group_by_padding(0..(@rows - 1), @rowpad, @row_trailing) %>
        <% rows_per_table = if @rowpad > 1, do: @rowpad, else: @rows %>
        <% cols_per_table = if @colpad > 1, do: @colpad, else: @columns %>
        <%= for row_group <- row_groups do %>
          <%!-- Calculate how many rows to render (pad partial tables) --%>
          <% actual_rows = length(row_group) %>
          <% render_rows = max(actual_rows, rows_per_table) %>
          <div class="flex flex-row gap-4">
            <%!-- Group columns into tables (separated by colpad) --%>
            <% col_groups = group_by_padding(0..(@columns - 1), @colpad, @col_trailing) %>
            <%= for col_group <- col_groups do %>
              <% actual_cols = length(col_group) %>
              <% render_cols = max(actual_cols, cols_per_table) %>
              <div class="flex-1 bg-base-200 border-2 border-base-300 rounded-xl p-2 flex flex-col gap-1">
                <%!-- Render rows, padding partial tables to full height --%>
                <%= for row_idx <- 0..(render_rows - 1) do %>
                  <% r = Enum.at(row_group, row_idx) %>
                  <div class="flex flex-row h-11">
                    <%= for col_idx <- 0..(render_cols - 1) do %>
                      <% c = Enum.at(col_group, col_idx) %>
                      <div class="flex flex-col flex-1 grow mx-0.5">
                        <%= if r != nil and c != nil do %>
                          <% station_data = @stations |> Map.get({c, r}) %>
                          <%= if !is_nil(station_data) do %>
                            <CancellationModalComponent.modal
                              error={@registration_error}
                              reservation={station_data.reservation}
                              station={station_data.station}
                              status={station_data.status}
                            />
                          <% end %>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
