defmodule LanpartyseatingWeb.Components.SeatMap do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :payload, :map, required: true
  attr :mode, :string, required: true
  attr :hook, :string, default: "SeatMapCanvas"
  attr :class, :string, default: nil
  attr :stage_class, :string, default: nil
  slot :toolbar
  slot :details

  def canvas(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook={@hook}
      data-mode={@mode}
      data-seat-map={Jason.encode!(@payload)}
      style="font-family: 'JetBrains Mono', 'SF Mono', ui-monospace, Menlo, monospace;"
      class={[
        "relative overflow-hidden border border-[#30363d] bg-[radial-gradient(ellipse_at_top,#161b22_0%,#0d1117_50%,#010409_100%)] shadow-[0_0_80px_rgba(0,0,0,0.8)]",
        @class
      ]}
    >
      <div data-seat-map-stage class={[@stage_class || "h-full w-full"]}></div>

      <div
        data-seat-map-minimap
        class="pointer-events-none absolute bottom-3 left-3 z-10 hidden rounded-lg border border-[#30363d] bg-[rgba(13,17,23,0.95)] p-2 shadow-[0_8px_32px_rgba(0,0,0,0.6)] backdrop-blur-sm"
      >
        <div class="mb-1.5 flex items-center justify-between gap-2">
          <span class="text-[0.6rem] font-semibold uppercase tracking-[0.2em] text-[#8b949e]">OVERVIEW</span>
          <span class="h-1.5 w-1.5 rounded-full bg-[#22c55e] shadow-[0_0_8px_rgba(34,197,94,0.6)]"></span>
        </div>
        <svg data-seat-map-minimap-svg class="h-24 w-36 overflow-hidden rounded border border-[#30363d] bg-[#0d1117]"></svg>
      </div>

      <div :if={@toolbar != []} class="pointer-events-none absolute inset-x-3 top-3 z-10 flex justify-between gap-3">
        <div class="pointer-events-auto flex flex-wrap items-center gap-2 rounded-lg border border-[#30363d] bg-[rgba(22,27,34,0.95)] px-3 py-2 shadow-[0_8px_32px_rgba(0,0,0,0.5)] backdrop-blur-sm">
          {render_slot(@toolbar)}
        </div>
      </div>

      <div :if={@details != []} class="pointer-events-none absolute inset-x-3 bottom-3 z-10 flex justify-end">
        <div class="pointer-events-auto w-full max-w-sm rounded-lg border border-[#30363d] bg-[rgba(22,27,34,0.98)] p-4 shadow-[0_12px_48px_rgba(0,0,0,0.6)] backdrop-blur-sm">
          {render_slot(@details)}
        </div>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil

  def legend(assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-2 text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-[#8b949e]", @class]}>
      <div class="flex items-center gap-1.5 rounded bg-[rgba(34,197,94,0.1)] px-2 py-1 border border-[rgba(34,197,94,0.3)]">
        <span class="h-2 w-2 rounded-full bg-[#22c55e] shadow-[0_0_6px_rgba(34,197,94,0.8)]"></span>
        <span class="text-[#4ade80]">Available</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-[rgba(245,158,11,0.1)] px-2 py-1 border border-[rgba(245,158,11,0.3)]">
        <span class="h-2 w-2 rounded-full bg-[#f59e0b] shadow-[0_0_6px_rgba(245,158,11,0.8)]"></span>
        <span class="text-[#fbbf24]">Occupied</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-[rgba(239,68,68,0.1)] px-2 py-1 border border-[rgba(239,68,68,0.3)]">
        <span class="h-2 w-2 rounded-full bg-[#ef4444] shadow-[0_0_6px_rgba(239,68,68,0.8)]"></span>
        <span class="text-[#f87171]">Unavailable</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-[rgba(6,182,212,0.1)] px-2 py-1 border border-[rgba(6,182,212,0.3)]">
        <span class="h-2 w-2 rounded-full bg-[#06b6d4] shadow-[0_0_6px_rgba(6,182,212,0.8)]"></span>
        <span class="text-[#22d3ee]">Tournament</span>
      </div>
      <div class="flex items-center gap-1.5 rounded bg-[rgba(107,114,128,0.1)] px-2 py-1 border border-[rgba(107,114,128,0.3)]">
        <span class="h-2 w-2 rounded-full bg-[#6b7280] shadow-[0_0_6px_rgba(107,114,128,0.6)]"></span>
        <span class="text-[#9ca3af]">Reserved</span>
      </div>
    </div>
    """
  end
end
