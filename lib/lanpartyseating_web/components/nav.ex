defmodule NavComponent do
  use Phoenix.Component

  # Optionally also bring the HTML helpers
  # use Phoenix.HTML

  attr(:nav_menu, :string, required: true)
  attr(:nav_menu_active_path, :string, required: true)

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
      <div class="navbar-end">
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
    </nav>
    """
  end
end
