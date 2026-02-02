defmodule WhatsAppAnalyzer do
  @moduledoc """
  Main module for WhatsApp conversation analysis.

  Provides a unified API for analyzing WhatsApp chat exports,
  with support for both regular and streaming parsing for large files.
  """

  alias WhatsAppAnalyzer.{
    AppConfig,
    DataProcessor,
    RelationshipAnalyzer,
    Visualization,
    StreamingParser,
    ConversationSegmenter,
    TemporalSummarizer
  }

  require Explorer.DataFrame, as: DF

  @doc """
  Analyzes a WhatsApp chat export file and returns a complete analysis.

  Automatically uses streaming parser for files larger than 10MB.
  """
  @spec analyze_chat(Path.t(), keyword()) :: map()
  def analyze_chat(file_path, opts \\ []) do
    processed_data = parse_file(file_path, opts)

    # Skip analysis if DataFrame is empty
    if DF.n_rows(processed_data) == 0 do
      %{
        error: "No valid messages found in the chat file",
        data: processed_data,
        analysis: nil,
        visualizations: nil,
        summary: nil,
        conversation_segments: []
      }
    else
      relationship_analysis = RelationshipAnalyzer.analyze_relationship(processed_data)

      visualizations = %{
        message_frequency: Visualization.message_frequency_chart(processed_data),
        sender_distribution: Visualization.sender_distribution_chart(processed_data),
        time_heatmap: Visualization.time_of_day_heatmap(processed_data),
        relationship_radar: Visualization.relationship_radar_chart(relationship_analysis),
        classification: Visualization.relationship_classification_chart(relationship_analysis),
        # New visualizations
        sentiment_timeline: Visualization.sentiment_timeline_chart(processed_data),
        word_frequency: Visualization.word_frequency_chart(processed_data),
        conversation_flow: Visualization.conversation_flow_chart(processed_data)
      }

      conversation_segments = ConversationSegmenter.segment_conversations(processed_data)
      temporal_summary = TemporalSummarizer.generate_full_summary(processed_data)

      %{
        data: processed_data,
        analysis: relationship_analysis,
        visualizations: visualizations,
        summary: RelationshipAnalyzer.relationship_summary(processed_data),
        conversation_segments: conversation_segments,
        temporal_summary: temporal_summary
      }
    end
  end

  @doc """
  Parses a file using the appropriate parser based on file size.
  """
  @spec parse_file(Path.t(), keyword()) :: DF.t()
  def parse_file(file_path, opts \\ []) do
    force_streaming = Keyword.get(opts, :streaming, false)
    file_size = File.stat!(file_path).size

    if force_streaming || file_size > AppConfig.large_file_threshold() do
      StreamingParser.parse_file_stream(file_path)
    else
      DataProcessor.process_file(file_path)
    end
  end

  @doc """
  Returns a brief summary of the relationship analysis.
  """
  @spec summarize_relationship(map()) :: map()
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

  @spec get_primary_indicators(map()) :: map()
  defp get_primary_indicators(scores) do
    scores
    |> Enum.sort_by(fn {_key, value} -> value end, :desc)
    |> Enum.take(2)
    |> Enum.map(fn {key, value} -> {key, round(value)} end)
    |> Map.new()
  end
end
