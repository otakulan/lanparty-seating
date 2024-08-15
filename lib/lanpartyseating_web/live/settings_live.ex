defmodule LanpartyseatingWeb.SettingsLive do
  use LanpartyseatingWeb, :live_view

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

  def mount(_params, _session, socket) do
    {:ok, settings} = Lanpartyseating.SettingsLogic.get_settings()
    layout = Lanpartyseating.StationLogic.get_station_layout()
    {max_x, max_y} = Map.keys(layout)
      |> Enum.reduce({0, 0}, fn {acc_x, acc_y}, {x, y} -> {max(x, acc_x), max(y, acc_y)} end)
    columns = max_x + 1
    rows = max_y + 1

    socket =
      socket
      |> assign(:columns, columns)
      |> assign(:rows, rows)
      |> assign(:col_trailing, settings.vertical_trailing)
      |> assign(:row_trailing, settings.horizontal_trailing)
      |> assign(:is_diagonally_mirrored, settings.is_diagonally_mirrored)
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      # Creates a 2D array given the number of rows and columns
      |> assign(:grid, layout)

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
      |> assign(:is_diagnoally_mirrored, !socket.assigns.is_diagonally_mirrored)
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

    :ok = Lanpartyseating.StationLogic.save_station_positions(socket.assigns.table)

    :ok = Lanpartyseating.SettingsLogic.save_settings(
      s.rows,
      s.columns,
      s.rowpad,
      s.colpad,
      s.is_diagonally_mirrored,
      s.row_trailing,
      s.col_trailing
    )

    {:noreply, socket}
  end

  def transpose(list) when is_list(list) and is_list(hd(list)) do
    for i <- 0..(length(hd(list)) - 1) do
      Enum.map(list, &Enum.at(&1, i))
    end
  end

  def transpose(_), do: {:error, "Input must be a 2D list"}

  def handle_event("swap", params, socket) do
    IO.puts("meow")
    grid = socket.assigns.grid
    as_list = Map.to_list(grid)
    {from, _} = Map.get(params, "from") |> Integer.parse()
    {to, _} = Map.get(params, "to") |> Integer.parse()
    {from_pos, from_num} = List.keyfind(as_list, from, 1)
    {to_pos, to_num} = List.keyfind(as_list, to, 1)
    grid = grid
      |> Map.put(from_pos, to_num)
      |> Map.put(to_pos, from_num)

    socket =
      socket
      |> assign(:grid, grid)

    {:noreply, socket}
  end

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Grid Size Configuration</h1>

      <form phx-change="change_dimensions">
        <input
          type="number"
          placeholder="X"
          min="1"
          max="15"
          class="w-16 max-w-xs input input-bordered input-xs"
          name="columns"
          value={@columns}
        />
        <input
          type="number"
          placeholder="Y"
          min="1"
          max="15"
          class="w-16 max-w-xs input input-bordered input-xs"
          name="rows"
          value={@rows}
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
                <div class="btn btn-warning" station-number={"#{Map.get(@grid, {c, r})}"} station-x={"#{c}"} station-y={"#{r}"} draggable="true"><%= Map.get(@grid, {c, r}) %></div>
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
          const gridItems = document.querySelectorAll('[station-number]');

          gridItems.forEach(item => {
            item.addEventListener('dragstart', event => {
              draggedElement = event.target;
            });

            item.addEventListener("dragend", event => {
              // for some reason this print statement is required ???
              console.log('dragend');
            });

            item.addEventListener("drop", event => {
              console.log('drop');
              console.log(draggedElement);
              console.log(event.target);
              // Push an event to the LiveView with some parameters
              this.pushEvent("swap", { from: draggedElement.getAttribute("station-number"), to: event.target.getAttribute("station-number") });
            });
          });


        }
      };
      window.customHooks = hooks;
    </script>
    """
  end
end
