[
  import_deps: [:phoenix, :ecto, :ecto_sql],
  inputs: ["*.{ex,exs}", "{config,lib,priv,test}/**/*.{ex,exs}"],
  plugins: [Phoenix.LiveView.HTMLFormatter, FreedomFormatter],
  line_length: 200,
  trailing_comma: true,
]
