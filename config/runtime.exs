import Config

# TZData storage path for prod releases in the nix store
config :tzdata,
       :data_dir,
       System.get_env("STORAGE_DIR")

config :lanpartyseating, LanpartyseatingWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "localhost", port: 4000]
