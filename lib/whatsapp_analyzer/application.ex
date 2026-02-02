defmodule WhatsAppAnalyzer.Application do
  @moduledoc """
  The WhatsAppAnalyzer Application Service.

  Starts ML model servings, Phoenix endpoint, and sets up ETS for temporary result storage.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Cache GenServer with ETS and TTL management
      WhatsAppAnalyzer.AnalysisCache,
      # Task supervisor for background jobs
      {Task.Supervisor, name: WhatsAppAnalyzer.TaskSupervisor},
      # ML model servings - load models at startup with pre-compilation and batching
      # Must start before Endpoint to ensure models are available for requests
      WhatsAppAnalyzer.Servings.summarizer_spec(),
      WhatsAppAnalyzer.Servings.sentiment_spec(),
      # Start the endpoint when the application starts
      WhatsAppAnalyzerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: WhatsAppAnalyzer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    WhatsAppAnalyzerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
