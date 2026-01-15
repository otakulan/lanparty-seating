defmodule NavComponent do
  use Phoenix.Component
  use LanpartyseatingWeb, :verified_routes

  attr(:nav_menu, :list, required: true)
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
      <div class="navbar-center hidden lg:flex">
        <ul class="p-0 menu menu-horizontal">
          <%= for {menu_txt, path} <- assigns.nav_menu do %>
            <li class="nav-item min-w-fit">
              <.link patch={path} class={"nav-link hover:bg-neutral-focus rounded-lg #{if path == assigns.nav_menu_active_path, do: "bg-neutral-focus font-semibold", else: ""}"}>
                {menu_txt}
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
      <div class="navbar-end gap-2">
        <%= if @is_authenticated do %>
          <div class="flex items-center gap-2">
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
                Logout / Déconnexion
              </button>
            </form>
          </div>
        <% else %>
          <.link href={~p"/login"} class="btn btn-ghost btn-sm hover:bg-neutral-focus">
            Admin Login / Connexion admin
          </.link>
        <% end %>
      </div>
    </nav>
    """
  end
end
