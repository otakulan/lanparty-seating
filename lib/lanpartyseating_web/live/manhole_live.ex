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
    <div class="container mx-auto px-4 py-4">
      <h1 class="text-3xl font-bold mb-6">Manhole - Tournament & Station Control</h1>
      
    <!-- Warning Notice -->
      <div class="alert alert-warning mb-6">
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
        <span>
          This is an administrative tool. Use with caution as it directly controls tournament and reservation states on desktop clients.
        </span>
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
      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4 text-error">Tournament Start Controls</h2>
        
    <!-- Single Station Tournament Start -->
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h3 class="card-title text-error">Single Station Tournament Start</h3>
            <p class="text-base-content/70">Broadcast tournament start command to a single station</p>

            <form phx-submit="single_station_broadcast" class="w-full max-w-xs">
              <label class="label" for="station_number">Station Number</label>
              <input
                type="number"
                min="1"
                step="1"
                placeholder="Enter station number"
                class="input w-full max-w-xs"
                name="station_number"
                value={@single_station_number}
                phx-change="update_single_station"
                phx-focus="clear_messages"
                required
              />
              <div class="card-actions justify-end mt-4">
                <button type="submit" class="btn btn-error">
                  Start Tournament
                </button>
              </div>
            </form>
          </div>
        </div>
        
    <!-- Range Tournament Start -->
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h3 class="card-title text-error">Station Range Tournament Start</h3>
            <p class="text-base-content/70">
              Broadcast tournament start command to a range of stations
            </p>

            <form phx-submit="range_broadcast">
              <div class="flex gap-4 items-end">
                <div class="w-full max-w-xs">
                  <label class="label" for="range_start">Start Station</label>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    placeholder="Start station"
                    class="input w-full max-w-xs"
                    name="range_start"
                    value={@range_start}
                    phx-change="update_range_start"
                    phx-focus="clear_messages"
                    required
                  />
                </div>

                <div class="w-full max-w-xs">
                  <label class="label" for="range_end">End Station</label>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    placeholder="End station"
                    class="input w-full max-w-xs"
                    name="range_end"
                    value={@range_end}
                    phx-change="update_range_end"
                    phx-focus="clear_messages"
                    required
                  />
                </div>

                <div class="card-actions">
                  <button type="submit" class="btn btn-error">
                    Start Tournament Range
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      </div>
      
    <!-- Cancel Reservation Controls -->
      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4 text-error">Cancel Reservation Controls</h2>
        
    <!-- Single Station Cancel -->
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h3 class="card-title text-error">Single Station Logout</h3>
            <p class="text-base-content/70">Cancel reservation and log out a single station</p>

            <form phx-submit="cancel_single_station" class="w-full max-w-xs">
              <label class="label" for="station_number">Station Number</label>
              <input
                type="number"
                min="1"
                step="1"
                placeholder="Enter station number"
                class="input w-full max-w-xs"
                name="station_number"
                value={@cancel_single_station_number}
                phx-change="update_cancel_single_station"
                phx-focus="clear_messages"
                required
              />
              <div class="card-actions justify-end mt-4">
                <button type="submit" class="btn btn-error">
                  Cancel Reservation
                </button>
              </div>
            </form>
          </div>
        </div>
        
    <!-- Range Cancel -->
        <div class="card bg-base-100 shadow-xl mb-6">
          <div class="card-body">
            <h3 class="card-title text-error">Station Range Logout</h3>
            <p class="text-base-content/70">Cancel reservations and log out a range of stations</p>

            <form phx-submit="cancel_range">
              <div class="flex gap-4 items-end">
                <div class="w-full max-w-xs">
                  <label class="label" for="range_start">Start Station</label>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    placeholder="Start station"
                    class="input w-full max-w-xs"
                    name="range_start"
                    value={@cancel_range_start}
                    phx-change="update_cancel_range_start"
                    phx-focus="clear_messages"
                    required
                  />
                </div>

                <div class="w-full max-w-xs">
                  <label class="label" for="range_end">End Station</label>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    placeholder="End station"
                    class="input w-full max-w-xs"
                    name="range_end"
                    value={@cancel_range_end}
                    phx-change="update_cancel_range_end"
                    phx-focus="clear_messages"
                    required
                  />
                </div>

                <div class="card-actions">
                  <button type="submit" class="btn btn-error">
                    Cancel Range
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
