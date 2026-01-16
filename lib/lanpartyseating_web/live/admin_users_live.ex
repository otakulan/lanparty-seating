defmodule LanpartyseatingWeb.AdminUsersLive do
  @moduledoc """
  LiveView for managing admin users.
  Only accessible with full user authentication (not badge auth).
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.Accounts

  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    socket =
      socket
      |> assign(:users, users)
      |> assign(:show_create_form, false)
      |> assign(:form, to_form(%{"email" => "", "password" => ""}, as: "user"))
      |> assign(:form_error, nil)

    {:ok, socket}
  end

  def handle_event("toggle_create_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, !socket.assigns.show_create_form)
     |> assign(:form, to_form(%{"email" => "", "password" => ""}, as: "user"))
     |> assign(:form_error, nil)}
  end

  def handle_event("create_user", %{"user" => user_params}, socket) do
    case Accounts.create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:users, Accounts.list_users())
         |> assign(:show_create_form, false)
         |> assign(:form, to_form(%{"email" => "", "password" => ""}, as: "user"))
         |> assign(:form_error, nil)
         |> put_flash(:info, "User created successfully.")}

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        error_msg =
          errors
          |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
          |> Enum.join("; ")

        {:noreply,
         socket
         |> assign(:form, to_form(user_params, as: "user"))
         |> assign(:form_error, error_msg)}
    end
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    # Prevent self-deletion
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

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    dt
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.shift_zone!("America/Montreal")
    |> Calendar.strftime("%Y-%m-%d %H:%M")
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto max-w-4xl">
      <.page_header title="Admin Users" subtitle="Manage admin user accounts with full access permissions.">
        <:trailing>
          <span class="text-base-content/60">{length(@users)} users</span>
        </:trailing>
      </.page_header>

      <.admin_section title="Create New User">
        <%= if @show_create_form do %>
          <.form for={@form} phx-submit="create_user" class="space-y-4">
            <%= if @form_error do %>
              <div class="alert alert-error">
                <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span>{@form_error}</span>
              </div>
            <% end %>

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
            <th class="text-base-content">Email</th>
            <th class="text-base-content">Created</th>
            <th class="text-base-content">Actions</th>
          </:header>
          <:row :for={user <- @users}>
            <tr class="hover:bg-base-200">
              <td class="text-base-content/50">{user.id}</td>
              <td class="font-mono">
                {user.email}
                <%= if user.id == @current_scope.user.id do %>
                  <span class="badge badge-info badge-sm ml-2">You</span>
                <% end %>
              </td>
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
