defmodule WhatsAppAnalyzer.DataProcessor do
  @moduledoc """
  Converts parsed WhatsApp messages into Explorer DataFrames and adds analysis features.
  """

  require Explorer.Series, as: S
  require Explorer.DataFrame, as: DF

  @doc """
  Converts a list of message maps into an Explorer DF.
  """
  @spec messages_to_dataframe([map()]) :: DF.t()
  def messages_to_dataframe(messages) do
    messages = Enum.reject(messages, &(&1.sender == "SYSTEM"))

    DF.new(
      datetime: Enum.map(messages, & &1.datetime),
      sender: Enum.map(messages, & &1.sender),
      message: Enum.map(messages, & &1.message)
    )
  end

  @doc """
  Processes an entire chat file in batches to handle memory constraints.
  """
  @spec process_file(Path.t(), pos_integer()) :: DF.t()
  def process_file(filepath, batch_size \\ 1000) do
    messages = WhatsAppAnalyzer.Parser.parse_file(filepath)

    if length(messages) <= batch_size do
      messages
      |> messages_to_dataframe()
      |> enhance_dataframe()
    else
      messages
      |> Enum.chunk_every(batch_size)
      |> Enum.map(&messages_to_dataframe/1)
      |> Enum.map(&enhance_dataframe/1)
      |> combine_dataframes()
    end
  end

  @doc """
  Enhances a DF with additional analysis features.
  """
  @spec enhance_dataframe(DF.t()) :: DF.t()
  def enhance_dataframe(df) do
    if DF.n_rows(df) == 0 do
      df
    else
      df
      |> add_time_features()
      |> add_message_length()
      |> add_response_time()
      |> add_conversation_markers()
      |> add_sentiment_scores()
    end
  end

  @spec add_sentiment_scores(DF.t()) :: DF.t()
  defp add_sentiment_scores(df) do
    WhatsAppAnalyzer.SentimentScorer.add_sentiment_columns(df)
  end

  @spec add_time_features(DF.t()) :: DF.t()
  defp add_time_features(df) do
    date =
      df["datetime"]
      |> S.transform(fn dt -> NaiveDateTime.to_date(dt) end)

    hour =
      df["datetime"]
      |> S.transform(fn dt -> dt.hour end)

    day_of_week =
      df["datetime"]
      |> S.transform(fn dt ->
        dt |> NaiveDateTime.to_date() |> Date.day_of_week()
      end)

    df
    |> DF.put("date", date)
    |> DF.put("hour", hour)
    |> DF.put("day_of_week", day_of_week)
  end

  @spec add_message_length(DF.t()) :: DF.t()
  defp add_message_length(df) do
    lengths =
      df["message"]
      |> S.transform(fn msg -> String.length(to_string(msg)) end)

    word_counts =
      df["message"]
      |> S.transform(fn msg ->
        msg |> to_string() |> String.split() |> length()
      end)

    df
    |> DF.put("message_length", lengths)
    |> DF.put("word_count", word_counts)
  end

  @spec add_response_time(DF.t()) :: DF.t()
  defp add_response_time(df) do
    if DF.n_rows(df) == 0 do
      add_response_time_empty(df)
    else
      add_response_time_filled(df)
    end
  end

  defp add_response_time_empty(df) do
    DF.put(df, "response_time_minutes", S.from_list([]))
  end

  defp add_response_time_filled(df) do
    sorted_df = DF.sort_by(df, datetime)

    response_times =
      sorted_df
      |> DF.to_rows()
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        if prev["sender"] != curr["sender"] do
          (NaiveDateTime.diff(curr["datetime"], prev["datetime"]) / 60) |> min(1440)
        else
          nil
        end
      end)
      |> then(&[nil | &1])

    DF.put(sorted_df, "response_time_minutes", S.from_list(response_times))
  end

  @spec add_conversation_markers(DF.t()) :: DF.t()
  defp add_conversation_markers(df) do
    if DF.n_rows(df) == 0 do
      add_conversation_markers_empty(df)
    else
      add_conversation_markers_filled(df)
    end
  end

  defp add_conversation_markers_empty(df) do
    df
    |> DF.put("new_conversation", S.from_list([]))
    |> DF.put("conversation_id", S.from_list([]))
  end

  defp add_conversation_markers_filled(df) do
    sorted_df = DF.sort_by(df, datetime)

    timestamps =
      sorted_df["datetime"]
      |> S.to_list()

    time_gaps =
      Enum.zip([nil | timestamps], timestamps)
      |> Enum.map(fn {prev, current} ->
        case prev do
          nil -> nil
          _ -> NaiveDateTime.diff(current, prev) / 60
        end
      end)

    conversation_markers =
      Enum.map(time_gaps, fn
        nil -> 1
        gap when gap > 60 -> 1
        _ -> 0
      end)

    {conversation_ids, _} =
      Enum.reduce(conversation_markers, {[], 1}, fn
        marker, {acc, current_id} ->
          if marker == 1 do
            {[current_id + 1 | acc], current_id + 1}
          else
            {[current_id | acc], current_id}
          end
      end)

    df = DF.put(sorted_df, "new_conversation", S.from_list(conversation_markers))
    DF.put(df, "conversation_id", S.from_list(Enum.reverse(conversation_ids)))
  end

  @spec combine_dataframes([DF.t()]) :: DF.t()
  defp combine_dataframes(dfs) do
    Enum.reduce(dfs, fn df, acc ->
      DF.concat_rows(acc, df)
    end)
  end
end
