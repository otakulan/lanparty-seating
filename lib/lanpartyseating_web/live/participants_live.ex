defmodule LanpartyseatingWeb.ParticipantsLive do
  use LanpartyseatingWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px">Seats</h1>

      <table>
        <tr>
          <th>badge id</th>
          <!-- badge uid -->
          <th>last scan</th>
          <!-- scan date that triggered the creation of the user in the AD -->
          <th>minutes left</th>
          <!-- minutes left until the user can't login or is logged off -->
          <th>deactivated</th>
          <!-- a boolean that's true once the user has been successfully deleted from the AD -->
          <th>username</th>
          <!-- username as the temporary login credential -->
        </tr>
        <tr>
          <td>00193</td>
          <td>May 6 2023, 17:43</td>
          <td>32</td>
          <td>no</td>
          <td>fish 🐟</td>
        </tr>
        <tr>
          <td>04918</td>
          <td>May 6 2023, 14:43</td>
          <td>13</td>
          <td>no</td>
          <td>bee 🐝</td>
        </tr>
        <tr>
          <td>03112</td>
          <td>May 6 2023, 13:43</td>
          <td>0</td>
          <td>yes</td>
          <td>sunflower 🌻</td>
        </tr>
      </table>
    </div>
    """
  end
end
