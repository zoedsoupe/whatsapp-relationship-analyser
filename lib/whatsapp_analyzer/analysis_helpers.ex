defmodule WhatsAppAnalyzer.AnalysisHelpers do
  @moduledoc """
  Helper functions for common analysis patterns.
  Reduces code repetition across analyzer modules.
  """

  require Explorer.DataFrame, as: DF
  require Explorer.Series, as: S

  alias WhatsAppAnalyzer.Config

  @doc """
  Generic indicator counting function.

  Takes a DataFrame and a list of indicator keywords, returns a map with:
  - total_indicators: Total count of indicator occurrences
  - by_sender: Map of sender -> count
  - percentage_of_messages: Percentage of messages containing indicators
  """
  def count_indicators(df, indicator_list) do
    indicators_regex =
      indicator_list
      |> Enum.map(&Regex.escape/1)
      |> Enum.join("|")
      |> Regex.compile!("i")

    indicator_counts =
      df["message"]
      |> S.transform(fn msg ->
        msg = to_string(msg)
        Regex.scan(indicators_regex, String.downcase(msg)) |> length()
      end)

    total_indicators = indicator_counts |> S.sum()

    indicators_by_sender =
      df
      |> DF.put("indicator_count", indicator_counts)
      |> DF.group_by("sender")
      |> DF.summarise(count: sum(indicator_count))
      |> DF.to_rows()
      |> Enum.map(fn row -> {row["sender"], row["count"]} end)
      |> Map.new()

    messages_with_indicators =
      indicator_counts
      |> S.filter(_ > 0)
      |> S.size()

    indicator_percentage =
      if DF.n_rows(df) > 0 do
        messages_with_indicators / DF.n_rows(df) * 100
      else
        0
      end

    %{
      total_indicators: total_indicators,
      by_sender: indicators_by_sender,
      percentage_of_messages: round(indicator_percentage)
    }
  end

  @doc """
  Aggregates data by sender.

  Takes a DataFrame, a column name, and an aggregation function (:sum, :mean, :count).
  Returns a map of sender -> aggregated_value.
  """
  def aggregate_by_sender(df, column, aggregation \\ :count) do
    senders = get_senders(df)

    Enum.map(senders, fn sender ->
      sender_df = DF.filter_with(df, fn rows -> S.equal(rows["sender"], sender) end)

      value = case aggregation do
        :count -> DF.n_rows(sender_df)
        :sum -> if DF.n_rows(sender_df) > 0, do: S.sum(sender_df[column]), else: 0
        :mean -> if DF.n_rows(sender_df) > 0, do: S.mean(sender_df[column]), else: nil
      end

      {sender, value}
    end)
    |> Map.new()
  end

  @doc """
  Gets distinct senders from a DataFrame, excluding SYSTEM.
  """
  def get_senders(df) do
    df["sender"]
    |> S.distinct()
    |> S.to_list()
    |> Enum.reject(&(&1 == "SYSTEM"))
  end

  @doc """
  Adds day_name column to a DataFrame based on day_of_week.
  """
  def add_day_names(df) do
    day_name =
      df["day_of_week"]
      |> S.transform(fn day -> Config.day_name(day) end)

    DF.put(df, "day_name", day_name)
  end

  @doc """
  Adds time_period column to a DataFrame based on hour.
  """
  def add_time_period(df) do
    time_period =
      df["hour"]
      |> S.transform(fn hour -> Config.time_period(hour) end)

    DF.put(df, "time_period", time_period)
  end

  @doc """
  Calculates percentage distribution for a grouped DataFrame.
  Takes the result of a group_by + summarise operation.
  """
  def percentage_distribution(counts_map, total) do
    counts_map
    |> Enum.map(fn {key, count} ->
      {key, round(count / total * 100)}
    end)
    |> Map.new()
  end
end
