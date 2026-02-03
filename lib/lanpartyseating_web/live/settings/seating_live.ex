defmodule LanpartyseatingWeb.Settings.SeatingLive do
  @moduledoc """
  Settings page for station grid/seating configuration.
  """
  use LanpartyseatingWeb, :live_view
  require Logger
  import Ecto.Query
  import LanpartyseatingWeb.Helpers, only: [group_by_padding: 2]

  alias Lanpartyseating.Repo
  alias Lanpartyseating.PubSub
  alias LanpartyseatingWeb.Components.SettingsNav

  # ============================================================================
  # Mount & Handle Params
  # ============================================================================

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, %{assigns: %{live_action: :index}} = socket) do
    # Redirect /settings to /settings/seating
    {:noreply, push_navigate(socket, to: ~p"/settings/seating", replace: true)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, load_data(socket)}
  end

  defp load_data(socket) do
    {:ok, settings} = Lanpartyseating.SettingsLogic.get_settings()
    layout = Lanpartyseating.StationLogic.get_station_layout()
    {columns, rows} = grid_dimensions(layout)
    station_count = Repo.one(from(s in Lanpartyseating.Station, select: count("*")))
    layout = resize_grid(layout, columns, rows, station_count)
    {columns, rows} = grid_dimensions(layout)

    socket
    |> assign(:columns, columns)
    |> assign(:rows, rows)
    |> assign(:station_count, station_count)
    |> assign(:colpad, settings.column_padding)
    |> assign(:rowpad, settings.row_padding)
    |> socket_assign_grid(layout)
  end

  # ============================================================================
  # Grid Helper Functions
  # ============================================================================

  defp minmax_row(grid, y_in) do
    grid
    |> Enum.reject(fn {{_x, y}, _} -> y != y_in end)
    |> Enum.map(fn {{x, _}, _} -> x end)
    |> Enum.min_max()
  end

  defp minmax_column(grid, x_in) do
    grid
    |> Enum.reject(fn {{x, _y}, _} -> x != x_in end)
    |> Enum.map(fn {{_, y}, _} -> y end)
    |> Enum.min_max()
  end

  defp reverse_rows(grid, rem) do
    grid
    |> Enum.map(fn {{x, y}, num} ->
      if rem(y, 2) == rem do
        {min_x, max_x} = minmax_row(grid, y)
        {{max_x - x + min_x, y}, num}
      else
        {{x, y}, num}
      end
    end)
    |> Enum.into(%{})
  end

  defp reverse_even_rows(grid), do: reverse_rows(grid, 0)
  defp reverse_odd_rows(grid), do: reverse_rows(grid, 1)

  defp reverse_columns(grid, rem) do
    grid
    |> Enum.map(fn {{x, y}, num} ->
      if rem(x, 2) == rem do
        {min_y, max_y} = minmax_column(grid, x)
        {{x, max_y - y + min_y}, num}
      else
        {{x, y}, num}
      end
    end)
    |> Enum.into(%{})
  end

  defp reverse_even_columns(grid), do: reverse_columns(grid, 0)
  defp reverse_odd_columns(grid), do: reverse_columns(grid, 1)

  defp transpose(grid) do
    grid
    |> Enum.map(fn {{x, y}, num} -> {{y, x}, num} end)
    |> Enum.into(%{})
  end

  defp grid_dimensions(grid) do
    {max_x, max_y} =
      Map.keys(grid)
      |> Enum.reduce({0, 0}, fn {x, y}, {max_x, max_y} -> {max(x, max_x), max(y, max_y)} end)

    {max_x + 1, max_y + 1}
  end

  defp socket_assign_grid(socket, grid) do
    {columns, rows} = grid_dimensions(grid)

    socket
    |> assign(:grid_width, columns)
    |> assign(:grid_height, rows)
    |> assign(:grid, grid)
  end

  defp add_stations_to_grid(grid, column_major?, columns, rows, first_num, count) do
    order =
      if column_major? do
        for c <- 0..(columns - 1), r <- 0..(rows - 1), do: {c, r}
      else
        for r <- 0..(rows - 1), c <- 0..(columns - 1), do: {c, r}
      end

    order
    |> Stream.reject(fn pos -> Map.has_key?(grid, pos) end)
    |> Enum.take(count)
    |> Enum.with_index()
    |> Enum.map(fn {pos, index} -> {pos, index + first_num} end)
    |> Enum.into(grid)
  end

  defp truncate_grid(grid, max) do
    grid |> Enum.reject(fn {_, num} -> num > max end) |> Enum.into(%{})
  end

  defp resize_grid(grid, columns, rows, count) do
    if map_size(grid) > count do
      truncate_grid(grid, count)
    else
      add_stations_to_grid(grid, true, columns, rows, map_size(grid) + 1, count - map_size(grid))
    end
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  def handle_event("change_dimensions", %{"rows" => rows, "columns" => columns}, socket) do
    {:noreply,
     socket
     |> assign(:rows, String.to_integer(rows))
     |> assign(:columns, String.to_integer(columns))}
  end

  def handle_event("change_padding", %{"rowpad" => rowpad, "colpad" => colpad}, socket) do
    {:noreply,
     socket
     |> assign(:rowpad, String.to_integer(rowpad))
     |> assign(:colpad, String.to_integer(colpad))}
  end

  def handle_event("horizontal_mirror_even", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_even_rows(socket.assigns.grid))}
  end

  def handle_event("horizontal_mirror_odd", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_odd_rows(socket.assigns.grid))}
  end

  def handle_event("vertical_mirror_even", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_even_columns(socket.assigns.grid))}
  end

  def handle_event("vertical_mirror_odd", _params, socket) do
    {:noreply, socket_assign_grid(socket, reverse_odd_columns(socket.assigns.grid))}
  end

  def handle_event("diagonal_mirror", _params, socket) do
    grid = transpose(socket.assigns.grid)
    {columns, rows} = grid_dimensions(grid)

    {:noreply,
     socket
     |> assign(:columns, columns)
     |> assign(:rows, rows)
     |> socket_assign_grid(grid)}
  end

  def handle_event("reset_grid_column_major", _params, socket) do
    grid = add_stations_to_grid(%{}, true, socket.assigns.columns, socket.assigns.rows, 1, socket.assigns.station_count)
    {:noreply, socket_assign_grid(socket, grid)}
  end

  def handle_event("reset_grid_row_major", _params, socket) do
    grid = add_stations_to_grid(%{}, false, socket.assigns.columns, socket.assigns.rows, 1, socket.assigns.station_count)
    {:noreply, socket_assign_grid(socket, grid)}
  end

  def handle_event("save", _params, socket) do
    s = socket.assigns

    save_stations = Lanpartyseating.StationLogic.save_stations(s.grid)

    save_settings =
      Lanpartyseating.SettingsLogic.settings_db_changes(%{
        row_padding: s.rowpad,
        column_padding: s.colpad,
      })

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.append(save_settings)
      |> Ecto.Multi.append(save_stations)

    socket =
      try do
        case Repo.transaction(multi) do
          {:ok, _result} ->
            {columns, rows} = grid_dimensions(s.grid)
            publish_station_update()

            socket
            |> assign(:columns, columns)
            |> assign(:rows, rows)
            |> put_flash(:info, "Saved successfully")

          {:error, failed_operation, failed_value, changes_so_far} ->
            Logger.error("Transaction error")
            Logger.error("operation: #{failed_operation}")
            Logger.error("failed value: #{failed_value}")
            Logger.error("#{inspect(changes_so_far)}")

            socket
            |> put_flash(:error, "Transaction error\noperation: #{failed_operation}\nfailed value: #{failed_value}\n#{inspect(changes_so_far)}")
        end
      rescue
        e ->
          Logger.error("Postgres exception trying to commit transaction: #{inspect(e)}")
          socket |> put_flash(:error, "Postgres exception trying to commit transaction:\n#{inspect(e)}")
      end

    {:noreply, socket}
  end

  def handle_event("move", params, socket) do
    grid = socket.assigns.grid
    %{"from" => %{"x" => x1, "y" => y1}, "to" => %{"x" => x2, "y" => y2}} = params
    from_num = Map.get(grid, {x1, y1})
    to_num = Map.get(grid, {x2, y2})

    grid =
      if to_num != nil do
        grid
        |> Map.put({x1, y1}, to_num)
        |> Map.put({x2, y2}, from_num)
      else
        grid
        |> Map.delete({x1, y1})
        |> Map.put({x2, y2}, from_num)
      end

    {:noreply, socket_assign_grid(socket, grid)}
  end

  def handle_event("change_station_count", %{"station_count" => count}, socket) do
    grid = socket.assigns.grid
    count = String.to_integer(count)
    grid = resize_grid(grid, socket.assigns.columns, socket.assigns.rows, count)

    {:noreply,
     socket
     |> assign(:station_count, count)
     |> socket_assign_grid(grid)}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp publish_station_update do
    {:ok, stations} = Lanpartyseating.StationLogic.get_all_stations()
    Phoenix.PubSub.broadcast(PubSub, "station_update", {:stations, stations})
  end

  # ============================================================================
  # Render
  # ============================================================================

  def render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="settings-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content">
        <%!-- Mobile header with hamburger --%>
        <div class="lg:hidden navbar bg-base-200 border-b border-base-300">
          <label for="settings-drawer" class="btn btn-square btn-ghost">
            <Icons.menu />
          </label>
          <span class="text-lg font-bold">Seating Configuration</span>
        </div>

        <%!-- Main content area --%>
        <div class="p-4 lg:p-6">
          <.seating_content {assigns} />
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:seating} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  defp seating_content(assigns) do
    ~H"""
    <div class="max-w-6xl">
      <.page_header title="Station Layout Settings" subtitle="Configure the station grid layout displayed on signage" />

      <%!-- Grid Configuration Section --%>
      <.admin_section title="Grid Configuration">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <%!-- Grid Dimensions --%>
          <div>
            <h3 class="font-medium mb-3">Dimensions</h3>
            <form id="dimensions-form" phx-change="change_dimensions" class="space-y-3">
              <.labeled_input
                label="Columns"
                type="number"
                name="columns"
                value={@columns}
                min={@grid_width}
              />
              <.labeled_input
                label="Rows"
                type="number"
                name="rows"
                value={@rows}
                min={@grid_height}
              />
            </form>
          </div>

          <%!-- Station Count --%>
          <div>
            <h3 class="font-medium mb-3">Station Count</h3>
            <form id="station-count-form" phx-change="change_station_count">
              <.labeled_input
                label="Stations"
                type="number"
                name="station_count"
                value={@station_count}
                min={1}
                max={"#{@rows * @columns}"}
              />
            </form>
            <p class="text-xs text-base-content/50 mt-2">Max: {@rows * @columns}</p>
          </div>

          <%!-- Aisle Gaps --%>
          <div>
            <h3 class="font-medium mb-3">Aisle Gaps</h3>
            <form id="padding-form" phx-change="change_padding" class="space-y-3">
              <.labeled_input
                label="Col gap"
                type="number"
                name="colpad"
                value={@colpad}
                min={1}
                max={15}
              />
              <.labeled_input
                label="Row gap"
                type="number"
                name="rowpad"
                value={@rowpad}
                min={1}
                max={15}
              />
            </form>
          </div>
        </div>
      </.admin_section>

      <%!-- Layout Tools Section --%>
      <.admin_section title="Layout Tools">
        <p class="text-sm text-base-content/60 mb-4">Transform station numbering or drag stations in the preview to manually reorder.</p>

        <div class="flex flex-wrap gap-6 items-end">
          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Mirror Rows</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm" phx-click="horizontal_mirror_even">
                <Icons.double_sided_arrow_horizontal /> Even
              </button>
              <button class="btn btn-sm" phx-click="horizontal_mirror_odd">
                <Icons.double_sided_arrow_horizontal /> Odd
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Mirror Columns</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm" phx-click="vertical_mirror_even">
                <Icons.double_sided_arrow_vertical /> Even
              </button>
              <button class="btn btn-sm" phx-click="vertical_mirror_odd">
                <Icons.double_sided_arrow_vertical /> Odd
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Rotate</span>
            <div class="mt-1">
              <button class="btn btn-sm" phx-click="diagonal_mirror">
                <Icons.refresh /> Transpose
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Reset</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm btn-warning" phx-click="reset_grid_column_major">
                <Icons.x /> Column Major
              </button>
              <button class="btn btn-sm btn-warning" phx-click="reset_grid_row_major">
                <Icons.x /> Row Major
              </button>
            </div>
          </div>
        </div>
      </.admin_section>

      <%!-- Layout Preview Section --%>
      <section class="mb-10">
        <div class="flex justify-between items-center mb-4 border-b border-base-300 pb-2">
          <h2 class="text-xl font-semibold">Layout Preview</h2>
          <button class="btn btn-primary" phx-click="save">Save Layout</button>
        </div>

        <div id="station-grid" phx-hook="ButtonGridHook" class="flex flex-col gap-4 w-full p-4">
          <%!-- Group rows into table rows (separated by rowpad) --%>
          <% row_groups = group_by_padding(0..(@rows - 1), @rowpad) %>
          <% rows_per_table = if @rowpad > 1, do: @rowpad, else: @rows %>
          <% cols_per_table = if @colpad > 1, do: @colpad, else: @columns %>
          <%= for row_group <- row_groups do %>
            <div class="flex flex-row gap-4">
              <%!-- Group columns into tables (separated by colpad) --%>
              <% col_groups = group_by_padding(0..(@columns - 1), @colpad) %>
              <%= for col_group <- col_groups do %>
                <%!-- Calculate how many rows to render (pad partial tables) --%>
                <% actual_rows = length(row_group) %>
                <% render_rows = max(actual_rows, rows_per_table) %>
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
                            <% station_num = @grid |> Map.get({c, r}) %>
                            <%= if !is_nil(station_num) do %>
                              <div class="btn btn-warning h-full" station-x={"#{c}"} station-y={"#{r}"} draggable="true">
                                {Map.get(@grid, {c, r})}
                              </div>
                            <% else %>
                              <div class="btn btn-outline btn-ghost h-full" station-x={"#{c}"} station-y={"#{r}"}></div>
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
      </section>
    </div>
    """
  end
end
