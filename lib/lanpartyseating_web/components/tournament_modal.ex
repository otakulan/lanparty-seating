defmodule TournamentModalComponent do
  use Phoenix.Component

  def tournament_modal(assigns) do
    ~H"""
    <label for="tournament-modal" class="btn btn-info">ADD NEW</label>
    <!-- Put this part before </body> tag -->
    <input type="checkbox" id="tournament-modal" class="modal-toggle" />
    <div class="modal modal-bottom sm:modal-middle">
      <div class="modal-box">
        <h3 class="text-lg font-bold">Creating new tournament</h3>

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
            <label for="tournament-modal" class="btn">Close</label>
            <button for="tournament-modal" class="btn" type="submit">Create</button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
