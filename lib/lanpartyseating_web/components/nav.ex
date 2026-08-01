defmodule LanpartyseatingWeb.Components.Nav do
  @moduledoc """
  Navigation bar component.
  """
  use LanpartyseatingWeb, :html
  alias LanpartyseatingWeb.Components.UI

  attr(:nav_menu, :list, required: true)
  attr(:admin_menu, :list, default: [])
  attr(:nav_menu_active_path, :string, required: true)
  attr(:current_scope, :map, default: nil)
  attr(:is_authenticated, :boolean, default: false)
  attr(:is_user_auth, :boolean, default: false)
  attr(:class, :string, default: "")

  def nav(assigns) do
    ~H"""
    <div class={["max-md:collapse bg-neutral text-neutral-content shadow-sm w-full rounded-none", @class]}>
      <input id="navbar-toggle" class="peer hidden" type="checkbox" />
      <label
        for="navbar-toggle"
        class="fixed inset-0 z-40 hidden max-md:peer-checked:block bg-black/20"
      >
      </label>

      <%!-- flex row, all start-aligned (no navbar-start/end 50% widths) --%>
      <div class="collapse-title navbar w-full px-2 sm:px-4 justify-between gap-1">
        <div class="flex grow">
          <label for="navbar-toggle" class="btn btn-ghost btn-square md:hidden" aria-label="Open menu">
            <Icons.menu />
          </label>

          <.link patch="/" class="btn btn-ghost text-lg self-stretch normal-case">
            PC Gaming / Jeux PC
          </.link>

          <span class="inline-flex md:hidden items-center justify-center ml-auto">
            <UI.theme_swap class="btn btn-ghost btn-square"/>
          </span>
        </div>

        <div class="hidden md:flex place-self-end">
          <ul class="menu menu-horizontal flex-nowrap">
            <.navigation_menu menu={@nav_menu} active_path={@nav_menu_active_path}/>
            <.admin_menu open?={false} menu={@admin_menu} active_path={@nav_menu_active_path}/>
            {user_menu(assigns)}
            <li>
              <span class="inline-flex items-center justify-center">
                <UI.theme_toggle class="border-neutral-content"/>
              </span>
            </li>
          </ul>

          <%!-- <div class="hidden lg:block"> --%>
          <%!-- </div> --%>
        </div>
      </div>

      <div class="collapse-content lg:hidden z-50 relative">
        <div class="flex items-center justify-end px-2 pb-1">
        </div>
        <ul class="menu menu-sm w-full gap-1 pb-3">
          <li>
          </li>
          <.navigation_menu menu={@nav_menu} active_path={@nav_menu_active_path} />
          <.admin_menu open?={true} menu={@admin_menu} active_path={@nav_menu_active_path} />
          {user_menu(assigns)}
        </ul>
      </div>
    </div>
    """
  end

  defp navigation_menu(assigns) do
    ~H"""
    <li :for={{menu_txt, path} <- @menu}>
      <.link
        patch={path}
        class={if path == @active_path, do: "menu-active", else: nil}
      >
        {menu_txt}
      </.link>
    </li>
    """
  end

  defp admin_menu(assigns) do
    ~H"""
    <li :if={@menu != []}>
      <details open={@open?}>
        <summary>Administration</summary>
        <ul class="lg:bg-base-100 lg:text-base-content p-2 lg:z-50 lg:w-44 lg:rounded-box lg:shadow-sm">
          <li :for={{menu_txt, path} <- @menu}>
            <.link
              patch={path}
              class={if path == @active_path, do: "menu-active", else: nil}
            >
              {menu_txt}
            </.link>
          </li>
        </ul>
      </details>
    </li>
    """
  end

  defp user_menu(assigns) do
    ~H"""
    <%= if @is_authenticated do %>
      <%= if @is_user_auth do %>
        <li>
          <.link patch={~p"/profile"} class="gap-1">
            <Icons.user class="w-4 h-4" />
            {@current_scope.user.name}
          </.link>
        </li>
      <% else %>
        <li>
          <span class="cursor-default opacity-80 gap-1 pointer-events-none">
            <Icons.user class="w-4 h-4" />
            {@current_scope.user.name}
            <span class="badge badge-warning badge-sm">Badge</span>
          </span>
        </li>
      <% end %>
      <li>
        <form action={~p"/logout"} method="post">
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <button type="submit">
            Logout
          </button>
        </form>
      </li>
    <% else %>
      <li>
        <.link href={~p"/login"} class="gap-1">
          <Icons.user class="w-4 h-4" />
          Admin Login
        </.link>
      </li>
    <% end %>
    """
  end
end
