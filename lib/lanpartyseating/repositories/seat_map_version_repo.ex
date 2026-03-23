defmodule Lanpartyseating.SeatMapVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "seat_map_versions" do
    field :name, :string
    field :status, :string, default: "draft"
    field :width, :integer, default: 1920
    field :height, :integer, default: 1080
    field :background_kind, :string, default: "none"
    field :background_value, :string
    field :data, :map, default: %{}
    field :published_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :seat_map, Lanpartyseating.SeatMap
    has_many :team_assignments, Lanpartyseating.TournamentTeamAssignment

    timestamps()
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [
      :seat_map_id,
      :name,
      :status,
      :width,
      :height,
      :background_kind,
      :background_value,
      :data,
      :published_at,
      :deleted_at
    ])
    |> validate_required([:seat_map_id, :name, :status, :width, :height, :background_kind, :data])
    |> validate_inclusion(:status, ["draft", "published"])
    |> validate_inclusion(:background_kind, ["none", "image", "svg"])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
  end
end
