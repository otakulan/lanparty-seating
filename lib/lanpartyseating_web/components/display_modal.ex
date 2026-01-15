defmodule DisplayModalComponent do
  use Phoenix.Component
  import LanpartyseatingWeb.Components.UI, only: [station_button: 1]

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
        <.station_button status={:available} station_number={@station.station_number} class="w-full" />
        """

      :occupied ->
        assigns =
          assign(assigns, :end_date, List.first(assigns.station.reservations).end_date)

        ~H"""
        <.station_button status={:occupied} station_number={@station.station_number} end_date={@end_date} class="w-full" />
        """

      :broken ->
        ~H"""
        <.station_button status={:broken} station_number={@station.station_number} class="w-full" />
        """

      :reserved ->
        ~H"""
        <.station_button status={:reserved} station_number={@station.station_number} class="w-full" />
        """
    end
  end
end
