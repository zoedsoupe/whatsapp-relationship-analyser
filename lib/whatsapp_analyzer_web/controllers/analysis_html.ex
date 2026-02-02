defmodule WhatsAppAnalyzerWeb.AnalysisHTML do
  @moduledoc """
  Renders analysis result templates.
  """
  use WhatsAppAnalyzerWeb, :html

  alias WhatsAppAnalyzerWeb.VegaLiteHelper

  embed_templates("analysis_html/*")

  @doc """
  Formats segmentation type for display.
  """
  def format_segmentation_type(type) do
    case type do
      :topic_change -> "Topic Change"
      :time_gap -> "Time Gap"
      :daily -> "Daily"
      _ -> "Unknown"
    end
  end
end
