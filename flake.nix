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
        erlang = beam.interpreters.erlangR26;
        elixir = beam.packages.erlangR26.elixir_1_13;
        nodejs = nodejs-16_x;
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ cacert git erlang elixir cargo nodejs ]
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
