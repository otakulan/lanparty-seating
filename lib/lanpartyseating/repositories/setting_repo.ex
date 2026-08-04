defmodule Lanpartyseating.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: false}

  schema "settings" do
    field :row_padding, :integer
    field :column_padding, :integer
    field :reservation_duration_minutes, :integer
    field :tournament_buffer_minutes, :integer
    field :seat_picking_enabled_in_kiosk, :boolean, default: false

    belongs_to :active_room, Lanpartyseating.Room,
      foreign_key: :active_room_id,
      references: :id,
      on_replace: :nilify

    timestamps()
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [
      :row_padding,
      :column_padding,
      :reservation_duration_minutes,
      :tournament_buffer_minutes,
      :seat_picking_enabled_in_kiosk,
      :active_room_id
    ])
    |> validate_number(:row_padding, greater_than_or_equal_to: 0)
    |> validate_number(:column_padding, greater_than_or_equal_to: 0)
    |> validate_number(:reservation_duration_minutes, greater_than_or_equal_to: 5, less_than_or_equal_to: 480)
    |> validate_number(:tournament_buffer_minutes, greater_than_or_equal_to: 5, less_than_or_equal_to: 480)
    |> validate_inclusion(:seat_picking_enabled_in_kiosk, [true, false])
  end
end
