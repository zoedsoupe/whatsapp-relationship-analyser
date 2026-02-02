import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.

config :whatsapp_analyzer, WhatsAppAnalyzerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

# Production ML model configuration
# Set BUMBLEBEE_CACHE_DIR to /app/cache in production deployment
# Set BUMBLEBEE_OFFLINE=true after models are cached during build
config :bumblebee, :progress_bar_enabled, false
