{
  description = "Lan party seating application for Otakuthon";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        inherit (pkgs.lib) optional optionals;
        erlang = pkgs.beam.interpreters.erlangR25;
        elixir = pkgs.beam.packages.erlangR25.elixir_1_13;
        rebar = pkgs.beam.packages.erlangR25.rebar3;
        nodejs = pkgs.nodejs-16_x;
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ cacert git erlang elixir rebar cargo nodejs ]
            ++ optional stdenv.isLinux inotify-tools
            ++ optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
            CoreFoundation
            CoreServices
          ]);
          shellHook = ''
            alias mdg="mix deps.get"
            alias mps="mix phx.server"
            alias test="mix test"
            alias c="iex -S mix"
          '';
        };
      }
    );
}