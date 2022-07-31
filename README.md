# Lanpartyseating

This is the default phoenix readme for now, this will change later!

On a Non-NixOS system, as root: 

`mkdir /etc/nix`
`echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf`

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Start the database: `docker-compose start`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install && cd ..`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
