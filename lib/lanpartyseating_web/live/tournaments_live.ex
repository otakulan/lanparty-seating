defmodule LanpartyseatingWeb.TournamentsLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.TournamentsLogic, as: TournamentsLogic

  def mount(_params, _session, socket) do
    tournaments = TournamentsLogic.get_all_tournaments()

    socket =
      socket
      |> assign(:tournaments, tournaments)
      |> assign(:tournamentsCount, length(tournaments))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
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
          <div class="flex flex-row w-full " }>
            <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
              <h3>
                <%= tournament.name %>
              </h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
              <h3>
                <%= Calendar.strftime(
                  tournament.start_date |> Timex.to_datetime("America/Montreal"),
                  "%y/%m/%d -> %H:%M"
                ) %>
              </h3>
            </div>
            <div class="flex flex-col flex-1 mx-1 h-14 grow" }>
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
