defmodule LanpartyseatingWeb.SettingsControllerLive do
  use Phoenix.LiveView

  def make_2d_array(rows, columns) do
    Enum.to_list(0..rows-1)
    |> Enum.map(fn x ->
        Enum.to_list((x*columns)+1..(x+1)*columns)
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
        row
      else
        Enum.reverse(row)
      end
    end)
  end

  def reverse_odd_rows(list) when is_list(list) and is_list(hd(list)) do
    Enum.with_index(list)
    |> Enum.map(fn ({row, index}) ->
      if rem(index + 1, 2) == 0 do
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
        column
      else
        Enum.reverse(column)
      end
    end)
    |> transpose()
  end

  def mount(_params, _session, socket) do
    settings = Lanpartyseating.SettingsLogic.get_settings()
    socket = socket
    |> assign(:columns, settings.columns)
    |> assign(:rows, settings.rows)
    |> assign(:col_trailing, settings.vertical_trailing)
    |> assign(:row_trailing, settings.horizontal_trailing)
    |> assign(:is_diagonally_mirrored, settings.is_diagonally_mirrored)
    |> assign(:colpad, settings.column_padding)
    |> assign(:rowpad, settings.row_padding)
    # Creates a 2D array given the number of rows and columns
    |> assign(:table, make_2d_array(settings.rows, settings.columns))
    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(LanpartyseatingWeb.SettingsView, "settings.html", assigns)
  end

  def handle_event("number", _params, socket) do
    {:noreply, assign(socket, :temperature, 2666)}
  end

  def handle_event("col_trailing", _params, socket) do
    socket = socket
    |> update(:col_trailing, &(&1+1)) # fixme: integer overflow warning
    {:noreply, socket}
  end

  def handle_event("row_trailing", _params, socket) do
    socket = socket
    |> update(:row_trailing, &(&1+1)) # fixme: integer overflow warning
    {:noreply, socket}
  end

  def handle_event("change_dimensions", %{"rows" => rows, "columns" => columns}, socket) do
    socket = socket
    |> assign(:rows, String.to_integer(rows))
    |> assign(:columns, String.to_integer(columns))
    |> assign(:table, make_2d_array(String.to_integer(rows), String.to_integer(columns)))
    {:noreply, socket}
  end

  def handle_event("change_padding", %{"rowpad" => rowpad, "colpad" => colpad}, socket) do
    socket = socket
    |> assign(:rowpad, String.to_integer(rowpad)) # fixme: colpad should not be bigger than "rows"
    |> assign(:colpad, String.to_integer(colpad)) # fixme: colpad should not be bigger than "columns"
    {:noreply, socket}
  end

  def handle_event("horizontal_mirror_even", _params, socket) do
    socket = socket
    |> assign(:table, reverse_even_rows(socket.assigns.table))
    {:noreply, socket}
  end

  def handle_event("horizontal_mirror_odd", _params, socket) do
    socket = socket
    |> assign(:table, reverse_odd_rows(socket.assigns.table))
    {:noreply, socket}
  end

  def handle_event("vertical_mirror_even", _params, socket) do
    socket = socket
    |> assign(:table, reverse_even_columns(socket.assigns.table))
    {:noreply, socket}
  end

  def handle_event("vertical_mirror_odd", _params, socket) do
    socket = socket
    |> assign(:table, reverse_odd_columns(socket.assigns.table))
    {:noreply, socket}
  end

  def handle_event("diagonal_mirror", _params, socket) do
    socket = socket
    |> assign(:rows, socket.assigns.rows)
    |> assign(:columns, socket.assigns.columns)
    |> assign(:table, transpose(socket.assigns.table))
    {:noreply, socket}
  end

  def handle_event("reset_grid", _params, socket) do
    socket = socket
    |> assign(:table, make_2d_array(socket.assigns.rows, socket.assigns.columns))
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    socket = socket
    |> put_flash(:info, "Welcome Back!")

    s = socket.assigns

    Lanpartyseating.StationLogic.save_station_positions(socket.assigns.table)
    Lanpartyseating.SettingsLogic.save_settings(s.rows, s.columns, s.rowpad, s.colpad, s.is_diagonally_mirrored, s.row_trailing, s.col_trailing)
    {:noreply, socket}
  end

  def transpose(list) when is_list(list) and is_list(hd(list)) do
    for i <- 0..length(hd(list))-1 do
      Enum.map(list, &Enum.at(&1, i))
    end
  end

  def transpose(_), do: {:error, "Input must be a 2D list"}

end
