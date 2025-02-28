defmodule WhatsAppAnalyzer do
  @moduledoc """
  Main module for WhatsApp conversation analysis.
  """
  
  alias WhatsAppAnalyzer.DataProcessor
  alias WhatsAppAnalyzer.RelationshipAnalyzer
  alias WhatsAppAnalyzer.Visualization
  
  @doc """
  Analyzes a WhatsApp chat export file and returns a complete analysis.
  """
  def analyze_chat(file_path) do
    processed_data = DataProcessor.process_file(file_path)
    
    relationship_analysis = RelationshipAnalyzer.analyze_relationship(processed_data)
    
    visualizations = %{
      message_frequency: Visualization.message_frequency_chart(processed_data),
      sender_distribution: Visualization.sender_distribution_chart(processed_data),
      time_heatmap: Visualization.time_of_day_heatmap(processed_data),
      relationship_radar: Visualization.relationship_radar_chart(relationship_analysis),
      classification: Visualization.relationship_classification_chart(relationship_analysis)
    }
    
    %{
      data: processed_data,
      analysis: relationship_analysis,
      visualizations: visualizations,
      summary: RelationshipAnalyzer.relationship_summary(processed_data)
    }
  end
  
  @doc """
  Returns a brief summary of the relationship analysis.
  """
  def summarize_relationship(analysis) do
    classification = analysis.analysis.relationship_classification
    
    %{
      classification: classification.classification,
      confidence_score: classification.score,
      message_count: analysis.analysis.total_messages,
      time_span_days: analysis.analysis.time_span.days,
      primary_indicators: get_primary_indicators(classification.component_scores)
    }
  end
  
  defp get_primary_indicators(scores) do
    scores
    |> Enum.sort_by(fn {_key, value} -> value end, :desc)
    |> Enum.take(2)
    |> Enum.map(fn {key, value} -> {key, Float.round(value, 1)} end)
    |> Map.new()
  end
end
