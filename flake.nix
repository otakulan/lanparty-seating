{
  description = "Lan party seating application for Otakuthon";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    nix2container.url = "github:nlewo/nix2container";
  };

  outputs = inputs@{ flake-parts, devenv, nix2container, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
      ];

      perSystem = { config, self', inputs', pkgs, system, ... }: rec {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              nix2container = nix2container.packages.${system}.nix2container;
            })
          ];
        };
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        packages.default = pkgs.callPackage ./default.nix { };
        packages.lanparty-seating = pkgs.callPackage ./default.nix { };
        packages.container = let
          # temp path to store tzdata information
          tmp = pkgs.runCommand "tmp" {} ''
            mkdir -p $out/tmp/tzdata
          '';
          utils = pkgs.buildEnv {
            name = "root";
            paths = with pkgs; [ bashInteractive coreutils gnused gnugrep packages.lanparty-seating ];
            pathsToLink = [ "/bin" ];
          };
        in pkgs.nix2container.buildImage {
          name = "lanparty-seating";
          tag = packages.lanparty-seating.version;
          copyToRoot = [ tmp utils ];
          perms = [{
            path = tmp;
            regex = ".*";
            mode = "0777";
          }];
          config = {
            entrypoint = ["${packages.lanparty-seating}/bin/server"];
            env = [
              "RELEASE_COOKIE=changeme213482308949234"
              "PORT=4000"
              "STORAGE_DIR=/tmp/tzdata"
              "TZ=America/Toronto"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
              "LANG=en_US.UTF-8"
              "LC_ALL=en_US.UTF-8"
            ];
            user = "1000";
          };
        };

        devenv.shells.default = let
          inherit (pkgs.lib) optional optionals;
          erlang = pkgs.beam.interpreters.erlangR25;
          elixir = pkgs.beam.packages.erlangR26.elixir_1_15;
          rebar = pkgs.rebar3;
          nodejs = pkgs.nodejs_20;
        in {
          services.postgres = {
            enable = true;
            initialDatabases = [ { name = "lanpartyseating_dev"; } ];
            initialScript = ''
              CREATE USER postgres WITH SUPERUSER PASSWORD 'password';
            '';
            listen_addresses = "::1,127.0.0.1";
          };
          env.MIX_REBAR3 = "${rebar}/bin/rebar3";
          env.MIX_ESBUILD_PATH = "${pkgs.esbuild}/bin/esbuild";
          packages = with pkgs; [ cacert git erlang elixir rebar cargo nodejs yarn elixir-ls ]
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
        };
      };
      flake = {
        # Put your original flake attributes here.
      };
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    };
}
