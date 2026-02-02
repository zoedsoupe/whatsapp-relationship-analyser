defmodule WhatsAppAnalyzer.MixProject do
  use Mix.Project

  def project do
    [
      app: :whatsapp_analyser,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {WhatsAppAnalyzer.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Phoenix core (no LiveView)
      {:phoenix, "~> 1.7.14"},
      {:phoenix_html, "~> 4.1"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},

      # Data analysis stack
      {:explorer, "~> 0.10"},
      {:vega_lite, "~> 0.1.6"},
      {:nx, "~> 0.9"},
      {:axon, "~> 0.7"},
      {:bumblebee, "~> 0.6"},
      {:exla, "~> 0.9"},
      {:tokenizers, "~> 0.5"},
      {:stemmer, "~> 1.2"}
    ]
  end
end
