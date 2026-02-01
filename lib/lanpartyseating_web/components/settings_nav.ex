defmodule LanpartyseatingWeb.Components.SettingsNav do
  @moduledoc """
  Shared sidebar navigation component for settings pages.
  """
  use Phoenix.Component
  use LanpartyseatingWeb, :verified_routes

  alias LanpartyseatingWeb.Components.Icons

  @doc """
  Renders the settings sidebar navigation.

  ## Attributes

    * `:current_page` - The current page atom (:seating, :users, :badges, :scanners)
    * `:is_user_auth` - Whether the user is authenticated via user login (not badge)
  """
  attr :current_page, :atom, required: true
  attr :is_user_auth, :boolean, required: true

  def settings_nav(assigns) do
    ~H"""
    <ul class="menu bg-base-200 min-h-full w-64 p-4 pt-6">
      <li class="menu-title text-base-content/60 text-xs uppercase tracking-wider mb-2">
        Settings
      </li>

      <%!-- Seating - available to all authenticated users --%>
      <li>
        <.link
          navigate={~p"/settings/seating"}
          class={["flex items-center gap-3", @current_page == :seating && "active"]}
        >
          <Icons.squares_2x2 class="w-5 h-5" />
          <span>Seating Configuration</span>
        </.link>
      </li>

      <%!-- User-only sections --%>
      <%= if @is_user_auth do %>
        <li>
          <.link
            navigate={~p"/settings/users"}
            class={["flex items-center gap-3", @current_page == :users && "active"]}
          >
            <Icons.users class="w-5 h-5" />
            <span>Users</span>
          </.link>
        </li>
        <li>
          <.link
            navigate={~p"/settings/badges"}
            class={["flex items-center gap-3", @current_page == :badges && "active"]}
          >
            <Icons.identification class="w-5 h-5" />
            <span>Badges</span>
          </.link>
        </li>
      <% end %>

      <%!-- Scanners --%>
      <li>
        <.link
          navigate={~p"/settings/scanners"}
          class={["flex items-center gap-3", @current_page == :scanners && "active"]}
        >
          <Icons.qr_code class="w-5 h-5" />
          <span>Scanners</span>
        </.link>
      </li>
    </ul>
    """
  end
end
