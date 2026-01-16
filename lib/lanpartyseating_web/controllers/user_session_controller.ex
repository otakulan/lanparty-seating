defmodule LanpartyseatingWeb.UserSessionController do
  use LanpartyseatingWeb, :controller

  alias Lanpartyseating.Accounts
  alias LanpartyseatingWeb.UserAuth

  def new(conn, _params) do
    form = Phoenix.Component.to_form(%{}, as: "user")
    render(conn, :new, form: form)
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> UserAuth.log_in_user(user, user_params)
    else
      form = Phoenix.Component.to_form(user_params, as: "user")

      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new, form: form)
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
