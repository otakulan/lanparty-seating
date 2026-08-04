defmodule LanpartyseatingWeb.Components.RoomOnboarding do
  @moduledoc """
  Inline onboarding checklist for a fresh install. Progress is derived entirely from the
  database (passed in as assigns), so it is resumable across reloads and doubles as a
  "getting started" checklist that disappears once every step is done.
  """
  use LanpartyseatingWeb, :html

  attr :room, :any, default: nil
  attr :seat_count, :integer, default: 0
  attr :first_map, :any, default: nil
  attr :has_published, :boolean, default: false

  def room_onboarding(assigns) do
    assigns = derive_steps(assigns)

    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body">
        <h3 class="text-lg font-bold text-base-content flex items-center gap-2">
          <Icons.rocket class="w-5 h-5 text-primary" />
          Get started / Pour commencer
        </h3>
        <p class="text-sm text-base-content/60 mb-2">
          Set up your first room and publish a map. / Configurez votre première salle et publiez une carte.
        </p>

        <%!-- Step 1: create room --%>
        <div class="collapse collapse-arrow bg-base-200 rounded-lg">
          <input type="checkbox" checked={@step1_open} />
          <div class="collapse-title font-medium flex items-center gap-2">
            <%= if @room do %>
              <Icons.circle_check_big class="w-5 h-5 text-success" />
            <% else %>
              <Icons.circle_dashed class="w-5 h-5 text-base-content/50" />
            <% end %>
            Create your room / Créez votre salle
          </div>
          <div class="collapse-content">
            <p class="text-sm text-base-content/60 mb-3">
              A Room holds your Seats. Give it a name and a canvas size. / Une salle contient vos places.
            </p>
            <.form for={%{}} as={:room} phx-submit="create_room" class="space-y-2">
              <label class="form-control">
                <span class="label-text text-xs">Room name / Nom de la salle</span>
                <input name="room[name]" class="input input-bordered input-sm" placeholder="Main Room" required />
              </label>
              <div class="flex gap-2">
                <label class="form-control flex-1">
                  <span class="label-text text-xs">Canvas width</span>
                  <input name="room[width]" type="number" min="1" value="1920" class="input input-bordered input-sm" />
                </label>
                <label class="form-control flex-1">
                  <span class="label-text text-xs">Canvas height</span>
                  <input name="room[height]" type="number" min="1" value="1080" class="input input-bordered input-sm" />
                </label>
              </div>
              <label class="form-control">
                <span class="label-text text-xs">First map name / Nom de la première carte</span>
                <input name="room[first_map_name]" class="input input-bordered input-sm" placeholder="Main Layout" />
              </label>
              <button type="submit" class="btn btn-sm btn-primary w-full">Create / Créer</button>
            </.form>
          </div>
        </div>

        <%!-- Step 2: add seats --%>
        <div class="collapse collapse-arrow bg-base-200 rounded-lg">
          <input type="checkbox" checked={@step2_open} />
          <div class="collapse-title font-medium flex items-center gap-2">
            <%= if @seat_count > 0 do %>
              <Icons.circle_check_big class="w-5 h-5 text-success" />
            <% else %>
              <Icons.circle_dashed class="w-5 h-5 text-base-content/50" />
            <% end %>
            Add seats / Ajoutez des places
          </div>
          <div class="collapse-content">
            <p class="text-sm text-base-content/60 mb-3">
              <%= if @seat_count > 0 do %>
                <%= @seat_count %> seat(s) placed. / place(s) placée(s).
              <% else %>
                Open the editor and draw your seats on the canvas. / Ouvrez l'éditeur et dessinez vos places.
              <% end %>
            </p>
            <%= if @first_map do %>
              <.link navigate={~p"/settings/seat-maps/#{@first_map.public_id}/edit"} class="btn btn-sm btn-primary w-full">
                Open the editor / Ouvrir l'éditeur
              </.link>
            <% else %>
              <button class="btn btn-sm btn-disabled w-full" disabled>Open the editor / Ouvrir l'éditeur</button>
            <% end %>
          </div>
        </div>

        <%!-- Step 3: publish --%>
        <div class="collapse collapse-arrow bg-base-200 rounded-lg">
          <input type="checkbox" checked={@step3_open} />
          <div class="collapse-title font-medium flex items-center gap-2">
            <%= if @has_published do %>
              <Icons.circle_check_big class="w-5 h-5 text-success" />
            <% else %>
              <Icons.circle_dashed class="w-5 h-5 text-base-content/50" />
            <% end %>
            Publish your map / Publiez votre carte
          </div>
          <div class="collapse-content">
            <p class="text-sm text-base-content/60 mb-3">
              <%= if @has_published do %>
                Your map is live. / Votre carte est en ligne.
              <% else %>
                Make the current map the one attendees see. / Rendez la carte visible.
              <% end %>
            </p>
            <%= if @first_map && not @has_published do %>
              <button phx-click="publish_first_map" phx-value-map_id={@first_map.id} class="btn btn-sm btn-primary w-full">
                Publish / Publier
              </button>
            <% else %>
              <button class="btn btn-sm btn-disabled w-full" disabled>Publish / Publier</button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp derive_steps(assigns) do
    room = assigns.room
    has_room = not is_nil(room)
    has_seats = assigns.seat_count > 0
    has_published = assigns.has_published

    step1_open = not has_room
    step2_open = has_room and not has_seats
    step3_open = has_room and has_seats and not has_published

    assign(assigns, step1_open: step1_open, step2_open: step2_open, step3_open: step3_open)
  end
end
