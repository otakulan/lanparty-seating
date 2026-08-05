defmodule LanpartyseatingWeb.SetupController do
  @moduledoc """
             Handles the only step of the onboarding wizard that must write to the browser session:
             creating the first admin account and logging them in.

             ## Why a controller and not the LiveView?

             LiveViews communicate over a websocket, which does not carry the Plug session, so a
             LiveView cannot set `:user_token` (the cookie is only minted on a normal HTTP
             response). The account form therefore submits as a regular HTTP `POST` to this
             controller. We create the admin via `OnboardingLogic.create_admin/1` and then delegate
             the actual session write to `UserAuth.log_in_user/2`, which redirects back to `/setup`.
             The LiveView then resumes at the room step because the setup state has already advanced.

             ## State guard

             This endpoint is only meaningful before the admin account exists. It is therefore
             rejected unless `OnboardingLogic.state()` is `:not_started` (account not yet created)
             or `:admin_created` (created but the login POST was not completed). Any later state
             means onboarding has moved on, so we bounce back to `/setup`.
             """
  use LanpartyseatingWeb, :controller

  alias Lanpartyseating.OnboardingLogic
  alias LanpartyseatingWeb.UserAuth

  def login(conn, %{"user" => user_params}) do
    unless state_allows_login?() do
      conn
      |> put_flash(:error, "Setup has already progressed past account creation.")
      |> redirect(to: ~p"/setup")
    end

    case OnboardingLogic.create_admin(user_params) do
      {:ok, user} ->
        conn
        |> Plug.Conn.put_session(:user_return_to, to_string(~p"/setup"))
        |> UserAuth.log_in_user(user, user_params)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, format_changeset_errors(changeset))
        |> redirect(to: ~p"/setup")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Could not create account: #{inspect(reason)}")
        |> redirect(to: ~p"/setup")
    end
  end

  defp state_allows_login? do
    OnboardingLogic.state() in [:not_started, :admin_created]
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(
      changeset,
      fn {msg, opts} ->
        Regex.replace(
          ~r"%{(\w+)}",
          msg,
          fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end
        )
      end
    )
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
