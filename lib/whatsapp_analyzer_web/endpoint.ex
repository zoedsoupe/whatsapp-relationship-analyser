defmodule WhatsAppAnalyzerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :whatsapp_analyzer

  # Serve at "/" the static files from "priv/static" directory.
  plug(Plug.Static,
    at: "/",
    from: :whatsapp_analyzer,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    # CRITICAL: Increase upload limit for large chat files (50MB)
    length: 50_000_000
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(Plug.Session,
    store: :cookie,
    key: "_whatsapp_analyzer_key",
    signing_salt: "YourSigningSalt"
  )

  plug(WhatsAppAnalyzerWeb.Router)
end
