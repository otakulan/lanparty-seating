defmodule LanpartyseatingWeb.SettingsControllerLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    settings = Lanpartyseating.SettingsLogic.get_settings()
    socket = socket
    |> assign(:columns, settings.columns)
    |> assign(:rows, settings.rows)
    |> assign(:col_trailing, settings.vertical_trailing)
    |> assign(:row_trailing, settings.horizontal_trailing)
    |> assign(:colpad, settings.column_padding)
    |> assign(:rowpad, settings.row_padding)
    |> assign(:table, Enum.to_list(1..settings.columns*settings.rows))
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
    |> assign(:table, Enum.to_list(1..String.to_integer(rows)*String.to_integer(columns)))
    {:noreply, socket}
  end

  def handle_event("change_padding", %{"rowpad" => rowpad, "colpad" => colpad}, socket) do
    socket = socket
    |> assign(:rowpad, String.to_integer(rowpad)) # fixme: colpad should not be bigger than "rows"
    |> assign(:colpad, String.to_integer(colpad)) # fixme: colpad should not be bigger than "columns"
    {:noreply, socket}
  end

  def handle_event("horizontal_mirror_even", _params, socket) do
    table = socket.assigns.table
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    |> assign(:table, Enum.map(Enum.to_list(0..w*h-1), fn i -> if rem(trunc(i / w), 2) == 0 do Enum.at(table, trunc(i / w) * w + w - rem(i, w) - 1) else Enum.at(table, i) end end))
    {:noreply, socket}
  end

  def handle_event("horizontal_mirror_odd", _params, socket) do
    table = socket.assigns.table
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    |> assign(:table, Enum.map(Enum.to_list(0..w*h-1), fn i -> if rem(trunc(i / w), 2) == 1 do Enum.at(table, trunc(i / w) * w + w - rem(i, w) - 1) else Enum.at(table, i) end end))
    {:noreply, socket}
  end

  def handle_event("vertical_mirror_even", _params, socket) do
    table = socket.assigns.table
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    |> assign(:table, Enum.map(Enum.to_list(0..w*h-1), fn i -> if rem(rem(i, w), 2) == 0 do Enum.at(table, i-(trunc(i / w) - (h - trunc(i / w) - 1)) * w)  else Enum.at(table, i) end end))
    {:noreply, socket}
  end

  def handle_event("vertical_mirror_odd", _params, socket) do
    table = socket.assigns.table
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    |> assign(:table, Enum.map(Enum.to_list(0..w*h-1), fn i -> if rem(rem(i, w), 2) == 1 do Enum.at(table, i-(trunc(i / w) - (h - trunc(i / w) - 1)) * w) else Enum.at(table, i) end end))
    {:noreply, socket}
  end

  def handle_event("diagonal_mirror", _params, socket) do
    table = socket.assigns.table
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    # fixme: broken when grid is not square
    |> assign(:table, Enum.map(Enum.to_list(0..w*h-1), fn i -> Enum.at(table, rem(i, w) * w + trunc(i / w)) end))
    {:noreply, socket}
  end

  def handle_event("shift_left", _params, socket) do
    table = socket.assigns.table
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    |> assign(:table, Enum.map(Enum.to_list(0..w*h-1), fn i -> Enum.at(table, rem(i + h * w - 1, h * w)) end))
    {:noreply, socket}
  end

  def handle_event("shift_right", _params, socket) do
    table = socket.assigns.table
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    |> assign(:table, Enum.map(Enum.to_list(0..w*h-1), fn i -> Enum.at(table, rem(i + 1, h * w)) end))
    {:noreply, socket}
  end

  def handle_event("reset_grid", _params, socket) do
    h = socket.assigns.rows
    w = socket.assigns.columns
    socket = socket
    |> assign(:table, Enum.to_list(1..h*w))
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    socket = socket
    |> put_flash(:info, "Welcome Back!")

    s = socket.assigns

    Lanpartyseating.SettingsLogic.save_settings(s.rows, s.columns, s.rowpad, s.colpad, s.row_trailing, s.col_trailing)
    {:noreply, socket}
  end

end
