defmodule LanpartyseatingWeb.Settings.CarouselLive do
  @moduledoc """
  Settings page for managing the game cover carousel displayed on the public display page.
  Supports image upload, title editing, enable/disable toggle, reordering, and deletion.
  Requires full user authentication (not badge auth).
  """
  use LanpartyseatingWeb, :live_view

  alias Lanpartyseating.CarouselLogic
  alias LanpartyseatingWeb.Components.SettingsNav

  # ============================================================================
  # Mount & Handle Params
  # ============================================================================

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Lanpartyseating.PubSub, "carousel_update")
    end

    socket =
      socket
      |> allow_upload(:carousel_image,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 2_000_000
      )
      |> assign(:upload_error, nil)
      |> assign(:title_form, %{"title" => ""})
      |> assign(:editing_image, nil)
      |> assign(:edit_title, "")
      |> assign(:delete_confirm_id, nil)

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
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
    assign(socket, :images, CarouselLogic.list_all_images())
  end

  # ============================================================================
  # Event Handlers
  # ============================================================================

  def handle_event("validate_upload", _params, socket) do
    {:noreply, assign(socket, :upload_error, nil)}
  end

  def handle_event("change_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :title_form, %{"title" => title})}
  end

  def handle_event("upload_image", %{"title" => title}, socket) do
    case uploaded_entries(socket, :carousel_image) do
      {[entry], []} ->
        result =
          consume_uploaded_entry(socket, entry, fn %{path: path} ->
            image_data = File.read!(path)
            {:ok, {image_data, entry.client_type}}
          end)

        case result do
          {image_data, content_type} ->
            attrs = %{
              image_data: image_data,
              content_type: content_type,
              title: if(title == "", do: nil, else: title),
            }

            case CarouselLogic.create_image(attrs) do
              {:ok, _image} ->
                {:noreply,
                 socket
                 |> assign(:title_form, %{"title" => ""})
                 |> assign(:upload_error, nil)
                 |> put_flash(:info, "Image uploaded")
                 |> load_data()}

              {:error, _changeset} ->
                {:noreply,
                 socket
                 |> assign(:upload_error, "Failed to save image")
                 |> put_flash(:error, "Failed to save image")}
            end

          _ ->
            {:noreply, assign(socket, :upload_error, "Upload failed")}
        end

      {[], [_error | _]} ->
        {:noreply, assign(socket, :upload_error, "Invalid file. Use JPEG, PNG, or WebP under 2MB.")}

      {[], []} ->
        {:noreply, assign(socket, :upload_error, "Please select an image file")}
    end
  end

  def handle_event("toggle_enabled", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    image = Enum.find(socket.assigns.images, &(&1.id == id))

    if image do
      CarouselLogic.update_image(id, %{enabled: !image.enabled})
      {:noreply, load_data(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("reorder", %{"ids" => ordered_ids}, socket) do
    CarouselLogic.reorder_images(ordered_ids)
    {:noreply, load_data(socket)}
  end

  def handle_event("start_edit", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    image = Enum.find(socket.assigns.images, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:editing_image, id)
     |> assign(:edit_title, image[:title] || "")}
  end

  def handle_event("change_edit_title", %{"title" => title}, socket) do
    {:noreply, assign(socket, :edit_title, title)}
  end

  def handle_event("save_edit", _params, socket) do
    id = socket.assigns.editing_image
    title = socket.assigns.edit_title
    title = if title == "", do: nil, else: title

    CarouselLogic.update_image(id, %{title: title})

    {:noreply,
     socket
     |> assign(:editing_image, nil)
     |> assign(:edit_title, "")
     |> load_data()}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_image, nil)
     |> assign(:edit_title, "")}
  end

  def handle_event("confirm_delete", %{"id" => id_str}, socket) do
    {:noreply, assign(socket, :delete_confirm_id, String.to_integer(id_str))}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_confirm_id, nil)}
  end

  def handle_event("delete_image", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    CarouselLogic.delete_image(id)

    {:noreply,
     socket
     |> assign(:delete_confirm_id, nil)
     |> put_flash(:info, "Image deleted")
     |> load_data()}
  end

  # ============================================================================
  # PubSub Handlers
  # ============================================================================

  def handle_info({:carousel, :updated}, socket) do
    {:noreply, load_data(socket)}
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
          <span class="text-lg font-bold">Carousel</span>
        </div>

        <%!-- Main content area --%>
        <div class="p-4 lg:p-6">
          <.carousel_content {assigns} />
        </div>
      </div>

      <div class="drawer-side z-40">
        <label for="settings-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <SettingsNav.settings_nav current_page={:carousel} is_user_auth={@is_user_auth} />
      </div>
    </div>
    """
  end

  defp carousel_content(assigns) do
    ~H"""
    <div class="max-w-4xl">
      <.page_header
        title="Game Carousel"
        subtitle="Manage game cover images shown on the display page"
      />

      <%!-- Upload Section --%>
      <.admin_section title="Upload New Image">
        <form id="carousel-upload-form" phx-submit="upload_image" phx-change="validate_upload" class="space-y-4">
          <div class="flex flex-col sm:flex-row gap-4 items-start">
            <div class="flex-1">
              <label class="label">
                <span class="label-text font-medium">Game Title (optional)</span>
              </label>
              <input
                type="text"
                name="title"
                value={@title_form["title"]}
                placeholder="e.g. League of Legends"
                class="input input-bordered w-full"
                phx-change="change_title"
                phx-debounce="300"
              />
            </div>
            <div class="flex-1">
              <label class="label">
                <span class="label-text font-medium">Image File</span>
              </label>
              <.live_file_input upload={@uploads.carousel_image} class="file-input file-input-bordered w-full" />
              <p class="text-xs text-base-content/50 mt-1">JPEG, PNG, or WebP. Max 2MB.</p>
            </div>
          </div>

          <%= if @upload_error do %>
            <div class="alert alert-error text-sm">
              <Icons.exclamation_triangle class="w-4 h-4" />
              <span>{@upload_error}</span>
            </div>
          <% end %>

          <%!-- Upload preview --%>
          <%= for entry <- @uploads.carousel_image.entries do %>
            <div class="flex items-center gap-4 p-3 bg-base-200 rounded-lg">
              <.live_img_preview entry={entry} class="w-14 h-20 object-cover rounded" />
              <div class="flex-1">
                <p class="text-sm font-medium">{entry.client_name}</p>
                <p class="text-xs text-base-content/50">{Float.round(entry.client_size / 1_000_000, 2)} MB</p>
              </div>
              <progress class="progress progress-primary w-24" value={entry.progress} max="100" />
            </div>

            <%= for err <- upload_errors(@uploads.carousel_image, entry) do %>
              <div class="alert alert-error text-sm">
                <span>{upload_error_to_string(err)}</span>
              </div>
            <% end %>
          <% end %>

          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary" disabled={@uploads.carousel_image.entries == []}>
              <Icons.arrow_up_tray class="w-4 h-4" /> Upload
            </button>
          </div>
        </form>
      </.admin_section>

      <%!-- Image List Section --%>
      <.admin_section title={"Carousel Images (#{length(@images)})"}>
        <%= if @images == [] do %>
          <div class="text-center py-12 text-base-content/50">
            <Icons.photo class="w-12 h-12 mx-auto mb-3 opacity-50" />
            <p class="text-lg">No images yet</p>
            <p class="text-sm">Upload game covers above to get started</p>
          </div>
        <% else %>
          <div id="carousel-image-list" phx-hook="SortableListHook" class="space-y-3">
            <%= for image <- @images do %>
              <div
                data-id={image.id}
                class={[
                  "flex items-center gap-4 p-3 rounded-lg border",
                  if(image.enabled, do: "border-base-300 bg-base-100", else: "border-base-300 bg-base-200 opacity-60")
                ]}
              >
                <%!-- Thumbnail --%>
                <img
                  src={~p"/carousel/images/#{image.id}"}
                  class="w-14 h-20 object-cover rounded flex-shrink-0"
                  alt={image.title || "Carousel image"}
                />

                <%!-- Title / Edit --%>
                <div class="flex-1 min-w-0">
                  <%= if @editing_image == image.id do %>
                    <form phx-submit="save_edit" class="flex gap-2">
                      <input
                        type="text"
                        name="title"
                        value={@edit_title}
                        phx-change="change_edit_title"
                        phx-debounce="200"
                        class="input input-bordered input-sm flex-1"
                        placeholder="Game title (optional)"
                        autofocus
                      />
                      <button type="submit" class="btn btn-sm btn-success">
                        <Icons.check class="w-4 h-4" />
                      </button>
                      <button type="button" class="btn btn-sm btn-ghost" phx-click="cancel_edit">
                        <Icons.x class="w-4 h-4" />
                      </button>
                    </form>
                  <% else %>
                    <p
                      class="font-medium truncate cursor-pointer hover:text-primary"
                      phx-click="start_edit"
                      phx-value-id={image.id}
                      title="Click to edit title"
                    >
                      {image.title || "(no title)"}
                    </p>
                    <p class="text-xs text-base-content/50">
                      {image.content_type} &middot; Order: {image.display_order}
                    </p>
                  <% end %>
                </div>

                <%!-- Controls --%>
                <div class="flex items-center gap-1 flex-shrink-0">
                  <%!-- Drag handle for reordering --%>
                  <div data-drag-handle draggable="true" class="cursor-grab active:cursor-grabbing px-1" title="Drag to reorder">
                    <Icons.bars_3 class="w-5 h-5 text-base-content/40" />
                  </div>

                  <%!-- Toggle enabled --%>
                  <label class="label cursor-pointer px-2" title={if(image.enabled, do: "Disable", else: "Enable")}>
                    <input
                      type="checkbox"
                      class="toggle toggle-sm toggle-success"
                      checked={image.enabled}
                      phx-click="toggle_enabled"
                      phx-value-id={image.id}
                    />
                  </label>

                  <%!-- Delete --%>
                  <%= if @delete_confirm_id == image.id do %>
                    <button
                      class="btn btn-sm btn-error"
                      phx-click="delete_image"
                      phx-value-id={image.id}
                    >
                      Confirm
                    </button>
                    <button class="btn btn-sm btn-ghost" phx-click="cancel_delete">
                      Cancel
                    </button>
                  <% else %>
                    <button
                      class="btn btn-sm btn-ghost text-error"
                      phx-click="confirm_delete"
                      phx-value-id={image.id}
                      title="Delete image"
                    >
                      <Icons.trash class="w-4 h-4" />
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </.admin_section>
    </div>
    """
  end

  defp upload_error_to_string(:too_large), do: "File is too large (max 2MB)"
  defp upload_error_to_string(:not_accepted), do: "Invalid file type. Use JPEG, PNG, or WebP."
  defp upload_error_to_string(:too_many_files), do: "Only one file at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
