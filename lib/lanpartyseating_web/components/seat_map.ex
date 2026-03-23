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
      style="font-family: 'SF Pro Display', 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif;"
      class={[
        "relative overflow-hidden rounded-[36px] border border-white/70 bg-[radial-gradient(circle_at_top,#fffdf9_0%,#f8f4ec_45%,#efe8db_100%)] shadow-[0_32px_120px_rgba(53,41,28,0.16)] ring-1 ring-[#d8ccbc]/70",
        @class
      ]}
    >
      <div data-seat-map-stage class={[@stage_class || "h-full w-full"]}></div>

      <div
        data-seat-map-minimap
        class="pointer-events-none absolute bottom-4 left-4 z-10 hidden rounded-[24px] border border-white/80 bg-white/78 p-3 shadow-[0_18px_50px_rgba(54,40,26,0.14)] backdrop-blur-xl"
      >
        <div class="mb-2 flex items-center justify-between gap-3">
          <p class="text-[0.58rem] font-semibold uppercase tracking-[0.28em] text-[#8b6f52]">Overview</p>
          <div class="h-2 w-2 rounded-full bg-[#86a89b]"></div>
        </div>
        <svg data-seat-map-minimap-svg class="h-28 w-40 overflow-hidden rounded-[16px] border border-[#e4d8c8]/80 bg-[rgba(255,255,255,0.55)]"></svg>
      </div>

      <div :if={@toolbar != []} class="pointer-events-none absolute inset-x-4 top-4 z-10 flex justify-between gap-4">
        <div class="pointer-events-auto flex flex-wrap items-center gap-2 rounded-[28px] border border-white/80 bg-white/78 px-3 py-3 shadow-[0_20px_60px_rgba(54,40,26,0.14)] backdrop-blur-xl">
          {render_slot(@toolbar)}
        </div>
      </div>

      <div :if={@details != []} class="pointer-events-none absolute inset-x-4 bottom-4 z-10 flex justify-end">
        <div class="pointer-events-auto w-full max-w-sm rounded-[30px] border border-white/80 bg-white/82 p-5 shadow-[0_28px_80px_rgba(54,40,26,0.16)] backdrop-blur-xl">
          {render_slot(@details)}
        </div>
      </div>
    </div>
    """
  end

  attr :class, :string, default: nil

  def legend(assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-2.5 text-[11px] font-semibold uppercase tracking-[0.24em] text-[#42525c]", @class]}>
      <div class="flex items-center gap-2 rounded-full bg-white/65 px-3 py-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#7aa48e]"></span>Libre / Available</div>
      <div class="flex items-center gap-2 rounded-full bg-white/65 px-3 py-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#f1bf4b]"></span>Reservee jusqu'a / Reserved until</div>
      <div class="flex items-center gap-2 rounded-full bg-white/65 px-3 py-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#cb6672]"></span>Indisponible / Unavailable</div>
      <div class="flex items-center gap-2 rounded-full bg-white/65 px-3 py-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#4b88a7]"></span>Tournoi / Tournament</div>
      <div class="flex items-center gap-2 rounded-full bg-white/65 px-3 py-1.5"><span class="h-2.5 w-2.5 rounded-full bg-[#667684]"></span>Bloquee / Locked</div>
    </div>
    """
  end
end
