defmodule WhatsAppAnalyzer.ConversationSegmenter do
  @moduledoc """
  Segments conversations and provides metrics per segment.

  Groups messages by conversation_id and extracts useful metrics
  for each conversation segment.
  """

  require Explorer.DataFrame, as: DF
  require Explorer.Series, as: S

  @doc """
  Segments conversations from a DataFrame and provides metrics.

  Returns a list of conversation segments with metadata, limited to top 50 by message count
  and sorted chronologically.
  """
  @spec segment_conversations(DF.t()) :: [
          %{
            conversation_id: integer(),
            start_time: NaiveDateTime.t(),
            end_time: NaiveDateTime.t(),
            duration_minutes: float(),
            message_count: non_neg_integer(),
            participants: [String.t()],
            summary: map(),
            text_summary: nil | String.t()
          }
        ]
  def segment_conversations(df) do
    if DF.n_rows(df) == 0, do: [], else: process_segments(df)
  end

  defp process_segments(df) do
    df["conversation_id"]
    |> S.distinct()
    |> S.to_list()
    |> Enum.map(&extract_and_build_segment(df, &1))
    |> Enum.sort_by(& &1.message_count, :desc)
    |> Enum.take(50)
    |> Enum.sort_by(& &1.start_time, NaiveDateTime)
  end

  defp extract_and_build_segment(df, conv_id) do
    df
    |> DF.filter_with(fn rows -> S.equal(rows["conversation_id"], conv_id) end)
    |> build_segment_metadata()
  end

  defp build_segment_metadata(conv_df) do
    conversation_id = conv_df["conversation_id"] |> S.first()

    datetimes = conv_df["datetime"] |> S.to_list()
    start_time = Enum.min(datetimes)
    end_time = Enum.max(datetimes)

    message_count = DF.n_rows(conv_df)

    participants =
      conv_df["sender"]
      |> S.distinct()
      |> S.to_list()
      |> Enum.reject(&(&1 == "SYSTEM"))

    summary = summarize_metrics(conv_df)

    # Extract messages for ML summarization
    messages =
      conv_df["message"]
      |> S.to_list()

    # Generate ML summary with fallback
    text_summary = generate_text_summary(messages)

    # Ensure duration is always positive
    duration_minutes = abs(NaiveDateTime.diff(end_time, start_time) / 60)

    %{
      conversation_id: conversation_id,
      start_time: start_time,
      end_time: end_time,
      duration_minutes: duration_minutes,
      message_count: message_count,
      participants: participants,
      summary: summary,
      text_summary: text_summary
    }
  end

  defp generate_text_summary(messages) do
    # Generate ML summary automatically with fallback
    WhatsAppAnalyzer.MLSummarizer.summarize_conversation_text(messages, enable_ml: false)
  end

  defp summarize_metrics(_conv_df) do
    # Simplified - only keeping essential data
    %{}
  end

  @doc """
  Formats a conversation segment for display.
  """
  @spec format_segment(map()) :: String.t()
  def format_segment(segment) do
    """
    Conversation ##{segment.conversation_id}
    Time: #{format_datetime(segment.start_time)} - #{format_datetime(segment.end_time)}
    Duration: #{Float.round(segment.duration_minutes, 1)} minutes
    Messages: #{segment.message_count}
    Participants: #{Enum.join(segment.participants, ", ")}
    """
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
