defmodule Lanpartyseating.ExpirationKickstarter do
  use Task
  import Ecto.Query
  require Logger
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Tournament, as: Tournament
  alias Lanpartyseating.Repo, as: Repo

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    Logger.debug("Starting reservation expiration tasks")

    from(r in Reservation,
      where: r.end_date > ^now,
      where: r.start_date < ^now,
      where: is_nil(r.deleted_at)
    )
    |> Repo.all()
    |> Enum.each(fn res ->
      DynamicSupervisor.start_child(
        Lanpartyseating.ExpirationTaskSupervisor,
        {Lanpartyseating.Tasks.ExpireReservation, {res.end_date, res.id}}
      )
    end)

    Logger.debug("Starting tournament start tasks")

    from(t in Tournament,
      where: t.start_date > ^now,
      where: is_nil(t.deleted_at)
    )
    |> Repo.all()
    |> Enum.each(fn tournament ->
      DynamicSupervisor.start_child(
        Lanpartyseating.ExpirationTaskSupervisor,
        {Lanpartyseating.Tasks.StartTournament, {tournament.start_date, tournament.id}}
      )
    end)

    Logger.debug("Starting tournament expiration tasks")

    from(t in Tournament,
      where: t.end_date > ^now,
      where: is_nil(t.deleted_at)
    )
    |> Repo.all()
    |> Enum.each(fn tournament ->
      DynamicSupervisor.start_child(
        Lanpartyseating.ExpirationTaskSupervisor,
        {Lanpartyseating.Tasks.ExpireTournament, {tournament.end_date, tournament.id}}
      )
    end)
  end
end
