import Config

# Nx backend para ML (CPU no M1)
config :nx, default_backend: EXLA.Backend

# Configuração da aplicação WhatsApp Analyzer
config :whatsapp_analyzer,
  # Modelos ML multilíngues (incluem português, compatíveis com Bumblebee)
  # Alternativas menores e testadas para M1:
  sentiment_model: "nlptown/bert-base-multilingual-uncased-sentiment",
  summarization_model: "facebook/mbart-large-50",

  # Serving config (documentado sem magic numbers)
  ml_config: %{
    # Limites de geração de resumo
    # Comprimento máximo do resumo
    summary_max_tokens: 100,
    # Comprimento mínimo do resumo
    summary_min_tokens: 30,

    # Batch processing
    # Reduzido para M1 (4 → 2)
    batch_size: 2,
    # Timeout para acumular batch
    batch_timeout_ms: 100,

    # Limites de sequência (tokens)
    # Entrada máxima sumarização
    summarizer_max_length: 512,
    # Entrada máxima sentimento
    sentiment_max_length: 128,

    # Timeout de carregamento
    # 3 minutos (M1 é mais lento)
    model_load_timeout_ms: 180_000
  },

  # Thresholds de análise
  analysis_config: %{
    # Classificação de relacionamento (escala 0-100)
    # >= 70 = romântico
    romantic_threshold: 70,
    # >= 40 = amigo próximo
    close_friend_threshold: 40,
    # >= 20 = amigo
    friend_threshold: 20,
    # < 20 = conhecido

    # Pesos para classificação (soma = 1.0)
    # 35% - indicador principal
    romantic_weight: 0.35,
    # 25% - conexão emocional
    intimacy_weight: 0.25,
    # 15% - compromisso
    future_planning_weight: 0.15,
    # 15% - engajamento
    frequency_weight: 0.15,
    # 10% - responsividade
    response_time_weight: 0.10,

    # Multiplicadores de score
    # Escala contagem de keywords
    romantic_multiplier: 5,
    # Escala contagem de keywords
    intimacy_multiplier: 5,
    # Mais raro, peso maior
    future_multiplier: 10,

    # Conversão ML → score de relacionamento
    # confidence * 3 → romantic
    ml_romantic_factor: 3,
    # confidence * 2 → intimacy
    ml_intimacy_factor: 2,

    # Limites de arquivo
    # 10MB - usar streaming
    large_file_threshold_bytes: 10_485_760
  }

# Configures the endpoint
config :whatsapp_analyzer, WhatsAppAnalyzerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
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
