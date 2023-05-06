# Lanpartyseating

If you are running NixOS, make sure flakes are enabled.

On other operating systems/distributions, install Nix using the [Determinate Systems Nix installer](https://github.com/DeterminateSystems/nix-installer):

```console
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Consider installing [direnv](https://direnv.net/) to automatically install the project's nix shell when you `cd` into the folder. If you have direnv installed, simply run `direnv allow` and follow the instructions below.

If you don't use direnv, activate the nix shell using `nix shell --impure`.

To start lanparty-seating:

  * In a dedicated terminal, start the database: `devenv up`
  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Populate database with `mix ecto.reset`
  * Install Node.js dependencies with `cd assets && npm install && cd ..`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
