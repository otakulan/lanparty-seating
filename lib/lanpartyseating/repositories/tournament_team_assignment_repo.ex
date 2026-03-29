defmodule Lanpartyseating.TournamentTeamAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournament_team_assignments" do
    field :group_id, :string
    field :team_name, :string
    field :color, :string
    field :label_x, :integer
    field :label_y, :integer
    field :deleted_at, :utc_datetime

    belongs_to :tournament, Lanpartyseating.Tournament
    belongs_to :seat_map_version, Lanpartyseating.SeatMapVersion

    timestamps()
  end

  def changeset(team_assignment, attrs) do
    team_assignment
    |> cast(attrs, [
      :tournament_id,
      :seat_map_version_id,
      :group_id,
      :team_name,
      :color,
      :label_x,
      :label_y,
      :deleted_at,
    ])
    |> validate_required([:tournament_id, :seat_map_version_id, :group_id, :team_name])
    |> validate_length(:group_id, min: 1, max: 255)
    |> validate_length(:team_name, min: 1, max: 255)
  end
end
