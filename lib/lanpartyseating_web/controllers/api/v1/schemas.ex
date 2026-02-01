defmodule LanpartyseatingWeb.Api.V1.Schemas do
  @moduledoc """
  OpenAPI schemas for API v1.
  """
  alias OpenApiSpex.Schema

  defmodule CancelRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CancelRequest",
      description: "Request body for cancelling a reservation by badge",
      type: :object,
      required: [:badge_uid],
      properties: %{
        badge_uid: %Schema{
          type: :string,
          description: "The badge UID (scanned value). Case-insensitive, will be uppercased.",
          example: "ABC123DEF456",
          minLength: 1,
          maxLength: 255,
        },
      },
    })
  end

  defmodule SuccessResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SuccessResponse",
      description: "Successful operation response",
      type: :object,
      required: [:status, :message],
      properties: %{
        status: %Schema{
          type: :string,
          description: "Status indicator",
          enum: ["ok"],
        },
        message: %Schema{
          type: :string,
          description: "Human-readable success message",
          example: "Reservation cancelled for station 15",
        },
      },
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "Error response",
      type: :object,
      required: [:status, :message],
      properties: %{
        status: %Schema{
          type: :string,
          description: "Status indicator",
          enum: ["error"],
        },
        message: %Schema{
          type: :string,
          description: "Human-readable error message",
          example: "No active reservation found for this badge",
        },
      },
    })
  end
end
