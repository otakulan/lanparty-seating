defmodule LanpartyseatingWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the LAN Party Seating API.
  """
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "LAN Party Seating API",
        version: "1.0.0",
        description: """
        API for external badge scanners to cancel seat reservations.

        ## Authentication

        All endpoints require Bearer token authentication. Tokens are generated when
        creating a badge scanner in the admin interface and are only shown once.

        Include the token in the Authorization header:
        ```
        Authorization: Bearer lpss_<token>
        ```
        """,
      },
      servers: [
        %Server{url: "/api/v1", description: "API v1"},
      ],
      paths: Paths.from_router(LanpartyseatingWeb.Router),
      components: %Components{
        securitySchemes: %{
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "opaque",
            description: "Scanner authentication token (lpss_... prefix)",
          },
        },
      },
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
