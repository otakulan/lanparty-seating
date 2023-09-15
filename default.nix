{ lib
, stdenv
, beamPackages
, mkYarnModules
, nodejs
, esbuild
}:

let
  pname = "lanpartyseating";
  version = "1.0.0";

  src = ./.;

  # TODO consider using `mix2nix` as soon as it supports git dependencies.
  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "${pname}-deps";
    inherit src version;
    hash = "sha256-DCKtG/m48Pg3enY7ZU1uUMEH4L/UvgXY9PWf37l1gZ0=";
  };

  yarnDeps = mkYarnModules {
    pname = "${pname}-yarn-deps";
    inherit version;
    packageJSON = ./assets/package.json;
    yarnLock = ./assets/yarn.lock;
    postBuild = ''
      cp -r ${mixFodDeps}/phoenix $out/node_modules
      cp -r ${mixFodDeps}/phoenix_html $out/node_modules
      cp -r ${mixFodDeps}/phoenix_live_view $out/node_modules
    '';
  };
in
beamPackages.mixRelease {
  inherit pname version src mixFodDeps;

  nativeBuildInputs = [ nodejs ];

  preBuild = ''
    export HOME=$TMPDIR
    export MIX_ESBUILD_PATH=${esbuild}/bin/esbuild
    ln -sf ${yarnDeps}/node_modules assets/node_modules
    ln -sf ${esbuild}/bin/esbuild _build/esbuild-linux-x64
    mix assets.deploy
    mix phx.gen.release
  '';

  meta = with lib; {
    license = licenses.mit;
    homepage = "https://github.com/starcraft66/lanparty-seating";
    description = "Seating management for freeplay events.";
    maintainers = with maintainers; [ starcraft66 ];
    platforms = platforms.unix;
  };
}
