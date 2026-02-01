defmodule Mix.Tasks.GenDevCert do
  @shortdoc "Generates a self-signed certificate for HTTPS development (Chrome-compatible)"
  @moduledoc """
  Generates a self-signed certificate compatible with Chrome and OTP 28.

      $ mix gen_dev_cert
      $ mix gen_dev_cert --force

  Uses OpenSSL to generate certificates with proper Subject Alternative Names
  that Chrome requires. Output files:

    * priv/cert/selfsigned.pem - Certificate
    * priv/cert/selfsigned_key.pem - Private key

  ## Options

    * `--force` - Overwrite existing certificates

  ## Why not mix phx.gen.cert?

  The built-in Phoenix task uses Erlang's :public_key module which has
  compatibility issues with Chrome when running on OTP 28. This task uses
  OpenSSL directly to generate certificates that work reliably.

  ## Requirements

  OpenSSL must be installed and available in PATH.
  """

  use Mix.Task

  @cert_path "priv/cert"
  @cert_file "selfsigned.pem"
  @key_file "selfsigned_key.pem"

  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [force: :boolean])
    force? = Keyword.get(opts, :force, false)

    File.mkdir_p!(@cert_path)

    certfile = Path.join(@cert_path, @cert_file)
    keyfile = Path.join(@cert_path, @key_file)

    certs_exist? = File.exists?(certfile) and File.exists?(keyfile)

    cond do
      certs_exist? and not force? ->
        Mix.shell().info("Certificates already exist at #{@cert_path}/")
        Mix.shell().info("Use --force to regenerate.")

      true ->
        if certs_exist?, do: Mix.shell().info("Overwriting existing certificates...")
        generate_cert(certfile, keyfile)
    end
  end

  defp generate_cert(certfile, keyfile) do
    Mix.shell().info("Generating self-signed certificate...")

    args = [
      "req",
      "-x509",
      "-newkey",
      "rsa:4096",
      "-sha256",
      "-days",
      "365",
      "-nodes",
      "-keyout",
      keyfile,
      "-out",
      certfile,
      "-subj",
      "/CN=localhost",
      "-addext",
      "subjectAltName=DNS:localhost,IP:127.0.0.1",
    ]

    case System.cmd("openssl", args, stderr_to_stdout: true) do
      {_output, 0} ->
        File.chmod!(keyfile, 0o600)

        Mix.shell().info("""

        Certificate generated successfully!

          Certificate: #{certfile}
          Private key: #{keyfile}

        HTTPS is configured in config/dev.exs on port 4001.
        Access via: https://localhost:4001

        WARNING: Only use for local development. Do not use in production.
        """)

      {output, code} ->
        Mix.raise("""
        Failed to generate certificate (exit code #{code}).

        Make sure OpenSSL is installed and in your PATH.

        Output: #{output}
        """)
    end
  end
end
