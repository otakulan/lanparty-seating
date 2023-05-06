{
  description = "Lan party seating application for Otakuthon";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
  };

  outputs = inputs@{ flake-parts, devenv, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        devShells.default = let
          inherit (pkgs.lib) optional optionals;
          erlang = pkgs.beam.interpreters.erlangR25;
          elixir = pkgs.beam.packages.erlangR25.elixir_1_14;
          rebar = pkgs.beam.packages.erlangR25.rebar3;
          nodejs = pkgs.nodejs-16_x;
        in devenv.lib.mkShell {
          inherit pkgs inputs;
          modules = [
            {
              services.postgres = {
                enable = true;
                initialDatabases = [ { name = "lanpartyseating_dev"; } ];
                initialScript = ''
                  CREATE USER postgres WITH SUPERUSER PASSWORD 'password';
                '';
                listen_addresses = "::1,127.0.0.1";
              };
              env.MIX_REBAR3 = "${rebar}/bin/rebar3";
              packages = with pkgs; [ cacert git erlang elixir rebar cargo nodejs elixir-ls ]
                ++ optional stdenv.isLinux inotify-tools
                ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
                CoreFoundation
                CoreServices
              ]);
              enterShell = ''
                alias mdg="mix deps.get"
                alias mps="mix phx.server"
                alias test="mix test"
                alias c="iex -S mix"
              '';
            }
          ];
        };
      };
      flake = {
        # Put your original flake attributes here.
      };
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        "aarch64-darwin"
      ];
    };
}
