import Config

# TZData storage path for prod releases in the nix store
config :tzdata,
       :data_dir,
       System.get_env("STORAGE_DIR")

config :lanpartyseating, LanpartyseatingWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "localhost", port: 4000]

# config :opentelemetry,
#   span_processor: :batch,
#   traces_exporter: :otlp

# config :opentelemetry_exporter,
#   otlp_protocol: :grpc,
#   otlp_compression: :gzip,
#   otlp_endpoint: "https://api.honeycomb.io:443",
#   otlp_headers: [{"x-honeycomb-dataset", "lanparty-seating"}]
