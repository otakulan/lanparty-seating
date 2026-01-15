defmodule DisplayModalComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

  attr(:station, :any, required: true)
  attr(:status, :any, required: true)
  attr(:reservation, :any, required: true)

  def modal(assigns) do
    # status:
    # 1 - libre / available  (green: btn-success)
    # 2 - occupé / occupied (amber: btn-warning)
    # 3 - brisé / broken  (red: btn-error)
    # 4 - réserver pour un tournois / reserved for a tournament  (dark: btn-neutral)

    case assigns.status do
      :available ->
        ~H"""
        <label class="btn btn-success rounded-lg station-card station-available h-full">
          {assigns.station.station_number}
        </label>
        """

      :occupied ->
        # Get the end_date as ISO8601 for Alpine.js countdown
        assigns =
          assign(
            assigns,
            :end_date_iso,
            List.first(assigns.station.reservations).end_date
            |> DateTime.to_iso8601()
          )

        ~H"""
        <label
          class="btn btn-warning rounded-lg station-card flex flex-col h-full py-1"
          x-data={"{ endTime: new Date('#{assigns.end_date_iso}'), remaining: '' }"}
          x-init="
            const update = () => {
              const now = new Date();
              const diff = Math.max(0, endTime - now);
              const mins = Math.floor(diff / 60000);
              const secs = Math.floor((diff % 60000) / 1000);
              remaining = mins + ':' + secs.toString().padStart(2, '0');
            };
            update();
            setInterval(update, 1000);
          "
        >
          <div class="font-bold">{assigns.station.station_number}</div>
          <div class="text-xs" x-text="remaining"></div>
        </label>
        """

      :broken ->
        ~H"""
        <label class="btn btn-error rounded-lg station-card h-full">
          {assigns.station.station_number}
        </label>
        """

      :reserved ->
        ~H"""
        <label class="btn btn-neutral rounded-lg station-card h-full">
          {assigns.station.station_number}
        </label>
        """
    end
  end
end
