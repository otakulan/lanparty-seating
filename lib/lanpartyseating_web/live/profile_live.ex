defmodule LanpartyseatingWeb.ProfileLive do
  @moduledoc """
  LiveView for user profile settings.
  Allows users to update their name.
  Only accessible with full user authentication (not badge auth).
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:user, user)
      |> assign(:name_form, to_form(Accounts.change_user_name(user), as: "user"))
      |> assign(:name_saved, false)

    {:ok, socket}
  end

  def handle_event("validate_name", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_name(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :name_form, to_form(changeset, as: "user"))}
  end

  def handle_event("save_name", %{"user" => user_params}, socket) do
    case Accounts.update_user_name(socket.assigns.user, user_params) do
      {:ok, user} ->
        # Update current_scope with new user data so navbar updates immediately
        updated_scope = %{socket.assigns.current_scope | user: user}

        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:current_scope, updated_scope)
         |> assign(:name_form, to_form(Accounts.change_user_name(user), as: "user"))
         |> assign(:name_saved, true)
         |> put_flash(:info, "Name updated successfully. / Nom mis à jour avec succès.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :name_form, to_form(changeset, as: "user"))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto max-w-2xl">
      <.page_header title="Profile / Profil" subtitle="Manage your account settings. / Gérez les paramètres de votre compte." />

      <.admin_section title="Name / Nom">
        <.form
          for={@name_form}
          phx-change="validate_name"
          phx-submit="save_name"
          class="space-y-4"
        >
          <div class="form-control">
            <label class="label">
              <span class="label-text">Display Name / Nom d'affichage</span>
            </label>
            <input
              type="text"
              name="user[name]"
              value={@name_form[:name].value}
              class={"input input-bordered w-full max-w-md #{if @name_form[:name].errors != [], do: "input-error"}"}
              required
              phx-debounce="300"
            />
            <%= if @name_form[:name].errors != [] do %>
              <label class="label">
                <span class="label-text-alt text-error">
                  {Enum.map(@name_form[:name].errors, fn {msg, _} -> msg end) |> Enum.join(", ")}
                </span>
              </label>
            <% end %>
          </div>

          <button type="submit" class="btn btn-primary" disabled={not @name_form.source.valid?}>
            Save Name / Enregistrer
          </button>
        </.form>
      </.admin_section>

      <.admin_section title="Account Information / Informations du compte">
        <div class="space-y-2">
          <p><strong>Email:</strong> {@user.email}</p>
          <p class="text-sm text-base-content/60">
            To change your email or password, please contact an administrator. <br /> Pour modifier votre email ou mot de passe, veuillez contacter un administrateur.
          </p>
        </div>
      </.admin_section>
    </div>
    """
  end
end
