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

  Returns a list of conversation segments with metadata.
  """
  @spec segment_conversations(DF.t()) :: [
          %{
            conversation_id: integer(),
            start_time: NaiveDateTime.t(),
            end_time: NaiveDateTime.t(),
            duration_minutes: float(),
            message_count: non_neg_integer(),
            participants: [String.t()],
            summary: %{
              avg_message_length: float(),
              total_words: non_neg_integer(),
              message_counts: %{optional(String.t()) => non_neg_integer()}
            },
            text_summary: nil
          }
        ]
  def segment_conversations(df) do
    if DF.n_rows(df) == 0 do
      []
    else
      # Get unique conversation IDs
      conversation_ids =
        df["conversation_id"]
        |> S.distinct()
        |> S.to_list()

      # Process each conversation
      conversation_ids
      |> Enum.map(fn conv_id ->
        conv_df =
          DF.filter_with(df, fn rows ->
            S.equal(rows["conversation_id"], conv_id)
          end)

        build_segment_metadata(conv_df)
      end)
      |> Enum.sort_by(& &1.start_time)
    end
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

    %{
      conversation_id: conversation_id,
      start_time: start_time,
      end_time: end_time,
      duration_minutes: NaiveDateTime.diff(end_time, start_time) / 60,
      message_count: message_count,
      participants: participants,
      summary: summary,
      # Optional ML summary, populated on-demand
      text_summary: nil
    }
  end

  defp summarize_metrics(conv_df) do
    avg_message_length =
      if DF.n_rows(conv_df) > 0 do
        conv_df["message_length"]
        |> S.mean()
        |> Float.round(1)
      else
        0
      end

    total_words =
      if DF.n_rows(conv_df) > 0 do
        conv_df["word_count"]
        |> S.sum()
      else
        0
      end

    # Count messages per sender
    message_counts =
      conv_df
      |> DF.group_by("sender")
      |> DF.summarise(count: count(sender))
      |> DF.to_rows()
      |> Enum.map(fn row -> {row["sender"], row["count"]} end)
      |> Map.new()

    %{
      avg_message_length: avg_message_length,
      total_words: total_words,
      message_counts: message_counts
    }
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
    Avg Message Length: #{segment.summary.avg_message_length} chars
    """
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
