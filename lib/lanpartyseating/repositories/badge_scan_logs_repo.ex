defmodule Lanpartyseating.BadgeScanLogs do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "badge_scan_logs" do
    field :badge_number, :string
    field :date_scanned, :utc_datetime
    field :session_expiry, :utc_datetime
    field :assigned_station_number, :integer
    field :was_removed_from_ad, :boolean
    field :was_cancelled, :boolean
    field :date_cancelled, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:assigned_station_number, :assigned_station_number])
    |> validate_required([:assigned_station_number, :assigned_station_number])
  end
end
