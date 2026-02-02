import Config

# Configures the endpoint
config :whatsapp_analyser, WhatsAppAnalyzerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [html: WhatsAppAnalyzerWeb.ErrorHTML], layout: false],
  pubsub_server: WhatsAppAnalyzer.PubSub,
  secret_key_base:
    "qF8X3p2r5u8x/A?D(G+KbPeShVmYq3t6w9z$C&F)J@NcRfUjXn2r5u8x/A?D(G+KbPeShVmYp3s6v9y$B&E)H@McQfTjWnZq4t7w!z"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
