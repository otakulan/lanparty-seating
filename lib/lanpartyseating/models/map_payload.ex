defmodule Lanpartyseating.Models.MapPayload do
  @doc """
  Represents the payload structure for the seat map data, including all necessary information about seats, layout, and metadata.
  """
  @derive Jason.Encoder
  defstruct id: nil,
            name: nil,
            status: nil,
            width: 0,
            height: 0,
            background_kind: "none",
            background_value: nil,
            meta: nil,
            seats: [],
            objects: [],
            groups: [],
            team_assignments: [],
            revision: 0,
            published_revision: nil

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          status: String.t(),
          width: integer(),
          height: integer(),
          background_kind: String.t(),
          background_value: String.t() | nil,
          meta: map(),
          seats: list(map()),
          objects: list(map()),
          groups: list(map()),
          team_assignments: list(map()),
          revision: integer(),
          published_revision: integer() | nil
        }
end
