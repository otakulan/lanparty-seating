defmodule LanpartyseatingWeb.Components.SeatMap do
  use Phoenix.Component
  alias LanpartyseatingWeb.Components.UI

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
         * `:details` - Optional. Content rendered in the bottom details panel.
       """
  attr :id, :string, required: true
  attr :payload, :map, required: true
  attr :mode, :string, required: true
  attr :hook, :string, default: "SeatMapCanvas"
  attr :class, :string, default: nil
  attr :stage_class, :string, default: nil
  attr :pickable, :boolean, default: false
  attr :rest, :global

  slot :toolbar do
    attr :with_legend, :boolean
    attr :with_theme_toggle, :boolean
    attr :with_zoom_buttons, :boolean
  end

  slot :details

  def canvas(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook={@hook}
      data-mode={@mode}
      data-pickable={to_string(@pickable)}
      data-seat-map={Jason.encode!(@payload)}
      class={[
        "relative overflow-hidden border border-base-300 bg-base-100 shadow-xl font-mono",
        @class
      ]}
      {@rest}
    >
      <div data-seat-map-stage class={[@stage_class || "h-full w-full"]} tabindex="0" phx-ignore></div>

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

      <div
        :for={bar <- @toolbar}
        :if={@toolbar != []}
        class="pointer-events-none absolute inset-x-3 top-3 z-10 flex justify-between gap-3"
      >
        <div class="pointer-events-auto flex flex-wrap items-center gap-2 rounded-lg border border-base-300 bg-base-100/95 px-3 py-2 shadow-xl backdrop-blur-sm">
          <div class="flex flex-wrap items-center gap-2">
            <div class="flex items-center gap-2">
              <div class="h-2 w-2 rounded-full bg-success shadow-[0_0_8px_rgba(34,197,94,0.8)]"></div>
              <div>
                <h1 class="text-lg font-bold text-base-content">Sièges / Seating</h1>
              </div>
            </div>
            <%!-- Separator --%>
            <div class="h-6 w-px bg-base-300"></div>

            <%= if Map.get(bar, :with_zoom_buttons, false) do %>
              <div class="flex items-center gap-1">
                <button type="button" data-seat-map-command="zoom-out" class="btn btn-xs btn-ghost btn-square" title="Zoom out">
                  <.magnifying_glass_minus class="w-4 h-4" />
                </button>
                <button type="button" data-seat-map-command="zoom-in" class="btn btn-xs btn-ghost btn-square" title="Zoom in">
                  <.magnifying_glass_plus class="w-4 h-4" />
                </button>
                <button type="button" data-seat-map-command="reset-view" class="btn btn-xs btn-ghost btn-square" title="Fit to view">
                  <.arrows_pointing_in class="w-4 h-4" />
                </button>
              </div>
              <%!-- Separator --%>
              <div class="h-6 w-px bg-base-300"></div>
            <% end %>

            {render_slot(@toolbar)}

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

  attr :class, :string, default: nil

  def legend(assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-2 text-tiny font-semibold uppercase tracking-[0.18em] text-base-content/60", @class]}>
      <div class="flex items-center gap-1.5 rounded bg-success/10 px-2 py-1 border border-success/30">
        <span class="h-2 w-2 rounded-full bg-success shadow-[0_0_6px_rgba(34,197,94,0.8)]"></span>
        <span class="text-success">Available</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-warning/10 px-2 py-1 border border-warning/30">
        <span class="h-2 w-2 rounded-full bg-warning shadow-[0_0_6px_rgba(245,158,11,0.8)]"></span>
        <span class="text-warning">Occupied</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-error/10 px-2 py-1 border border-error/30">
        <span class="h-2 w-2 rounded-full bg-error shadow-[0_0_6px_rgba(239,68,68,0.8)]"></span>
        <span class="text-error">Unavailable</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-info/10 px-2 py-1 border border-info/30">
        <span class="h-2 w-2 rounded-full bg-info shadow-[0_0_6px_rgba(6,182,212,0.8)]"></span>
        <span class="text-info">Tournament</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-base-300/50 px-2 py-1 border border-base-300">
        <span class="h-2 w-2 rounded-full bg-base-content/50 shadow-[0_0_6px_rgba(107,114,128,0.6)]"></span>
        <span class="text-base-content/70">Reserved</span>
      </div>
    </div>
    """
  end

  # Icon helpers for this component
  attr :class, :string, default: "w-5 h-5"

  defp magnifying_glass_plus(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607ZM10.5 7.5v6m3-3h-6" />
    </svg>
    """
  end

  attr :class, :string, default: "w-5 h-5"

  defp magnifying_glass_minus(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607ZM7.5 10.5h6" />
    </svg>
    """
  end

  attr :class, :string, default: "w-5 h-5"

  defp arrows_pointing_in(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <path stroke-linecap="round" stroke-linejoin="round" d="M9 9V4.5M9 9H4.5M9 9 3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5 5.25 5.25" />
    </svg>
    """
  end
end
