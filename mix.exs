defmodule WhatsAppAnalyzer.MixProject do
  use Mix.Project

  def project do
    [
      app: :whatsapp_analyser,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nx, "~> 0.9"},
      {:axon, "~> 0.7"},
      {:explorer, "~> 0.10"},
      {:bumblebee, "~> 0.6"},
      {:exla, "~> 0.9"},
      {:tokenizers, "~> 0.5"},
      {:kino, "~> 0.15"},
      {:kino_vega_lite, "~> 0.1"},
      {:kino_bumblebee, "~> 0.5"},
      {:vega_lite, "~> 0.1.6"},
      {:stemmer, "~> 1.2"}
    ]
  end
end
