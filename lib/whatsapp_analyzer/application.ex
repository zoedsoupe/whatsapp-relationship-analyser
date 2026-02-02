defmodule WhatsAppAnalyzer.Application do
  @moduledoc """
  The WhatsAppAnalyzer Application Service.

  Starts the Phoenix endpoint and sets up ETS for temporary result storage.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the endpoint when the application starts
      WhatsAppAnalyzerWeb.Endpoint
    ]

    # Create ETS table for storing analysis results
    :ets.new(:analysis_results, [:set, :public, :named_table])

    opts = [strategy: :one_for_one, name: WhatsAppAnalyzer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    WhatsAppAnalyzerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
