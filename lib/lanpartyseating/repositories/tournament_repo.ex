defmodule Lanpartyseating.Tournament do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "tournaments" do
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :name, :string
    field :deleted_at, :utc_datetime
    has_many :tournament_reservations, Lanpartyseating.TournamentReservation
    timestamps()
  end

  @doc false
  def changeset(tournament, attrs) do
    tournament
    |> cast(attrs, [:start_date, :end_date, :name, :deleted_at])
    |> validate_required([:start_date, :end_date, :name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_end_date_after_start_date()
  end

  defp validate_end_date_after_start_date(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && DateTime.compare(end_date, start_date) != :gt do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
  end
end
