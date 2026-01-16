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
        <.link patch="/" class="text-xl normal-case btn btn-ghost hover:bg-neutral-focus">
          PC Gaming / Jeux PC
        </.link>
      </div>

      <%!-- Desktop menu --%>
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
          <%= if @is_authenticated do %>
            <li>
              <span class="hover:bg-transparent cursor-default opacity-80 gap-1">
                <IconComponent.user class="w-4 h-4" />
                {@current_scope.user.email}
                <%= if not @is_user_auth do %>
                  <span class="badge badge-warning badge-sm">Badge</span>
                <% end %>
              </span>
            </li>
            <li>
              <form action={~p"/logout"} method="post">
                <input type="hidden" name="_method" value="delete" />
                <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
                <button type="submit" class="hover:bg-neutral-focus rounded-lg">
                  Logout
                </button>
              </form>
            </li>
          <% else %>
            <li>
              <.link href={~p"/login"} class="hover:bg-neutral-focus rounded-lg">
                Admin Login
              </.link>
            </li>
          <% end %>
        </ul>
      </div>

      <%!-- Mobile hamburger menu --%>
      <div class="navbar-end lg:hidden">
        <div class="dropdown dropdown-end">
          <label tabindex="0" class="btn btn-ghost">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </label>
          <ul tabindex="0" class="menu dropdown-content mt-3 z-50 p-2 shadow-lg bg-neutral rounded-box w-52">
            <%= for {menu_txt, path} <- @nav_menu do %>
              <li>
                <.link patch={path} class={"hover:bg-neutral-focus #{if path == @nav_menu_active_path, do: "bg-neutral-focus font-semibold", else: ""}"}>
                  {menu_txt}
                </.link>
              </li>
            <% end %>
            <%= if @admin_menu != [] do %>
              <li class="menu-title"><span>Admin</span></li>
              <%= for {menu_txt, path} <- @admin_menu do %>
                <li>
                  <.link patch={path} class={"hover:bg-neutral-focus #{if path == @nav_menu_active_path, do: "bg-neutral-focus font-semibold", else: ""}"}>
                    {menu_txt}
                  </.link>
                </li>
              <% end %>
            <% end %>

            <%= if @is_authenticated do %>
              <li class="menu-title">
                <span class="flex items-center gap-1">
                  <IconComponent.user class="w-4 h-4" />
                  {@current_scope.user.email}
                  <%= if not @is_user_auth do %>
                    <span class="badge badge-warning badge-sm">Badge</span>
                  <% end %>
                </span>
              </li>
              <li>
                <form action={~p"/logout"} method="post">
                  <input type="hidden" name="_method" value="delete" />
                  <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
                  <button type="submit" class="hover:bg-neutral-focus w-full text-left">
                    Logout
                  </button>
                </form>
              </li>
            <% else %>
              <li>
                <.link href={~p"/login"} class="hover:bg-neutral-focus">
                  Admin Login
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </nav>
    """
  end
end
