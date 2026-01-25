defmodule LanpartyseatingWeb.AdminBadgesLive do
  @moduledoc """
  LiveView for managing admin badges (emergency backdoor authentication).
  Only accessible with full user authentication (not badge auth).
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.Accounts

  def mount(_params, _session, socket) do
    badges = Accounts.list_admin_badges()

    socket =
      socket
      |> assign(:badges, badges)
      |> assign(:show_create_form, false)
      |> assign(:form, to_form(%{"badge_number" => "", "label" => "", "enabled" => "true"}, as: "badge"))
      |> assign(:form_error, nil)

    {:ok, socket}
  end

  def handle_event("toggle_create_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_form, !socket.assigns.show_create_form)
     |> assign(:form, to_form(%{"badge_number" => "", "label" => "", "enabled" => "true"}, as: "badge"))
     |> assign(:form_error, nil)}
  end

  def handle_event("create_badge", %{"badge" => badge_params}, socket) do
    # Convert "enabled" string to boolean
    badge_params = Map.put(badge_params, "enabled", badge_params["enabled"] == "true")

    case Accounts.create_admin_badge(badge_params) do
      {:ok, _badge} ->
        {:noreply,
         socket
         |> assign(:badges, Accounts.list_admin_badges())
         |> assign(:show_create_form, false)
         |> assign(:form, to_form(%{"badge_number" => "", "label" => "", "enabled" => "true"}, as: "badge"))
         |> assign(:form_error, nil)
         |> put_flash(:info, "Admin badge created successfully.")}

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
         |> assign(:form, to_form(badge_params, as: "badge"))
         |> assign(:form_error, error_msg)}
    end
  end

  def handle_event("toggle_badge", %{"id" => id}, socket) do
    badge = Accounts.get_admin_badge!(id)

    case Accounts.update_admin_badge(badge, %{enabled: !badge.enabled}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:badges, Accounts.list_admin_badges())
         |> put_flash(:info, "Badge #{if badge.enabled, do: "disabled", else: "enabled"}.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update badge.")}
    end
  end

  def handle_event("delete_badge", %{"id" => id}, socket) do
    badge = Accounts.get_admin_badge!(id)

    case Accounts.delete_admin_badge(badge) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:badges, Accounts.list_admin_badges())
         |> put_flash(:info, "Badge deleted.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete badge.")}
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
      <.page_header title="Admin Badges" subtitle="Manage admin badges for emergency backdoor access. Badge authentication has limited permissions.">
        <:trailing>
          <span class="text-base-content/60">{length(@badges)} badges</span>
        </:trailing>
      </.page_header>

      <.admin_section title="Create New Badge">
        <%= if @show_create_form do %>
          <.form for={@form} phx-submit="create_badge" class="space-y-4">
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
                <span class="label-text">Badge Number</span>
              </label>
              <input
                type="text"
                name="badge[badge_number]"
                value={@form[:badge_number].value}
                class="input input-bordered w-full max-w-md"
                placeholder="e.g. ADMIN-002"
                required
                autocomplete="off"
              />
              <label class="label">
                <span class="label-text-alt">This is what gets scanned or entered at login</span>
              </label>
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text">Label</span>
              </label>
              <input
                type="text"
                name="badge[label]"
                value={@form[:label].value}
                class="input input-bordered w-full max-w-md"
                placeholder="e.g. Tech Support"
                required
              />
              <label class="label">
                <span class="label-text-alt">Displayed in the nav when logged in</span>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-2">
                <input
                  type="checkbox"
                  name="badge[enabled]"
                  value="true"
                  checked={@form[:enabled].value == "true"}
                  class="checkbox"
                />
                <span class="label-text">Enabled</span>
              </label>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="btn btn-primary">
                Create Badge
              </button>
              <button type="button" class="btn btn-ghost" phx-click="toggle_create_form">
                Cancel
              </button>
            </div>
          </.form>
        <% else %>
          <button class="btn btn-primary" phx-click="toggle_create_form">
            + Add Badge
          </button>
        <% end %>
      </.admin_section>

      <.admin_section title="Existing Badges">
        <%= if Enum.empty?(@badges) do %>
          <p class="text-base-content/60">No badges configured.</p>
        <% else %>
          <.data_table>
            <:header>
              <th class="text-base-content">ID</th>
              <th class="text-base-content">Badge Number</th>
              <th class="text-base-content">Label</th>
              <th class="text-base-content">Status</th>
              <th class="text-base-content">Created</th>
              <th class="text-base-content">Actions</th>
            </:header>
            <:row :for={badge <- @badges}>
              <tr class="hover:bg-base-200">
                <td class="text-base-content/50">{badge.id}</td>
                <td class="font-mono font-semibold">{badge.badge_number}</td>
                <td>{badge.label}</td>
                <td>
                  <%= if badge.enabled do %>
                    <span class="badge badge-success">Enabled</span>
                  <% else %>
                    <span class="badge badge-error">Disabled</span>
                  <% end %>
                </td>
                <td class="text-sm">{format_datetime(badge.inserted_at)}</td>
                <td class="flex gap-1">
                  <button
                    class={["btn btn-sm", if(badge.enabled, do: "btn-warning", else: "btn-success")]}
                    phx-click="toggle_badge"
                    phx-value-id={badge.id}
                  >
                    {if badge.enabled, do: "Disable", else: "Enable"}
                  </button>
                  <button
                    class="btn btn-error btn-sm"
                    phx-click="delete_badge"
                    phx-value-id={badge.id}
                    data-confirm="Are you sure you want to delete this badge?"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </:row>
          </.data_table>
        <% end %>
      </.admin_section>

      <.admin_section title="Badge Permissions" title_class="text-warning">
        <div class="alert alert-warning">
          <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
          <div>
            <p class="font-bold">Badge authentication has limited permissions:</p>
            <ul class="list-disc list-inside mt-2">
              <li>Can access admin pages (Tournaments, Settings, Logs)</li>
              <li>Cannot manage users or badges (this page)</li>
              <li>Sessions are browser-only (no persistent login)</li>
            </ul>
          </div>
        </div>
      </.admin_section>
    </div>
    """
  end
end
