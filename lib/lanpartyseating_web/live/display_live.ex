defmodule LanpartyseatingWeb.DisplayLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.PubSub, as: PubSub
  alias Lanpartyseating.TournamentsLogic, as: TournamentsLogic
  alias Lanpartyseating.SettingsLogic, as: SettingsLogic
  alias Lanpartyseating.StationLogic, as: StationLogic

  def mount(_params, _session, socket) do
    settings = SettingsLogic.get_settings()
    tournaments = TournamentsLogic.get_all_daily_tournaments()

    Phoenix.PubSub.subscribe(PubSub, "update_stations")

    socket =
      socket
      |> assign(:columns, settings.columns)
      |> assign(:rows, settings.rows)
      |> assign(:col_trailing, settings.vertical_trailing)
      |> assign(:row_trailing, settings.horizontal_trailing)
      |> assign(:colpad, settings.column_padding)
      |> assign(:rowpad, settings.row_padding)
      |> assign(:stations, StationLogic.get_all_stations())
      |> assign(:tournaments, tournaments)
      |> assign(:tournamentsCount, length(tournaments))

    {:ok, socket}
  end

  def handle_info({:update_stations, stations}, socket) do
    {:noreply, assign(socket, :stations, stations)}
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Seats</h1>

      <div class="flex flex-wrap w-full">
        <%= for r <- 0..(@rows-1) do %>
          <div class={"#{if rem(r,@rowpad) == rem(@row_trailing, @rowpad) and @rowpad != 1, do: "mb-4", else: ""} flex flex-row w-full "}>
            <%= for c <- 0..(@columns-1) do %>
              <div class={"#{if rem(c,@colpad) == rem(@col_trailing, @colpad) and @colpad != 1, do: "mr-4", else: ""} flex flex-col h-14 flex-1 grow mx-1 "}>
                <DisplayModalComponent.modal station={@stations |> Enum.at(r * @columns + c)} />
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <h1 style="font-size:30px">Tournaments</h1>

      <div class="flex flex-wrap w-full">
        <div class="flex flex-row w-full " }>
          <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
            <h2><u>Name</u></h2>
          </div>
          <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
            <h2><u>Start Time</u></h2>
          </div>
          <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
            <h2><u>End Time</u></h2>
          </div>
        </div>
        <%= for tournament <- @tournaments do %>
          <div class="flex flex-row w-full" }>
            <div class="flex flex-col flex-1 mx-1 grow" }>
              <h3><%= tournament.name %></h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 grow" }>
              <h3>
                <%= Calendar.strftime(
                  tournament.start_date |> Timex.to_datetime("America/Montreal"),
                  "%y/%m/%d -> %H:%M"
                ) %>
              </h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 grow" }>
              <h3>
                <%= Calendar.strftime(
                  tournament.end_date |> Timex.to_datetime("America/Montreal"),
                  "%y/%m/%d -> %H:%M"
                ) %>
              </h3>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
