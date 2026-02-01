defmodule LanpartyseatingWeb.Settings.UsersLive do
  @moduledoc """
  Settings page for admin user management.
  Requires full user authentication (not badge auth).
  """
  use LanpartyseatingWeb, :live_view
  import LanpartyseatingWeb.Helpers, only: [format_datetime: 1]

  alias Lanpartyseating.Accounts
  alias LanpartyseatingWeb.Components.SettingsNav

  # ============================================================================
  # Mount & Handle Params
  # ============================================================================

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    # Redirect badge-auth users - they don't have access to user management
    if socket.assigns.is_user_auth do
      {:noreply, load_data(socket)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Full admin access required")
       |> push_navigate(to: ~p"/settings/seating", replace: true)}
    end
  end

  defp load_data(socket) do
    socket
    |> assign(:users, Accounts.list_users())
    |> assign(:show_create_form, false)
    |> assign(:form, to_form(%{"name" => "", "email" => "", "password" => ""}, as: "user"))
    |> assign(:form_error, nil)
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  def handle_event("toggle_create_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, !socket.assigns.show_create_form)
     |> assign(:form, to_form(%{"name" => "", "email" => "", "password" => ""}, as: "user"))
     |> assign(:form_error, nil)}
  end

  def handle_event("create_user", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:users, Accounts.list_users())
         |> assign(:show_create_form, false)
         |> assign(:form, to_form(%{"name" => "", "email" => "", "password" => ""}, as: "user"))
         |> assign(:form_error, nil)
         |> put_flash(:info, "User created successfully.")}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)

        {:noreply,
         socket
         |> assign(:form, to_form(user_params, as: "user"))
         |> assign(:form_error, error_msg)}
    end
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    if user.id == socket.assigns.current_scope.user.id do
      {:noreply, put_flash(socket, :error, "You cannot delete your own account.")}
    else
      case Accounts.delete_user(user) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:users, Accounts.list_users())
           |> put_flash(:info, "User deleted.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete user.")}
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end

  # ============================================================================
  # Render
  # ============================================================================

  def render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="settings-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content">
        <%!-- Mobile header with hamburger --%>
        <div class="lg:hidden navbar bg-base-200 border-b border-base-300">
          <label for="settings-drawer" class="btn btn-square btn-ghost">
            <Icons.menu />
          </label>
          <span class="text-lg font-bold">Users</span>
        </div>

        <%!-- Main content area --%>
        <div class="p-4 lg:p-6">
          <.users_content {assigns} />
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:users} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  defp users_content(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <.page_header title="Admin Users" subtitle="Manage admin user accounts with full access permissions.">
        <:trailing>
          <span class="text-base-content/60">{length(@users)} users</span>
        </:trailing>
      </.page_header>

      <.admin_section title="Create New User">
        <%= if @show_create_form do %>
          <.form for={@form} id="create-user-form" phx-submit="create_user" class="space-y-4">
            <%= if @form_error do %>
              <div class="alert alert-error">
                <Icons.x_circle class="w-6 h-6" />
                <span>{@form_error}</span>
              </div>
            <% end %>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Name</span>
              </label>
              <input
                type="text"
                name="user[name]"
                value={@form[:name].value}
                class="input input-bordered w-full max-w-md"
                required
                autocomplete="off"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Email</span>
              </label>
              <input
                type="email"
                name="user[email]"
                value={@form[:email].value}
                class="input input-bordered w-full max-w-md"
                required
                autocomplete="off"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Password (min 12 characters)</span>
              </label>
              <input
                type="password"
                name="user[password]"
                class="input input-bordered w-full max-w-md"
                required
                minlength="12"
                autocomplete="new-password"
              />
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">
                Create User
              </button>
              <button type="button" class="btn btn-ghost" phx-click="toggle_create_form">
                Cancel
              </button>
            </div>
          </.form>
        <% else %>
          <button class="btn btn-primary" phx-click="toggle_create_form">
            + Add User
          </button>
        <% end %>
      </.admin_section>

      <.admin_section title="Existing Users">
        <.data_table>
          <:header>
            <th class="text-base-content">ID</th>
            <th class="text-base-content">Name</th>
            <th class="text-base-content">Email</th>
            <th class="text-base-content">Created</th>
            <th class="text-base-content">Actions</th>
          </:header>
          <:row :for={user <- @users}>
            <tr class="hover:bg-base-200">
              <td class="text-base-content/50">{user.id}</td>
              <td>
                {user.name}
                <%= if user.id == @current_scope.user.id do %>
                  <span class="badge badge-info badge-sm ml-2">You</span>
                <% end %>
              </td>
              <td class="font-mono text-sm">{user.email}</td>
              <td class="text-sm">{format_datetime(user.inserted_at)}</td>
              <td>
                <%= if user.id != @current_scope.user.id do %>
                  <button
                    class="btn btn-error btn-sm"
                    phx-click="delete_user"
                    phx-value-id={user.id}
                    data-confirm="Are you sure you want to delete this user?"
                  >
                    Delete
                  </button>
                <% else %>
                  <span class="text-base-content/50 text-sm">-</span>
                <% end %>
              </td>
            </tr>
          </:row>
        </.data_table>
      </.admin_section>
    </div>
    """
  end
end
