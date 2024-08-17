defmodule LanpartyseatingWeb.SettingsLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.Repo, as: Repo
  require Ecto.Query

  def make_2d_array(rows, columns) do
    Enum.to_list(0..(rows - 1))
    |> Enum.map(fn x ->
      Enum.to_list((x * columns + 1)..((x + 1) * columns))
    end)
  end

  def reverse_even_rows(list) when is_list(list) and is_list(hd(list)) do
    Enum.with_index(list)
    |> Enum.map(fn {row, index} ->
      if rem(index + 1, 2) == 0 do
        Enum.reverse(row)
      else
        row
      end
    end)
  end

  def reverse_odd_rows(list) when is_list(list) and is_list(hd(list)) do
    Enum.with_index(list)
    |> Enum.map(fn {row, index} ->
      if rem(index, 2) == 0 do
        Enum.reverse(row)
      else
        row
      end
    end)
  end

  def reverse_even_columns(list) when is_list(list) and is_list(hd(list)) do
    transpose(list)
    |> Enum.with_index()
    |> Enum.map(fn {column, index} ->
      if rem(index + 1, 2) == 0 do
        Enum.reverse(column)
      else
        column
      end
    end)
    |> transpose()
  end

  def reverse_odd_columns(list) when is_list(list) and is_list(hd(list)) do
    transpose(list)
    |> Enum.with_index()
    |> Enum.map(fn {column, index} ->
      if rem(index, 2) == 0 do
        Enum.reverse(column)
      else
        column
      end
    end)
    |> transpose()
  end

  # {columns, rows}
  def grid_dimensions(grid) do
    {max_x, max_y} = Map.keys(grid)
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

  def mount(_params, _session, socket) do
    {:ok, settings} = Lanpartyseating.SettingsLogic.get_settings()
    layout = Lanpartyseating.StationLogic.get_station_layout()
    {columns, rows} = grid_dimensions(layout)
    # number of rows in layout table might not match station_count setting
    layout = resize_grid(layout, columns, settings.station_count)
    {columns, rows} = grid_dimensions(layout)

    socket =
      socket
      |> assign(:columns, columns)
      |> assign(:rows, rows)
      |> assign(:station_count, settings.station_count)
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
      |> assign(:table, make_2d_array(String.to_integer(rows), String.to_integer(columns)))

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
      |> assign(:table, reverse_even_rows(socket.assigns.table))

    {:noreply, socket}
  end

  def handle_event("horizontal_mirror_odd", _params, socket) do
    socket =
      socket
      |> assign(:table, reverse_odd_rows(socket.assigns.table))

    {:noreply, socket}
  end

  def handle_event("vertical_mirror_even", _params, socket) do
    socket =
      socket
      |> assign(:table, reverse_even_columns(socket.assigns.table))

    {:noreply, socket}
  end

  def handle_event("vertical_mirror_odd", _params, socket) do
    socket =
      socket
      |> assign(:table, reverse_odd_columns(socket.assigns.table))

    {:noreply, socket}
  end

  def handle_event("diagonal_mirror", _params, socket) do
    socket =
      socket
      |> assign(:rows, socket.assigns.rows)
      |> assign(:columns, socket.assigns.columns)
      |> assign(:table, transpose(socket.assigns.table))

    {:noreply, socket}
  end

  def handle_event("reset_grid", _params, socket) do
    socket =
      socket
      |> assign(:table, make_2d_array(socket.assigns.rows, socket.assigns.columns))

    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    socket =
      socket
      |> put_flash(:info, "Welcome Back!")

    s = socket.assigns

    insert_stations = Lanpartyseating.StationLogic.insert_stations(socket.assigns.grid)

    insert_settings = Lanpartyseating.SettingsLogic.save_settings(
      s.grid,
      s.station_count,
      s.rowpad,
      s.colpad,
      s.row_trailing,
      s.col_trailing
    )
    IO.inspect(Ecto.Query.from(Lanpartyseating.Station, []))
    multi = Ecto.Multi.new()
      # because of the foreign key these need to be deleted and inserted specifically in this order
      |> Ecto.Multi.delete_all(:delete_stations, Ecto.Query.from(Lanpartyseating.Station))
      |> Ecto.Multi.delete_all(:delete_layout, Ecto.Query.from(Lanpartyseating.StationLayout))
      |> Ecto.Multi.append(insert_settings)
      |> Ecto.Multi.append(insert_stations)

    case Repo.transaction(multi) do
      {:ok, result} ->
        :ok
      {:error, failed_operation, failed_value, _changes_so_far} ->
        IO.puts("Transaction failed!")
        IO.inspect(failed_operation)
        IO.inspect(failed_value)
        {:error, {:save_settings_failed, failed_operation}}
    end

    {:noreply, socket}
  end

  def transpose(list) when is_list(list) and is_list(hd(list)) do
    for i <- 0..(length(hd(list)) - 1) do
      Enum.map(list, &Enum.at(&1, i))
    end
  end

  def transpose(_), do: {:error, "Input must be a 2D list"}

  def handle_event("move", params, socket) do
    grid = socket.assigns.grid
    %{"from" => %{"x" => x1, "y" => y1}, "to" => %{"x" => x2, "y" => y2}} = params
    from_num = Map.get(grid, {x1, y1}) # should never be nil
    to_num = Map.get(grid, {x2, y2}) # nil if empty slot
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

  def add_stations_to_grid(grid, columns, first_num, count) do
    Stream.iterate(0, &(&1 + 1)) # infinite stream
      |> Stream.flat_map(fn r -> 0..columns - 1 |> Enum.map(fn c -> {c, r} end) end)
      |> Stream.reject(fn pos -> Map.has_key?(grid, pos) end)
      |> Enum.take(count)
      |> Enum.with_index()
      |> Enum.map(fn {pos, index} -> {pos, index + first_num} end)
      |> Enum.into(grid)
  end

  def truncate_grid(grid, count) do
    grid |> Enum.reject(fn {_, num} -> num > count end) |> Enum.into(%{})
  end

  def resize_grid(grid, columns, count) do
    if map_size(grid) > count do
      truncate_grid(grid, count)
    else
      add_stations_to_grid(grid, columns, map_size(grid) + 1, count - map_size(grid))
    end
  end

  def handle_event("change_station_count", %{"station_count" => count}, socket) do
    grid = socket.assigns.grid
    count = String.to_integer(count)
    grid = resize_grid(grid, socket.assigns.columns, count)

    socket =
      socket
      |> assign(:station_count, count)
      |> socket_assign_grid(grid)

    {:noreply, socket}
  end

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Grid Size Configuration</h1>
      <form phx-change="change_dimensions">
        columns:
        <input
          type="number"
          placeholder="X"
          min={@grid_width}
          #max="15"
          class="w-16 max-w-xs input input-bordered input-xs"
          name="columns"
          value={@columns}
        />
        rows:
        <input
          type="number"
          placeholder="Y"
          min={@grid_height}
          #max="15"
          class="w-16 max-w-xs input input-bordered input-xs"
          name="rows"
          value={@rows}
        />
      </form>

      <h1 style="font-size:30px">Number Of Stations</h1>
      <form phx-change="change_station_count">
        <input
          type="number"
          placeholder="X"
          min="1"
          max={"#{@rows * @columns}"}
          class="w-16 max-w-xs input input-bordered input-xs"
          name="station_count"
          value={@station_count}
        />
      </form>

      <h1 style="font-size:30px">Cell Padding Configuration</h1>
      <form phx-change="change_padding">
        <input
          type="number"
          placeholder="X"
          min="1"
          max="15"
          class="w-16 max-w-xs input input-bordered input-xs"
          name="colpad"
          value={@colpad}
        />
        <input
          type="number"
          placeholder="Y"
          min="1"
          max="15"
          class="w-16 max-w-xs input input-bordered input-xs"
          name="rowpad"
          value={@rowpad}
        />
      </form>

      <button class="btn btn-sm" phx-click="col_trailing">
        <IconComponent.double_sided_arrow_horizontal /> trailing
      </button>
      <button class="btn btn-sm" phx-click="row_trailing">
        <IconComponent.double_sided_arrow_vertical /> trailing
      </button>

      <h1 style="font-size:30px">Layout Configuration</h1>

      <button class="btn btn-sm" phx-click="horizontal_mirror_even">
        <IconComponent.double_sided_arrow_horizontal /> even
      </button>
      <button class="btn btn-sm" phx-click="horizontal_mirror_odd">
        <IconComponent.double_sided_arrow_horizontal /> odd
      </button>
      <button class="btn btn-sm" phx-click="vertical_mirror_even">
        <IconComponent.double_sided_arrow_vertical /> even
      </button>
      <button class="btn btn-sm" phx-click="vertical_mirror_odd">
        <IconComponent.double_sided_arrow_vertical /> odd
      </button>
      <button class="btn btn-sm" phx-click="diagonal_mirror">
        <IconComponent.refresh /> orientation
      </button>
      <button class="btn btn-sm" phx-click="reset_grid">
        <IconComponent.x /> reset
      </button>

      <h1 style="font-size:30px">Layout Preview</h1>

      <div id="staton-grid" phx-hook="ButtonGridHook" class="flex flex-wrap w-full">
        <%= for r <- 0..(@rows-1) do %>
          <div class={"#{if rem(r,@rowpad) == rem(@row_trailing, @rowpad) and @rowpad != 1, do: "mb-4", else: ""} flex flex-row w-full "}>
            <%= for c <- 0..(@columns-1) do %>
              <div class={"#{if rem(c,@colpad) == rem(@col_trailing, @colpad) and @colpad != 1, do: "mr-4", else: ""} flex flex-col h-14 flex-1 grow mx-1 "}>
                <% station_num = assigns.grid |> Map.get({c, r}) %>
                <%= if !is_nil(station_num) do %>
                <div class="btn btn-warning" station-number={"#{Map.get(@grid, {c, r})}"} station-x={"#{c}"} station-y={"#{r}"} draggable="true"><%= Map.get(@grid, {c, r}) %></div>
                <% else %>
                <div class="btn btn-outline" station-x={"#{c}"} station-y={"#{r}"}></div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      <button class="btn btn-wide" phx-click="save">Save layout</button>
    </div>
    <script>
      let hooks = {};
      let draggedElement = null;

      hooks.ButtonGridHook = {
        mounted() {
          const container = document.getElementById('staton-grid');
          container.addEventListener('dragstart', event => {
            if (!event.target.matches('[station-x]')) return;
            console.log('Drag started:', event.target);
            draggedElement = event.target;
          });

          container.addEventListener("drop", event => {
          if (!event.target.matches('[station-x]')) return;
            console.log('drop');
            console.log(draggedElement);
            console.log(event.target);
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
