defmodule LanpartyseatingWeb.AdminBadgeLoginLive do
  use LanpartyseatingWeb, :live_view
  alias Lanpartyseating.Repo, as: Repo
  require Ecto.Query

  def on_mount(:default, _params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="jumbotron">
      <h1 style="font-size:30px; text-align: center">Admin Login</h1>
      <div class="flex flex-wrap w-full">
        <div class="flex flex-col h-14 flex-1 grow mx-1" x-data>
            <form id="badge-form">
              <br /><br />
              <input
                type="text"
                placeholder="Badge number / Numéro de badge"
                class="w-full max-w-xs input input-bordered"
                style="margin: auto; display: block; -webkit-text-security: disc;"
                id="badge-input"
                autocomplete="off"
                autofocus
              />
            </form>

            <script>
              document.getElementById('badge-form').addEventListener('submit', function(e) {
                e.preventDefault();
                const badgeId = document.getElementById('badge-input').value;
                console.log(`about to fetch with ${badgeId}`);
                fetch(`/auth?badge_number=${badgeId}`)
                  .then(response => {
                    if (response.status == 200) {
                      const urlParams = new URLSearchParams(window.location.search);
                      if (urlParams.has('redirect')) {
                        window.location.href = `/${urlParams.get('redirect')}`;
                      } else {
                        alert('success')
                      }
                    } else {
                      alert('not an admin badge')
                    }
                  })
                  .catch(e => {
                    console.log(e);
                    alert('exception lol');
                  });
              })
            </script>
        </div>
      </div>
    </div>
    """
  end
end
