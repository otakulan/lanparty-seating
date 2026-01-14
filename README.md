# Lanpartyseating

## Development

If you are running NixOS, make sure flakes are enabled.

On other operating systems/distributions, install Nix using the [Determinate Systems Nix installer](https://github.com/DeterminateSystems/nix-installer):

```console
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Consider installing [direnv](https://direnv.net/) to automatically install the project's nix shell when you `cd` into the folder. If you have direnv installed, simply run `direnv allow` and follow the instructions below.

If you don't use direnv, activate the nix shell using `nix shell --impure`.

To start lanparty-seating:

- In a dedicated terminal, start the database: `devenv up`
- Install dependencies with `mix deps.get`
- Create and migrate your database with `mix ecto.create && mix ecto.migrate`
- Populate database with `mix ecto.reset`
- Install Node.js dependencies with `cd assets && yarn install && cd ..`
- Deploy assets with `mix assets.deploy`
- Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Configuration

### Grafana

You can configure the app to automatically upload its grafana dashboards to grafana and annotate its lifecycle events in grafana by setting the following environment variables:

**GRAFANA_ENABLE**: Any value such as `1` enables grafana support

**GRAFANA_HOST**: URL to the grafana instance

**GRAFANA_AUTH_TOKEN**: Grafana auth token

**GRAFANA_DATASOURCE_ID**: Grafana datasource id for the prometheus instance that is scraping this application

### OpenTelemetry (OLTP)

You can configure OpenTelemetry to send trace to honeycomb.io by setting the following environment variable:

**OTEL_EXPORTER_OTLP_TRACES_HEADERS**: The value `x-honeycomb-team=<HONEYCOMB API TOKEN>`

## Debugging

There are mutiple ways to debug elixir code as show in the [Debugging](https://elixir-lang.org/getting-started/debugging.html) section of the elixir manual.

In general, you can use the VSCode editor with the recommended extensions for the project to debug in the editor using ElixirLS.

You can also launch the program with the elixir repl using `iex -S mix phx.server` and insert "breakpoints" into the code using `IEx.Pry()` in order to make the app break into the repl at that point, allowing you to introspect its state.

`pkill -9 postgres`
