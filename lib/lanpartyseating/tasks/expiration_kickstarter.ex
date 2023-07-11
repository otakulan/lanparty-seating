defmodule Lanpartyseating.ExpirationKickstarter do
  use Task
  import Ecto.Query
  alias Lanpartyseating.ExpireReservation, as: ExpireReservation
  alias Lanpartyseating.Reservation, as: Reservation
  alias Lanpartyseating.Repo, as: Repo

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    from(r in Reservation,
      where: r.end_date > ^now,
      where: r.start_date < ^now,
      where: is_nil(r.deleted_at)
    )
    |> Repo.all()
    |> Enum.each(fn res ->
      expiry_time = DateTime.diff(res.end_date, now, :millisecond)

      Task.Supervisor.start_child(
        Lanpartyseating.ExpirationTaskSupervisor,
        ExpireReservation,
        :run,
        [{expiry_time, res.id}]
      )
    end)
  end
end
