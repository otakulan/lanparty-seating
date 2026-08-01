defmodule Lanpartyseating.SeatMapVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "seat_map_versions" do
    field :name, :string
    field :status, :string, default: "draft"
    field :revision, :integer, default: 1
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

  @doc """
       Full changeset for content saves (save_draft, reset_draft). Includes optimistic
       locking on `revision` — Ecto will add `WHERE revision = N` to the UPDATE and
       increment the column automatically, raising `Ecto.StaleEntryError` on conflict.
       """
  def changeset(version, attrs) do
    version
    |> cast(
      attrs,
      [
        :seat_map_id,
        :name,
        :status,
        :revision,
        :width,
        :height,
        :background_kind,
        :background_value,
        :data,
        :published_at,
        :deleted_at,
      ]
    )
    |> optimistic_lock(:revision)
    |> validate_required([:seat_map_id, :name, :status, :width, :height, :background_kind, :data])
    |> validate_inclusion(:status, ["draft", "published"])
    |> validate_inclusion(:background_kind, ["none", "image", "svg"])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
  end

  @doc """
       Content changeset used inside the publish transaction. Casts data fields
       (data, width, height, background) without optimistic locking — the revision
       check is enforced explicitly via a WHERE clause in the Multi.
       """
  def save_data_changeset(version, attrs) do
    version
    |> cast(
      attrs,
      [
        :seat_map_id,
        :name,
        :status,
        :width,
        :height,
        :background_kind,
        :background_value,
        :data,
        :published_at,
        :deleted_at,
      ]
    )
    |> validate_required([:seat_map_id, :name, :status, :width, :height, :background_kind, :data])
    |> validate_inclusion(:status, ["draft", "published"])
    |> validate_inclusion(:background_kind, ["none", "image", "svg"])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
  end

  @doc """
       Status-only changeset for the publish flow. Does NOT touch the revision so that
       the revision number of a published version equals the revision it had as a draft.
       """
  def status_changeset(version, attrs) do
    version
    |> cast(attrs, [:status, :published_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, ["draft", "published"])
  end
end
