defmodule LanpartyseatingWeb.ManholeLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.ManholeLogic

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Manhole")
      |> assign(:single_station_number, "")
      |> assign(:range_start, "")
      |> assign(:range_end, "")
      |> assign(:cancel_single_station_number, "")
      |> assign(:cancel_range_start, "")
      |> assign(:cancel_range_end, "")
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)

    {:ok, socket}
  end

  def handle_event("single_station_broadcast", %{"station_number" => station_number}, socket) do
    case ManholeLogic.broadcast_single_station(station_number) do
      {:ok, station_num} ->
        socket =
          socket
          |> assign(:success_message, "Successfully broadcasted tournament start for station #{station_num}")
          |> assign(:error_message, nil)
          |> assign(:single_station_number, "")

        {:noreply, socket}

      {:error, message} ->
        socket =
          socket
          |> assign(:error_message, message)
          |> assign(:success_message, nil)

        {:noreply, socket}
    end
  end

  def handle_event("range_broadcast", %{"range_start" => range_start, "range_end" => range_end}, socket) do
    case ManholeLogic.broadcast_station_range(range_start, range_end) do
      {:ok, start_num, end_num} ->
        socket =
          socket
          |> assign(:success_message, "Successfully broadcasted tournament start for stations #{start_num} to #{end_num}")
          |> assign(:error_message, nil)
          |> assign(:range_start, "")
          |> assign(:range_end, "")

        {:noreply, socket}

      {:error, message} ->
        socket =
          socket
          |> assign(:error_message, message)
          |> assign(:success_message, nil)

        {:noreply, socket}
    end
  end

  def handle_event("update_single_station", %{"station_number" => station_number}, socket) do
    {:noreply, assign(socket, :single_station_number, station_number)}
  end

  def handle_event("update_range_start", %{"range_start" => range_start}, socket) do
    {:noreply, assign(socket, :range_start, range_start)}
  end

  def handle_event("update_range_end", %{"range_end" => range_end}, socket) do
    {:noreply, assign(socket, :range_end, range_end)}
  end

  def handle_event("cancel_single_station", %{"station_number" => station_number}, socket) do
    case ManholeLogic.cancel_single_station(station_number) do
      {:ok, station_num} ->
        socket =
          socket
          |> assign(:success_message, "Successfully cancelled reservation for station #{station_num}")
          |> assign(:error_message, nil)
          |> assign(:cancel_single_station_number, "")

        {:noreply, socket}

      {:error, message} ->
        socket =
          socket
          |> assign(:error_message, message)
          |> assign(:success_message, nil)

        {:noreply, socket}
    end
  end

  def handle_event("cancel_range", %{"range_start" => range_start, "range_end" => range_end}, socket) do
    case ManholeLogic.cancel_station_range(range_start, range_end) do
      {:ok, start_num, end_num} ->
        socket =
          socket
          |> assign(:success_message, "Successfully cancelled reservations for stations #{start_num} to #{end_num}")
          |> assign(:error_message, nil)
          |> assign(:cancel_range_start, "")
          |> assign(:cancel_range_end, "")

        {:noreply, socket}

      {:error, message} ->
        socket =
          socket
          |> assign(:error_message, message)
          |> assign(:success_message, nil)

        {:noreply, socket}
    end
  end

  def handle_event("update_cancel_single_station", %{"station_number" => station_number}, socket) do
    {:noreply, assign(socket, :cancel_single_station_number, station_number)}
  end

  def handle_event("update_cancel_range_start", %{"range_start" => range_start}, socket) do
    {:noreply, assign(socket, :cancel_range_start, range_start)}
  end

  def handle_event("update_cancel_range_end", %{"range_end" => range_end}, socket) do
    {:noreply, assign(socket, :cancel_range_end, range_end)}
  end

  # Clear messages when user starts typing
  def handle_event("clear_messages", _params, socket) do
    socket =
      socket
      |> assign(:error_message, nil)
      |> assign(:success_message, nil)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto max-w-4xl">
      <h1 class="text-3xl font-bold mb-2">Manhole - Station Control</h1>
      <p class="text-base-content/60 mb-6">Administrative tool for tournament and reservation management</p>
      
    <!-- Warning Notice -->
      <div class="alert alert-warning mb-8">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="stroke-current shrink-0 h-6 w-6"
          fill="none"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"
          />
        </svg>
        <span>Use with caution. This directly controls tournament and reservation states on desktop clients.</span>
      </div>

      <%= if @error_message do %>
        <div class="alert alert-error mb-4">
          <span>{@error_message}</span>
        </div>
      <% end %>

      <%= if @success_message do %>
        <div class="alert alert-success mb-4">
          <span>{@success_message}</span>
        </div>
      <% end %>
      
    <!-- Tournament Start Controls -->
      <section class="mb-10">
        <h2 class="text-xl font-semibold mb-4 border-b border-base-300 pb-2 text-error">Tournament Start Controls</h2>

        <div class="space-y-6">
          <!-- Single Station -->
          <div>
            <h3 class="font-medium mb-2">Single Station</h3>
            <form phx-submit="single_station_broadcast" class="flex items-end gap-4">
              <label class="flex items-center gap-3">
                <span class="text-sm text-base-content/70">Station #</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder="e.g. 15"
                  class="input input-bordered input-sm w-24"
                  name="station_number"
                  value={@single_station_number}
                  phx-change="update_single_station"
                  phx-focus="clear_messages"
                  required
                />
              </label>
              <button type="submit" class="btn btn-error btn-sm">Start Tournament</button>
            </form>
          </div>
          
    <!-- Station Range -->
          <div>
            <h3 class="font-medium mb-2">Station Range</h3>
            <form phx-submit="range_broadcast" class="flex items-end gap-4">
              <label class="flex items-center gap-3">
                <span class="text-sm text-base-content/70">From</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder="Start"
                  class="input input-bordered input-sm w-24"
                  name="range_start"
                  value={@range_start}
                  phx-change="update_range_start"
                  phx-focus="clear_messages"
                  required
                />
              </label>
              <label class="flex items-center gap-3">
                <span class="text-sm text-base-content/70">To</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder="End"
                  class="input input-bordered input-sm w-24"
                  name="range_end"
                  value={@range_end}
                  phx-change="update_range_end"
                  phx-focus="clear_messages"
                  required
                />
              </label>
              <button type="submit" class="btn btn-error btn-sm">Start Tournament Range</button>
            </form>
          </div>
        </div>
      </section>
      
    <!-- Cancel Reservation Controls -->
      <section class="mb-10">
        <h2 class="text-xl font-semibold mb-4 border-b border-base-300 pb-2 text-error">Cancel Reservation Controls</h2>

        <div class="space-y-6">
          <!-- Single Station Logout -->
          <div>
            <h3 class="font-medium mb-2">Single Station Logout</h3>
            <form phx-submit="cancel_single_station" class="flex items-end gap-4">
              <label class="flex items-center gap-3">
                <span class="text-sm text-base-content/70">Station #</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder="e.g. 15"
                  class="input input-bordered input-sm w-24"
                  name="station_number"
                  value={@cancel_single_station_number}
                  phx-change="update_cancel_single_station"
                  phx-focus="clear_messages"
                  required
                />
              </label>
              <button type="submit" class="btn btn-error btn-sm">Cancel Reservation</button>
            </form>
          </div>
          
    <!-- Range Logout -->
          <div>
            <h3 class="font-medium mb-2">Station Range Logout</h3>
            <form phx-submit="cancel_range" class="flex items-end gap-4">
              <label class="flex items-center gap-3">
                <span class="text-sm text-base-content/70">From</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder="Start"
                  class="input input-bordered input-sm w-24"
                  name="range_start"
                  value={@cancel_range_start}
                  phx-change="update_cancel_range_start"
                  phx-focus="clear_messages"
                  required
                />
              </label>
              <label class="flex items-center gap-3">
                <span class="text-sm text-base-content/70">To</span>
                <input
                  type="number"
                  min="1"
                  step="1"
                  placeholder="End"
                  class="input input-bordered input-sm w-24"
                  name="range_end"
                  value={@cancel_range_end}
                  phx-change="update_cancel_range_end"
                  phx-focus="clear_messages"
                  required
                />
              </label>
              <button type="submit" class="btn btn-error btn-sm">Cancel Range</button>
            </form>
          </div>
        </div>
      </section>
    </div>
    """
  end
end
