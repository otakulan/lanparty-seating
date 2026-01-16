defmodule NavComponent do
  use Phoenix.Component
  use LanpartyseatingWeb, :verified_routes

  attr(:nav_menu, :list, required: true)
  attr(:admin_menu, :list, default: [])
  attr(:nav_menu_active_path, :string, required: true)
  attr(:current_scope, :map, default: nil)
  attr(:is_authenticated, :boolean, default: false)
  attr(:is_user_auth, :boolean, default: false)

  def nav(assigns) do
    ~H"""
    <nav class="navbar bg-neutral text-neutral-content shadow-lg px-4 lg:px-8">
      <div class="navbar-start">
        <div class="flex-1">
          <.link patch="/" class="text-xl normal-case btn btn-ghost hover:bg-neutral-focus">
            PC Gaming / Jeux PC
          </.link>
        </div>
      </div>
      <div class="navbar-end hidden lg:flex items-center gap-2">
        <ul class="p-0 menu menu-horizontal flex-nowrap">
          <%= for {menu_txt, path} <- @nav_menu do %>
            <li>
              <.link patch={path} class={"hover:bg-neutral-focus rounded-lg #{if path == @nav_menu_active_path, do: "bg-neutral-focus font-semibold", else: ""}"}>
                {menu_txt}
              </.link>
            </li>
          <% end %>
          <%= if @admin_menu != [] do %>
            <li>
              <details>
                <summary class="hover:bg-neutral-focus rounded-lg">Admin</summary>
                <ul class="bg-neutral p-2 rounded-box shadow-lg z-50">
                  <%= for {menu_txt, path} <- @admin_menu do %>
                    <li>
                      <.link patch={path} class={"hover:bg-neutral-focus rounded-lg #{if path == @nav_menu_active_path, do: "bg-neutral-focus font-semibold", else: ""}"}>
                        {menu_txt}
                      </.link>
                    </li>
                  <% end %>
                </ul>
              </details>
            </li>
          <% end %>
        </ul>
        <span class="text-neutral-content/40 px-2">|</span>
        <%= if @is_authenticated do %>
          <span class="text-sm opacity-80">
            {@current_scope.user.email}
            <%= if not @is_user_auth do %>
              <span class="badge badge-warning badge-sm ml-1">Badge</span>
            <% end %>
          </span>
          <form action={~p"/logout"} method="post" class="inline">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <button type="submit" class="btn btn-ghost btn-sm hover:bg-neutral-focus">
              Logout
            </button>
          </form>
        <% else %>
          <.link href={~p"/login"} class="btn btn-ghost btn-sm hover:bg-neutral-focus">
            Admin Login
          </.link>
        <% end %>
      </div>
    </nav>
    """
  end
end
