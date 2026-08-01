defmodule LanpartyseatingWeb.Components.SeatMap do
  use LanpartyseatingWeb, :html

  @doc """
  A seat map canvas component that renders an interactive Konva.js-based seat map.

  ## Attributes

    * `:id` - Required. Unique identifier for the container element.
    * `:payload` - Required. Map containing seat map data (seats, labels, version info).
    * `:mode` - Required. Rendering mode (`:view`, `:kiosk`, or `:edit`).
    * `:hook` - Optional. Name of the Phoenix hook to attach (default: "SeatMapCanvas").
    * `:class` - Optional. CSS classes to apply to the container.
    * `:stage_class` - Optional. CSS classes for the stage container.
    * `:pickable` - Optional. When true, seats are clickable to show details.
    * `:rest` - Global attributes passed through to the container.

  ## Slots

    * `:toolbar` - Optional. Content rendered in the top toolbar area.
      - `:with_legend` - When true, includes the status legend.
      - `:with_theme_toggle` - When true, includes the theme toggle button.
      - `:with_zoom_buttons` - When true, includes zoom in/out buttons.
      - `:with_available_count` - When provided, shows the count of available/total seats from a tuple like `{available, total}`.
    * `:details` - Optional. Content rendered in the bottom details panel.
  """
  attr :id, :string, required: true
  attr :payload, :map, default: nil
  attr :mode, :string, required: true
  attr :hook, :string, default: "SeatMapCanvas"
  attr :class, :string, default: nil
  attr :stage_class, :string, default: nil
  attr :pickable, :boolean, default: false
  attr :background_kind, :string, default: "none"
  attr :background_value, :string, default: nil
  attr :rest, :global

  slot :toolbar do
    attr :with_legend, :boolean
    attr :with_theme_toggle, :boolean
    attr :with_zoom_buttons, :boolean
    attr :with_available_count, :any # tuple
  end

  slot :details

  def canvas(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook={@hook}
      data-mode={@mode}
      data-pickable={to_string(@pickable)}
      class={[
        "relative overflow-hidden border border-base-300 bg-base-100 shadow-xl font-mono",
        @class
      ]}
      {@rest}
    >
      <.background {assigns} />

      <div data-seat-map-stage class={[@stage_class || "h-full w-full"]} tabindex="0" phx-ignore></div>

      <.minimap {assigns} />

      <div
        :for={bar <- @toolbar}
        :if={@toolbar != []}
        class="pointer-events-none absolute inset-x-3 top-3 z-10 flex"
      >
        <div class="pointer-events-auto flex rounded-lg border border-base-300 bg-base-100/95 px-3 py-2 shadow-xl backdrop-blur-sm">
          <div class="flex flex-wrap items-center gap-2">
            <div class="flex items-center gap-2">
              <div>
                <h1 class="flex flex-nowrap shrink-0 gap-1 text-lg font-bold text-base-content">
                  <span>Sièges</span>
                  <span>/</span>
                  <span class="text-base-content/60">Seating</span>
                </h1>
              </div>
            </div>
            <div class="divider divider-horizontal m-0"></div>

            <%= if has_seat_count?(bar) do %>
              <div class="flex flex-nowrap shrink-0 items-center gap-3">
                <div class="flex flex-col items-center justify-center">
                  <span class="text-sm font-bold text-success leading-none tabular-nums">{get_available_seats(bar)}</span>
                  <span class="w-full border-t border-base-content/40 my-[0.2rem]"></span>
                  <span class="text-sm leading-none tabular-nums">{get_total_seats(bar)}</span>
                </div>
                <div class="flex flex-col leading-tight justify-center items-center">
                  <span class="text-xs font-semibold text-base-content">disponibles</span>
                  <span class="text-xs text-base-content/60">available</span>
                </div>
              </div>
            <% end %>

            <%= if Map.get(bar, :with_zoom_buttons, false) do %>
              <div class="flex items-center gap-1">
                <button type="button" data-seat-map-command="zoom-out" class="btn btn-xs btn-square" title="Zoom out">
                  <Icons.zoom_out class="w-4 h-4" />
                </button>
                <button type="button" data-seat-map-command="zoom-in" class="btn btn-xs btn-square" title="Zoom in">
                  <Icons.zoom_in class="w-4 h-4" />
                </button>
                <button type="button" data-seat-map-command="reset-view" class="btn btn-xs btn-square" title="Fit to view">
                  <Icons.move class="w-4 h-4" />
                </button>
              </div>
              <div class="divider divider-horizontal m-0"></div>
            <% end %>

            {render_slot(@toolbar)}
            <div class="divider divider-horizontal m-0"></div>

            <%= if Map.get(bar, :with_legend, false) do %>
              <.legend class="hidden lg:flex" />
            <% end %>

            <%= if Map.get(bar, :with_theme_toggle, false) do %>
              <div class="ml-auto">
                <UI.theme_toggle class="btn-sm btn-ghost" />
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <div :if={@details != []} class="pointer-events-none absolute inset-x-3 bottom-3 z-10 flex justify-end">
        <div class="pointer-events-auto w-full max-w-sm rounded-lg border border-base-300 bg-base-100/98 p-4 shadow-2xl backdrop-blur-sm">
          {render_slot(@details)}
        </div>
      </div>
    </div>
    """
  end

  @doc """

  """
  attr :class, :string, default: nil

  def legend(assigns) do
    ~H"""
    <div class={["flex flex-wrap gap-2 text-tiny font-semibold uppercase text-base-content/60", @class]}>
      <div class="flex items-baseline gap-1.5 rounded bg-success/10 px-2 py-1 border border-success/30">
        <span class="status status-success shadow-[0_0_6px_var(--color-success)]/[0.8]"></span>
        <span class="text-success">Disponible / Available</span>
      </div>
      <div class="flex items-baseline gap-1.5 rounded bg-warning/10 px-2 py-1 border border-warning/30">
        <span class="status status-warning shadow-[0_0_6px_var(--color-warning)]/[0.8]"></span>
        <span class="text-warning">Occupé / Occupied</span>
      </div>
      <div class="flex items-baseline gap-1.5 rounded bg-error/10 px-2 py-1 border border-error/30">
        <span class="status status-error shadow-[0_0_6px_var(--color-error)]/[0.8]"></span>
        <span class="text-error">Hors service / Unavailable</span>
      </div>
      <div class="flex items-baseline gap-1.5 rounded bg-info/10 px-2 py-1 border border-info/30">
        <span class="status status-info shadow-[0_0_6px_var(--color-info)]/[0.8]"></span>
        <span class="text-info">Tournoi / Tournament</span>
      </div>
      <div class="flex items-baseline gap-1.5 rounded bg-fuchsia-400/10 px-2 py-1 border border-fuchsia-400/30">
        <span class="status bg-fuchsia-400 shadow-[0_0_6px_var(--color-fuchsia-400)]/[0.6]"></span>
        <span class="text-fuchsia-400">Réservé / Reserved</span>
      </div>
    </div>
    """
  end

  defp background(assigns) do
    ~H"""
    <%!-- Checkerd background --%>
    <div class="absolute inset-0 pointer-events-none">
      <div class="absolute inset-0 bg-linear-to-br from-base-100 to-base-200"></div>
      <svg class="absolute inset-0 h-full w-full opacity-70">
        <defs>
          <pattern id={"grid-#{@id}"} width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" class="stroke-base-content/20 dark:stroke-base-content/70" stroke-width="0.5" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill={"url(#grid-#{@id})"} />
      </svg>
      <%= if @background_kind == "svg" and @background_value do %>
        <img src={@background_value} class="absolute inset-0 h-full w-full object-contain opacity-15" alt="" />
      <% end %>
    </div>
    """
  end

  defp minimap(assigns) do
    ~H"""
    <div
      data-seat-map-minimap
      class="pointer-events-none absolute bottom-3 left-3 z-10 hidden rounded-lg border border-base-300 bg-base-200/95 p-2 shadow-xl backdrop-blur-sm"
    >
      <div class="mb-1.5 flex items-center justify-between gap-2">
        <span class="text-tiny font-semibold uppercase tracking-[0.2em] text-base-content/60">OVERVIEW</span>
        <span class="h-1.5 w-1.5 rounded-full bg-success shadow-[0_0_8px_rgba(34,197,94,0.6)]"></span>
      </div>
      <svg data-seat-map-minimap-svg class="h-24 w-36 overflow-hidden rounded border border-base-300 bg-base-300"></svg>
    </div>
    """
  end

  defp has_seat_count?(bar), do: Map.has_key?(bar, :with_available_count)

  defp get_available_seats(bar) do
    case Map.get(bar, :with_available_count) do
      {available, _total} -> available
      _ -> nil
    end
  end

  defp get_total_seats(bar) do
    case Map.get(bar, :with_available_count) do
      {_available, total} -> total
      _ -> nil
    end
  end
end
