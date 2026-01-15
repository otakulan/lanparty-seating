defmodule LanpartyseatingWeb.SettingsLive do
  require Logger
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.Repo, as: Repo
  require Ecto.Query
  alias Lanpartyseating.PubSub, as: PubSub

  def minmax_row(grid, y_in) do
    grid
    |> Enum.reject(fn {{_x, y}, _} -> y != y_in end)
    |> Enum.map(fn {{x, _}, _} -> x end)
    |> Enum.min_max()
  end

  def minmax_column(grid, x_in) do
    grid
    |> Enum.reject(fn {{x, _y}, _} -> x != x_in end)
    |> Enum.map(fn {{_, y}, _} -> y end)
    |> Enum.min_max()
  end

  def reverse_rows(grid, rem) do
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

  def reverse_even_rows(grid) do
    reverse_rows(grid, 0)
  end

  def reverse_odd_rows(grid) do
    reverse_rows(grid, 1)
  end

  def reverse_columns(grid, rem) do
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

  def reverse_even_columns(grid) do
    reverse_columns(grid, 0)
  end

  def reverse_odd_columns(grid) do
    reverse_columns(grid, 1)
  end

  def transpose(grid) do
    grid
    |> Enum.map(fn {{x, y}, num} -> {{y, x}, num} end)
    |> Enum.into(%{})
  end

  @doc """
  returns {columns, rows}
  """
  def grid_dimensions(grid) do
    {max_x, max_y} =
      Map.keys(grid)
      |> Enum.reduce({0, 0}, fn {acc_x, acc_y}, {x, y} -> {max(x, acc_x), max(y, acc_y)} end)

    {max_x + 1, max_y + 1}
  end

  def socket_assign_grid(socket, grid) do
    {columns, rows} = grid_dimensions(grid)

    socket
    |> assign(:grid_width, columns)
    |> assign(:grid_height, rows)
    |> assign(:grid, grid)
  end

  def add_stations_to_grid(grid, column_major?, columns, rows, first_num, count) do
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

  def truncate_grid(grid, max) do
    grid |> Enum.reject(fn {_, num} -> num > max end) |> Enum.into(%{})
  end

  def resize_grid(grid, columns, rows, count) do
    if map_size(grid) > count do
      truncate_grid(grid, count)
    else
      add_stations_to_grid(grid, true, columns, rows, map_size(grid) + 1, count - map_size(grid))
    end
  end

  def mount(_params, _session, socket) do
    {:ok, settings} = Lanpartyseating.SettingsLogic.get_settings()
    layout = Lanpartyseating.StationLogic.get_station_layout()
    {columns, rows} = grid_dimensions(layout)
    # number of rows in layout table might not the number of rows in the stations table
    station_count = Repo.one(Ecto.Query.from(s in Lanpartyseating.Station, select: count("*")))
    layout = resize_grid(layout, columns, rows, station_count)
    {columns, rows} = grid_dimensions(layout)

    socket =
      socket
      |> assign(:columns, columns)
      |> assign(:rows, rows)
      |> assign(:station_count, station_count)
      |> assign(:col_trailing, settings.vertical_trailing)
      |> assign(:row_trailing, settings.horizontal_trailing)
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> socket_assign_grid(layout)

    {:ok, socket}
  end

  def handle_event("number", _params, socket) do
    {:noreply, assign(socket, :temperature, 2666)}
  end

  def handle_event("col_trailing", _params, socket) do
    socket =
      socket
      # fixme: integer overflow warning
      |> update(:col_trailing, &(&1 + 1))

    {:noreply, socket}
  end

  def handle_event("row_trailing", _params, socket) do
    socket =
      socket
      # fixme: integer overflow warning
      |> update(:row_trailing, &(&1 + 1))

    {:noreply, socket}
  end

  def handle_event("change_dimensions", %{"rows" => rows, "columns" => columns}, socket) do
    socket =
      socket
      |> assign(:rows, String.to_integer(rows))
      |> assign(:columns, String.to_integer(columns))

    {:noreply, socket}
  end

  def handle_event("change_padding", %{"rowpad" => rowpad, "colpad" => colpad}, socket) do
    socket =
      socket
      # fixme: colpad should not be bigger than "rows"
      |> assign(:rowpad, String.to_integer(rowpad))
      # fixme: colpad should not be bigger than "columns"
      |> assign(:colpad, String.to_integer(colpad))

    {:noreply, socket}
  end

  def handle_event("horizontal_mirror_even", _params, socket) do
    socket =
      socket
      |> socket_assign_grid(reverse_even_rows(socket.assigns.grid))

    {:noreply, socket}
  end

  def handle_event("horizontal_mirror_odd", _params, socket) do
    socket =
      socket
      |> socket_assign_grid(reverse_odd_rows(socket.assigns.grid))

    {:noreply, socket}
  end

  def handle_event("vertical_mirror_even", _params, socket) do
    socket =
      socket
      |> socket_assign_grid(reverse_even_columns(socket.assigns.grid))

    {:noreply, socket}
  end

  def handle_event("vertical_mirror_odd", _params, socket) do
    socket =
      socket
      |> socket_assign_grid(reverse_odd_columns(socket.assigns.grid))

    {:noreply, socket}
  end

  def handle_event("diagonal_mirror", _params, socket) do
    grid = transpose(socket.assigns.grid)
    {columns, rows} = grid_dimensions(grid)

    socket =
      socket
      |> assign(:columns, columns)
      |> assign(:rows, rows)
      |> socket_assign_grid(grid)

    {:noreply, socket}
  end

  def handle_event("reset_grid_column_major", _params, socket) do
    grid =
      add_stations_to_grid(%{}, true, socket.assigns.columns, socket.assigns.rows, 1, socket.assigns.station_count)

    socket =
      socket
      |> socket_assign_grid(grid)

    {:noreply, socket}
  end

  def handle_event("reset_grid_row_major", _params, socket) do
    grid =
      add_stations_to_grid(%{}, false, socket.assigns.columns, socket.assigns.rows, 1, socket.assigns.station_count)

    socket =
      socket
      |> socket_assign_grid(grid)

    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    s = socket.assigns

    save_stations = Lanpartyseating.StationLogic.save_stations(s.grid)

    save_settings =
      Lanpartyseating.SettingsLogic.settings_db_changes(
        s.rowpad,
        s.colpad,
        s.row_trailing,
        s.col_trailing
      )

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

          socket
          |> put_flash(:error, "Postgres exception trying to commit transaction:\n#{inspect(e)}")
      end

    {:noreply, socket}
  end

  def publish_station_update() do
    {:ok, stations} = Lanpartyseating.StationLogic.get_all_stations()

    Phoenix.PubSub.broadcast(
      PubSub,
      "station_update",
      {:stations, stations}
    )
  end

  # Note: This handle_event clause is separated from others above by the
  # helper function publish_station_update/0. This is intentional for code organization.
  def handle_event("move", params, socket) do
    grid = socket.assigns.grid
    %{"from" => %{"x" => x1, "y" => y1}, "to" => %{"x" => x2, "y" => y2}} = params
    # should never be nil
    from_num = Map.get(grid, {x1, y1})
    # nil if empty slot
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

    socket =
      socket
      |> socket_assign_grid(grid)

    {:noreply, socket}
  end

  def handle_event("change_station_count", %{"station_count" => count}, socket) do
    grid = socket.assigns.grid
    count = String.to_integer(count)
    grid = resize_grid(grid, socket.assigns.columns, socket.assigns.rows, count)

    socket =
      socket
      |> assign(:station_count, count)
      |> socket_assign_grid(grid)

    {:noreply, socket}
  end

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="container mx-auto max-w-6xl">
      <h1 class="text-3xl font-bold mb-2">Station Layout Settings</h1>
      <p class="text-base-content/60 mb-8">Configure the station grid layout displayed on signage</p>
      
    <!-- Grid Configuration Section -->
      <section class="mb-10">
        <h2 class="text-xl font-semibold mb-4 border-b border-base-300 pb-2">Grid Configuration</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <!-- Grid Dimensions -->
          <div>
            <h3 class="font-medium mb-3">Dimensions</h3>
            <form phx-change="change_dimensions" class="space-y-3">
              <label class="flex items-center gap-3">
                <span class="w-20 text-sm text-base-content/70">Columns</span>
                <input
                  type="number"
                  min={@grid_width}
                  class="input input-bordered input-sm w-24"
                  name="columns"
                  value={@columns}
                />
              </label>
              <label class="flex items-center gap-3">
                <span class="w-20 text-sm text-base-content/70">Rows</span>
                <input
                  type="number"
                  min={@grid_height}
                  class="input input-bordered input-sm w-24"
                  name="rows"
                  value={@rows}
                />
              </label>
            </form>
          </div>
          
    <!-- Station Count -->
          <div>
            <h3 class="font-medium mb-3">Station Count</h3>
            <form phx-change="change_station_count">
              <label class="flex items-center gap-3">
                <span class="w-20 text-sm text-base-content/70">Stations</span>
                <input
                  type="number"
                  min="1"
                  max={"#{@rows * @columns}"}
                  class="input input-bordered input-sm w-24"
                  name="station_count"
                  value={@station_count}
                />
              </label>
            </form>
            <p class="text-xs text-base-content/50 mt-2">Max: {@rows * @columns}</p>
          </div>
          
    <!-- Aisle Gaps -->
          <div>
            <h3 class="font-medium mb-3">Aisle Gaps</h3>
            <form phx-change="change_padding" class="space-y-3">
              <label class="flex items-center gap-3">
                <span class="w-20 text-sm text-base-content/70">Col gap</span>
                <input
                  type="number"
                  min="1"
                  max="15"
                  class="input input-bordered input-sm w-24"
                  name="colpad"
                  value={@colpad}
                />
              </label>
              <label class="flex items-center gap-3">
                <span class="w-20 text-sm text-base-content/70">Row gap</span>
                <input
                  type="number"
                  min="1"
                  max="15"
                  class="input input-bordered input-sm w-24"
                  name="rowpad"
                  value={@rowpad}
                />
              </label>
            </form>
            <div class="flex gap-2 mt-3">
              <button class="btn btn-xs btn-outline" phx-click="col_trailing">
                <IconComponent.double_sided_arrow_horizontal /> Shift H
              </button>
              <button class="btn btn-xs btn-outline" phx-click="row_trailing">
                <IconComponent.double_sided_arrow_vertical /> Shift V
              </button>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Layout Tools Section -->
      <section class="mb-10">
        <h2 class="text-xl font-semibold mb-4 border-b border-base-300 pb-2">Layout Tools</h2>
        <p class="text-sm text-base-content/60 mb-4">Transform station numbering or drag stations in the preview to manually reorder.</p>

        <div class="flex flex-wrap gap-6 items-end">
          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Mirror Rows</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm" phx-click="horizontal_mirror_even">
                <IconComponent.double_sided_arrow_horizontal /> Even
              </button>
              <button class="btn btn-sm" phx-click="horizontal_mirror_odd">
                <IconComponent.double_sided_arrow_horizontal /> Odd
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Mirror Columns</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm" phx-click="vertical_mirror_even">
                <IconComponent.double_sided_arrow_vertical /> Even
              </button>
              <button class="btn btn-sm" phx-click="vertical_mirror_odd">
                <IconComponent.double_sided_arrow_vertical /> Odd
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Rotate</span>
            <div class="mt-1">
              <button class="btn btn-sm" phx-click="diagonal_mirror">
                <IconComponent.refresh /> Transpose
              </button>
            </div>
          </div>

          <div>
            <span class="text-xs text-base-content/50 uppercase tracking-wide">Reset</span>
            <div class="flex gap-2 mt-1">
              <button class="btn btn-sm btn-warning" phx-click="reset_grid_column_major">
                <IconComponent.x /> Column Major
              </button>
              <button class="btn btn-sm btn-warning" phx-click="reset_grid_row_major">
                <IconComponent.x /> Row Major
              </button>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Layout Preview Section -->
      <section class="mb-10">
        <div class="flex justify-between items-center mb-4 border-b border-base-300 pb-2">
          <h2 class="text-xl font-semibold">Layout Preview</h2>
          <button class="btn btn-primary" phx-click="save">Save Layout</button>
        </div>

        <div id="staton-grid" phx-hook="ButtonGridHook" class="flex flex-col gap-4 w-full p-4">
          <%!-- Group rows into table rows (separated by rowpad) --%>
          <% row_groups = group_by_padding(0..(@rows - 1), @rowpad, @row_trailing) %>
          <% rows_per_table = if @rowpad > 1, do: @rowpad, else: @rows %>
          <% cols_per_table = if @colpad > 1, do: @colpad, else: @columns %>
          <%= for row_group <- row_groups do %>
            <div class="flex flex-row gap-4">
              <%!-- Group columns into tables (separated by colpad) --%>
              <% col_groups = group_by_padding(0..(@columns - 1), @colpad, @col_trailing) %>
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
                            <% station_num = assigns.grid |> Map.get({c, r}) %>
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
    <script>
      let hooks = {};
      let draggedElement = null;

      hooks.ButtonGridHook = {
        mounted() {
          const container = document.getElementById('staton-grid');
          container.addEventListener('dragstart', event => {
            if (!event.target.matches('[station-x]')) return;
            draggedElement = event.target;
          });

          container.addEventListener("drop", event => {
          if (!event.target.matches('[station-x]')) return;
            // Push an event to the LiveView with some parameters
            let from = { x: parseInt(draggedElement.getAttribute("station-x")), y: parseInt(draggedElement.getAttribute("station-y")) };
            let to = { x: parseInt(event.target.getAttribute("station-x")), y: parseInt(event.target.getAttribute("station-y")) };
            this.pushEvent("move", { from: from, to: to });
          });
        }
      };
      window.customHooks = hooks;
    </script>
    """
  end
end
