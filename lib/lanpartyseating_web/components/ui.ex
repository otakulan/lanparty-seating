defmodule LanpartyseatingWeb.Components.UI do
  @moduledoc """
  Shared UI components for the LAN Party Seating application.

  These components reduce code duplication across LiveView pages
  by providing consistent, reusable UI elements.
  """
  use Phoenix.Component
  import LanpartyseatingWeb.Helpers

  # ============================================================================
  # Station Legend Component
  # ============================================================================

  @doc """
  Renders the station status legend with color-coded indicators.

  ## Examples

      <.station_legend />

  """
  attr :class, :string, default: nil

  def station_legend(assigns) do
    ~H"""
    <div class={["flex flex-wrap gap-4 mb-4 p-3 bg-base-200 rounded-lg", @class]}>
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
    """
  end

  # ============================================================================
  # Station Grid Component
  # ============================================================================

  @doc """
  Renders a station grid layout with proper table grouping based on padding settings.

  The grid automatically groups stations into "physical tables" based on the
  row and column padding values, creating visual separation between groups.

  ## Examples

      <.station_grid
        stations={@stations}
        rows={@rows}
        columns={@columns}
        rowpad={@rowpad}
        colpad={@colpad}
      >
        <:cell :let={station_data}>
          <DisplayModalComponent.modal
            reservation={station_data.reservation}
            station={station_data.station}
            status={station_data.status}
          />
        </:cell>
      </.station_grid>

  """
  attr :stations, :map, required: true
  attr :rows, :integer, required: true
  attr :columns, :integer, required: true
  attr :rowpad, :integer, required: true
  attr :colpad, :integer, required: true
  attr :class, :string, default: nil

  slot :cell, required: true

  def station_grid(assigns) do
    stations = assigns.stations

    # Find globally active rows and columns (those with at least one station)
    station_coords = Map.keys(stations)
    # Extract x coordinate (column) from each {x, y} tuple
    active_cols =
      station_coords
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()
      |> Enum.sort()

    # Extract y coordinate (row) from each {x, y} tuple
    active_rows =
      station_coords
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()
      |> Enum.sort()

    # Group into table chunks, but only include active indices
    # Filter each group to only rows that have stations, remove empty groups
    row_groups =
      group_by_padding(0..(assigns.rows - 1), assigns.rowpad)
      |> Enum.map(fn group ->
        Enum.filter(group, &(&1 in active_rows))
      end)
      |> Enum.reject(&(&1 == []))

    # Filter each group to only columns that have stations, remove empty groups
    col_groups =
      group_by_padding(0..(assigns.columns - 1), assigns.colpad)
      |> Enum.map(fn group ->
        Enum.filter(group, &(&1 in active_cols))
      end)
      |> Enum.reject(&(&1 == []))

    assigns =
      assigns
      |> assign(:row_groups, row_groups)
      |> assign(:col_groups, col_groups)

    ~H"""
    <div class={["flex flex-col gap-4 w-full", @class]}>
      <%= for row_group <- @row_groups do %>
        <div class="flex flex-row gap-4">
          <%!--
            Table container sizing:
            - flex-grow is set to the number of columns in this table group
            - This ensures tables with more columns are proportionally wider
            - Combined with the parent's flex-row, all tables fill the available width
            - Example: a 2-column table gets flex-grow:2, a 1-column table gets flex-grow:1
              → the 2-column table is twice as wide

            Cell min-width (min-w-10):
            - Empty cells must have a minimum width to maintain grid alignment
            - Without this, empty cells collapse to 0 width breaking the layout
            - This is crucial for vertical orientation where rows may have stations
              in different columns
          --%>
          <%= for col_group <- @col_groups do %>
            <div style={"flex-grow: #{length(col_group)}"} class="bg-base-200 border-2 border-base-300 rounded-xl p-2 flex flex-col gap-1">
              <%= for r <- row_group do %>
                <div class="flex flex-row h-11">
                  <%= for c <- col_group do %>
                    <div class="flex flex-col flex-1 grow mx-0.5 min-w-10">
                      <% station_data = Map.get(@stations, {c, r}) %>
                      <%= if !is_nil(station_data) do %>
                        {render_slot(@cell, station_data)}
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
    """
  end

  # ============================================================================
  # Countdown Timer Component
  # ============================================================================

  @doc """
  Renders a countdown timer using Alpine.js that counts down to a given end time.

  The timer automatically updates every second and displays in "XmYs" format
  (e.g., "32m14s" or "45s" when under a minute).

  ## Examples

      <.countdown end_date={@reservation.end_date} />

      <.countdown end_date={@tournament.start_date} class="text-2xl font-bold" />

  """
  attr :end_date, DateTime, required: true
  attr :class, :string, default: "font-mono font-bold"

  def countdown(assigns) do
    assigns =
      assigns
      |> assign(:end_date_iso, DateTime.to_iso8601(assigns.end_date))
      |> assign(:end_date_unix, DateTime.to_unix(assigns.end_date))

    ~H"""
    <span
      id={"countdown-#{@end_date_unix}"}
      class={@class}
      x-data={"{ endTime: new Date('#{@end_date_iso}'), remaining: '', intervalId: null }"}
      x-init="
        const update = () => {
          const now = new Date();
          const diff = Math.max(0, endTime - now);
          const mins = Math.floor(diff / 60000);
          const secs = Math.floor((diff % 60000) / 1000);
          if (mins > 0) {
            remaining = mins + 'm' + secs + 's';
          } else {
            remaining = secs + 's';
          }
        };
        update();
        intervalId = setInterval(update, 1000);
      "
      @destroy="clearInterval(intervalId)"
      x-text="remaining"
    >
    </span>
    """
  end

  @doc """
  Renders a countdown timer with hours support for longer durations.

  Displays in "Xh Ym Zs" format (omitting zero-value leading units).
  Shows "Started!" when the countdown reaches zero.

  ## Examples

      <.countdown_long start_date={@tournament.start_date} class="countdown-timer" />

  """
  attr :start_date, DateTime, required: true
  attr :class, :string, default: "font-mono font-bold"

  def countdown_long(assigns) do
    assigns =
      assigns
      |> assign(:start_date_iso, DateTime.to_iso8601(assigns.start_date))
      |> assign(:start_date_unix, DateTime.to_unix(assigns.start_date))

    ~H"""
    <span
      id={"countdown-long-#{@start_date_unix}"}
      class={@class}
      x-data={"{ startTime: new Date('#{@start_date_iso}'), remaining: '', started: false, intervalId: null }"}
      x-init="
        const update = () => {
          const now = new Date();
          const diff = startTime - now;
          if (diff <= 0) {
            started = true;
            remaining = 'Started!';
          } else {
            const hours = Math.floor(diff / 3600000);
            const mins = Math.floor((diff % 3600000) / 60000);
            const secs = Math.floor((diff % 60000) / 1000);
            if (hours > 0) {
              remaining = hours + 'h' + mins + 'm' + secs + 's';
            } else if (mins > 0) {
              remaining = mins + 'm' + secs + 's';
            } else {
              remaining = secs + 's';
            }
          }
        };
        update();
        intervalId = setInterval(update, 1000);
      "
      @destroy="clearInterval(intervalId)"
      x-text="remaining"
    >
    </span>
    """
  end

  # ============================================================================
  # Page Header Component
  # ============================================================================

  @doc """
  Renders a consistent page header with title and optional subtitle.

  ## Examples

      <.page_header title="Seat Map Editor" subtitle="Configure the room-true seat map layout" />

      <.page_header title="Reservation History">
        <:trailing>
          <span class="text-base-content/60">88 records</span>
        </:trailing>
      </.page_header>

  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :class, :string, default: nil

  slot :trailing

  def page_header(assigns) do
    ~H"""
    <div class={@class}>
      <div class="flex justify-between items-center mb-2">
        <h1 class="text-3xl font-bold">{@title}</h1>
        <%= if @trailing != [] do %>
          {render_slot(@trailing)}
        <% end %>
      </div>
      <%= if @subtitle do %>
        <p class="text-base-content/60 mb-8">{@subtitle}</p>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Admin Section Component
  # ============================================================================

  @doc """
  Renders a section container for admin pages with a bordered heading.

  ## Examples

      <.admin_section title="Grid Configuration">
        <p>Section content here...</p>
      </.admin_section>

      <.admin_section title="Danger Zone" title_class="text-error">
        <p>Dangerous controls here...</p>
      </.admin_section>

  """
  attr :title, :string, required: true
  attr :title_class, :string, default: nil
  attr :class, :string, default: "mb-10"

  slot :inner_block, required: true

  def admin_section(assigns) do
    ~H"""
    <section class={@class}>
      <h2 class={["text-xl font-semibold mb-4 border-b border-base-300 pb-2", @title_class]}>
        {@title}
      </h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  # ============================================================================
  # Station Button Component
  # ============================================================================

  @doc """
  Renders a station button with consistent styling based on status.

  This is the base button used by station modals. It handles the common
  styling patterns for available, occupied, broken, and reserved states.

  ## Examples

      <.station_button status={:available} station_number={5} />

      <.station_button status={:occupied} station_number={5} end_date={@end_date}>
        <:extra>
          <div class="text-xs" x-text="remaining"></div>
        </:extra>
      </.station_button>

  """
  attr :status, :atom, required: true, values: [:available, :occupied, :broken, :reserved]
  attr :station_number, :integer, required: true
  attr :end_date, DateTime, default: nil
  attr :clickable, :boolean, default: false
  attr :on_click, :string, default: nil
  attr :class, :string, default: nil

  slot :extra

  def station_button(assigns) do
    base_classes = "btn rounded-lg station-card h-full"

    status_classes =
      case assigns.status do
        :available -> "btn-success station-available"
        :occupied -> "btn-warning flex flex-col justify-center gap-0"
        :broken -> "btn-error"
        :reserved -> "btn-neutral"
      end

    assigns =
      assigns
      |> assign(:base_classes, base_classes)
      |> assign(:status_classes, status_classes)
      |> assign(
        :end_date_iso,
        if(assigns.end_date, do: DateTime.to_iso8601(assigns.end_date), else: nil)
      )
      |> assign(
        :end_date_unix,
        if(assigns.end_date, do: DateTime.to_unix(assigns.end_date), else: nil)
      )

    ~H"""
    <label
      class={[@base_classes, @status_classes, @class]}
      x-on:click={@on_click}
    >
      <%= if @status == :occupied do %>
        <div class="font-bold">{@station_number}</div>
        <%= if @extra != [] do %>
          {render_slot(@extra)}
        <% else %>
          <div
            id={"station-countdown-#{@station_number}-#{@end_date_unix}"}
            class="text-xs"
            x-data={"{ endTime: new Date('#{@end_date_iso}'), remaining: '', intervalId: null }"}
            x-init="
              const update = () => {
                const now = new Date();
                const diff = Math.max(0, endTime - now);
                const mins = Math.floor(diff / 60000);
                const secs = Math.floor((diff % 60000) / 1000);
                if (mins > 0) {
                  remaining = mins + 'm' + secs + 's';
                } else {
                  remaining = secs + 's';
                }
              };
              update();
              intervalId = setInterval(update, 1000);
            "
            @destroy="clearInterval(intervalId)"
            x-text="remaining"
          >
          </div>
        <% end %>
      <% else %>
        {@station_number}
      <% end %>
    </label>
    """
  end

  # ============================================================================
  # Modal Dialog Component
  # ============================================================================

  @doc """
  Renders a DaisyUI modal dialog with consistent styling.

  ## Examples

      <.modal id="station-modal-5" title="Station 5">
        <p>Modal content here...</p>
      </.modal>

  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :actions

  def modal(assigns) do
    ~H"""
    <dialog class="modal" x-ref={@id}>
      <div class={["modal-box", @class]}>
        <form method="dialog">
          <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
        </form>
        <h3 class="text-xl font-bold mb-4">{@title}</h3>
        {render_slot(@inner_block)}
        <%= if @actions != [] do %>
          <div class="modal-action">
            {render_slot(@actions)}
          </div>
        <% end %>
      </div>
    </dialog>
    """
  end

  # ============================================================================
  # Labeled Input Component
  # ============================================================================

  @doc """
  Renders a form input with a label in a horizontal layout.

  ## Examples

      <.labeled_input label="Columns" type="number" name="columns" value={@columns} min={1} />

      <.labeled_input label="Station #" type="number" name="station" placeholder="e.g. 15" />

  """
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :placeholder, :string, default: nil
  attr :min, :any, default: nil
  attr :max, :any, default: nil
  attr :step, :any, default: nil
  attr :required, :boolean, default: false
  attr :class, :string, default: nil
  attr :input_class, :string, default: "input input-bordered input-sm w-24"
  attr :label_class, :string, default: "text-sm text-base-content/70"
  attr :label_width, :string, default: "w-20"
  attr :rest, :global, include: ~w(phx-change phx-focus phx-blur phx-debounce autocomplete autofocus)

  def labeled_input(assigns) do
    ~H"""
    <label class={["flex items-center gap-3", @class]}>
      <span class={[@label_class, @label_width]}>{@label}</span>
      <input
        type={@type}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        min={@min}
        max={@max}
        step={@step}
        required={@required}
        class={@input_class}
        {@rest}
      />
    </label>
    """
  end

  # ============================================================================
  # Data Table Component
  # ============================================================================

  @doc """
  Renders a styled data table with consistent formatting.

  ## Examples

      <.data_table>
        <:header>
          <th>Name</th>
          <th>Status</th>
        </:header>
        <:row :for={item <- @items}>
          <td>{item.name}</td>
          <td>{item.status}</td>
        </:row>
      </.data_table>

  """
  attr :class, :string, default: nil

  slot :header, required: true
  slot :row, required: true

  def data_table(assigns) do
    ~H"""
    <div class={["overflow-x-auto border border-base-300 rounded-lg", @class]}>
      <table class="table">
        <thead>
          <tr class="border-b-2 border-base-300 bg-base-200">
            {render_slot(@header)}
          </tr>
        </thead>
        <tbody>
          {render_slot(@row)}
        </tbody>
      </table>
    </div>
    """
  end

  # ============================================================================
  # Theme Toggle Component
  # ============================================================================

  @doc """
  Renders a theme toggle button with animated sun/moon icons.

  Uses the theme-change library to toggle between light and dark themes,
  persisting the choice in localStorage.

  ## Examples

      <.theme_toggle />
      <.theme_toggle class="btn-ghost" />
  """
  attr :class, :string, default: "btn-ghost"
  attr :id, :string, default: "theme-toggle-desktop"

  def theme_toggle(assigns) do
    ~H"""
    <label class={["swap swap-rotate btn", @class]} id={@id} phx-hook="ThemeToggle">
      <input type="checkbox" class="theme-controller" value="dark" />
      <svg class="swap-off fill-current w-5 h-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <path d="M5.64,17l-.71.71a1,1,0,0,0,0,1.41,1,1,0,0,0,1.41,0l.71-.71A1,1,0,0,0,5.64,17ZM5,12a1,1,0,0,0-1-1H3a1,1,0,0,0,0,2H4A1,1,0,0,0,5,12Zm7-7a1,1,0,0,0,1-1V3a1,1,0,0,0-2,0V4A1,1,0,0,0,12,5ZM5.64,7.05a1,1,0,0,0,.7.29,1,1,0,0,0,.71-.29,1,1,0,0,0,0-1.41l-.71-.71A1,1,0,0,0,4.93,6.34Zm12,.29a1,1,0,0,0,.7-.29l.71-.71a1,1,0,1,0-1.41-1.41L17,5.64a1,1,0,0,0,0,1.41A1,1,0,0,0,17.66,7.34ZM21,11H20a1,1,0,0,0,0,2h1a1,1,0,0,0,0-2Zm-9,8a1,1,0,0,0-1,1v1a1,1,0,0,0,2,0V20A1,1,0,0,0,12,19ZM18.36,17A1,1,0,0,0,17,18.36l.71.71a1,1,0,0,0,1.41,0,1,1,0,0,0,0-1.41ZM12,6.5A5.5,5.5,0,1,0,17.5,12,5.51,5.51,0,0,0,12,6.5Zm0,9A3.5,3.5,0,1,1,15.5,12,3.5,3.5,0,0,1,12,15.5Z" />
      </svg>
      <svg class="swap-on fill-current w-5 h-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <path d="M21.64,13a1,1,0,0,0-1.05-.14,8.05,8.05,0,0,1-3.37.73A8.15,8.15,0,0,1,9.08,5.49a8.59,8.59,0,0,1,.25-2A1,1,0,0,0,8,2.36,10.14,10.14,0,1,0,22,14.05,1,1,0,0,0,21.64,13Zm-9.5,6.69A8.14,8.14,0,0,1,7.08,5.22v.27A10.15,10.15,0,0,0,17.22,15.63a9.79,9.79,0,0,0,2.1-.27A8.13,8.13,0,0,1,12.14,19.73Z" />
      </svg>
    </label>
    """
  end
end
