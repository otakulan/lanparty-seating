defmodule TournamentModalComponent do
  use Phoenix.Component

  def tournament_modal(assigns) do
    ~H"""
      <div class="" x-data>
        <label for="tournament-modal" x-on:click="$refs.new_tournament_modal.showModal()" class="btn btn-info">ADD NEW</label>
        <dialog class="modal" x-ref="new_tournament_modal">
          <div class="modal-box">
            <h3 class="text-lg font-bold">Creating new tournament</h3>
            <form method="dialog">
              <button class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">✕</button>
            </form>
            <form phx-submit="create_tournament">
              <label for="name" class="">Name:</label>
              <input
                type="text"
                placeholder="Tournament Name"
                class="w-full max-w-xs input input-bordered"
                name="name"
              />
              <br />
              <label for="start_time" class="">Start time:</label>
              <input
                type="datetime-local"
                class="w-full max-w-xs input input-bordered"
                name="start_time"
              />
              <br />
              <label for="duration" class="">Duration:</label>
              <input id="duration" name="duration" class=" input input-bordered" type="number" />

              <br />
              <label for="start_station" class="">Starting Station:</label>
              <input id="start_station" name="start_station" class=" input input-bordered" type="number" />

              <br />
              <label for="end_station" class="">Last Station:</label>
              <input id="end_station" name="end_station" class=" input input-bordered" type="number" />

              <div class="modal-action">
                <button for="tournament-modal" class="btn" type="submit">Create</button>
              </div>
            </form>
          </div>
        </dialog>
      </div>
    """
  end
end
