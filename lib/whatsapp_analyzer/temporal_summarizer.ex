defmodule WhatsAppAnalyzer.TemporalSummarizer do
  @moduledoc """
  Generates temporal summaries of conversations with adaptive segmentation.
  Segments conversations by time periods (weekly, bi-weekly, or monthly)
  based on overall conversation duration.
  """

  alias Explorer.DataFrame
  alias Explorer.Series

  require Logger
  require Explorer.DataFrame

  @doc """
  Generates a full temporal summary of the conversation.
  Returns a structured summary organized by adaptive time periods.

  ## Parameters
    - df: DataFrame with conversation data

  ## Returns
    Map with period summaries and metadata
  """
  @spec generate_full_summary(DataFrame.t()) :: map()
  def generate_full_summary(df) do
    if DataFrame.n_rows(df) == 0 do
      %{
        periods: [],
        total_days: 0,
        segmentation_type: :none
      }
    else
      # Determine conversation timespan
      dates = df["datetime"] |> Series.to_list()
      start_date = Enum.min(dates)
      end_date = Enum.max(dates)
      total_days = Date.diff(NaiveDateTime.to_date(end_date), NaiveDateTime.to_date(start_date))

      # Determine segmentation type
      segmentation_type = determine_segmentation_type(total_days)

      # Segment by time period
      periods = segment_by_time_period(df, segmentation_type)

      # Generate summary for each period
      period_summaries =
        periods
        |> Enum.map(fn {period_key, period_df} ->
          summarize_period(period_key, period_df, segmentation_type)
        end)
        |> Enum.sort_by(& &1.period_start)

      %{
        periods: period_summaries,
        total_days: total_days,
        segmentation_type: segmentation_type,
        summary_text: format_as_markdown(period_summaries, total_days, segmentation_type)
      }
    end
  end

  @doc """
  Determines the appropriate segmentation type based on conversation duration.

  - < 30 days: weekly
  - 30-180 days: bi-weekly
  - > 180 days: monthly
  """
  @spec determine_segmentation_type(integer()) :: :weekly | :biweekly | :monthly
  def determine_segmentation_type(total_days) do
    cond do
      total_days < 30 -> :weekly
      total_days < 180 -> :biweekly
      true -> :monthly
    end
  end

  @doc """
  Segments the DataFrame by adaptive time periods.
  Returns a list of {period_key, period_df} tuples sorted by period index.
  """
  @spec segment_by_time_period(DataFrame.t(), atom()) :: [{String.t(), DataFrame.t()}]
  def segment_by_time_period(df, segmentation_type) do
    dates = df["datetime"] |> Series.to_list()
    start_date = Enum.min(dates) |> NaiveDateTime.to_date()

    # Add period columns to DataFrame
    period_data =
      dates
      |> Enum.map(fn datetime ->
        date = NaiveDateTime.to_date(datetime)

        {
          calculate_period_key(date, start_date, segmentation_type),
          calculate_period_index(date, start_date, segmentation_type)
        }
      end)

    period_keys = Enum.map(period_data, &elem(&1, 0))
    period_indices = Enum.map(period_data, &elem(&1, 1))

    df_with_periods =
      df
      |> DataFrame.put("temporal_period", period_keys)
      |> DataFrame.put("period_index", period_indices)

    # Group by period and sort by period index
    period_keys
    |> Enum.uniq()
    |> Enum.map(fn period_key ->
      period_df =
        DataFrame.filter_with(df_with_periods, fn rows ->
          Series.equal(rows["temporal_period"], period_key)
        end)

      # Get the period index from the first row
      period_index =
        period_df["period_index"]
        |> Series.to_list()
        |> List.first()

      {period_key, period_df, period_index}
    end)
    |> Enum.sort_by(&elem(&1, 2))
    |> Enum.map(fn {period_key, period_df, _index} -> {period_key, period_df} end)
  end

  @doc """
  Summarizes a single time period.
  """
  @spec summarize_period(String.t(), DataFrame.t(), atom()) :: map()
  def summarize_period(period_key, period_df, segmentation_type) do
    dates = extract_date_range(period_df)
    messages = extract_messages(period_df)

    %{
      period_key: period_key,
      period_start: dates.start,
      period_end: dates.end,
      segmentation_type: segmentation_type,
      message_count: DataFrame.n_rows(period_df),
      messages_per_day: calculate_messages_per_day(period_df, dates),
      avg_response_time_minutes: calculate_avg_response_time(period_df),
      sentiment_distribution: extract_sentiment_scores(period_df),
      dominant_themes: extract_top_keywords(messages, 5),
      highest_activity_date: find_highest_activity_date(period_df),
      sender_breakdown: calculate_sender_breakdown(period_df)
    }
  end

  defp extract_date_range(period_df) do
    dates = period_df["datetime"] |> Series.to_list()
    %{start: Enum.min(dates), end: Enum.max(dates)}
  end

  defp calculate_messages_per_day(period_df, dates) do
    message_count = DataFrame.n_rows(period_df)
    days = max(Date.diff(NaiveDateTime.to_date(dates.end), NaiveDateTime.to_date(dates.start)), 1)
    Float.round(message_count / days, 1)
  end

  defp calculate_avg_response_time(period_df) do
    response_times =
      period_df["response_time_minutes"]
      |> Series.to_list()
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(response_times) do
      nil
    else
      (Enum.sum(response_times) / length(response_times)) |> Float.round(1)
    end
  end

  defp extract_sentiment_scores(period_df) do
    %{
      romantic: period_df["romantic_score"] |> Series.sum(),
      intimacy: period_df["intimacy_score"] |> Series.sum(),
      future_planning: period_df["future_planning_score"] |> Series.sum()
    }
  end

  defp extract_messages(period_df) do
    period_df["message"] |> Series.to_list()
  end

  defp calculate_sender_breakdown(period_df) do
    period_df
    |> DataFrame.group_by("sender")
    |> DataFrame.summarise(count: count(sender))
    |> DataFrame.to_rows()
    |> Enum.map(fn row -> {row["sender"], row["count"]} end)
    |> Map.new()
  end

  @doc """
  Formata o resumo temporal como texto markdown.
  """
  @spec format_as_markdown([map()], integer(), atom()) :: String.t()
  def format_as_markdown(period_summaries, total_days, segmentation_type) do
    """
    # Resumo Temporal da Conversa

    **Duração Total:** #{total_days} dias
    **Segmentação:** #{format_segmentation_type(segmentation_type)}
    **Total de Períodos:** #{length(period_summaries)}

    ---

    #{Enum.map_join(period_summaries, "\n\n---\n\n", &format_period_markdown/1)}
    """
  end

  # Private helper functions

  defp calculate_period_key(date, start_date, :weekly) do
    week_number = max(1, div(Date.diff(date, start_date), 7) + 1)
    "Semana #{week_number}"
  end

  defp calculate_period_key(date, start_date, :biweekly) do
    biweek_number = max(1, div(Date.diff(date, start_date), 14) + 1)
    "Período #{biweek_number}"
  end

  defp calculate_period_key(date, _start_date, :monthly) do
    Calendar.strftime(date, "%Y-%m")
  end

  defp calculate_period_index(date, start_date, :weekly) do
    max(0, div(Date.diff(date, start_date), 7))
  end

  defp calculate_period_index(date, start_date, :biweekly) do
    max(0, div(Date.diff(date, start_date), 14))
  end

  defp calculate_period_index(date, _start_date, :monthly) do
    date.year * 12 + date.month
  end

  # Stopwords em português
  @stopwords_pt MapSet.new([
                  "que",
                  "para",
                  "com",
                  "uma",
                  "você",
                  "voce",
                  "vc",
                  "ele",
                  "ela",
                  "por",
                  "como",
                  "mas",
                  "seu",
                  "sua",
                  "esse",
                  "essa",
                  "esta",
                  "este",
                  "isso",
                  "aqui",
                  "ali",
                  "muito",
                  "mais",
                  "quando",
                  "onde",
                  "porque",
                  "pq",
                  "qual",
                  "quem",
                  "depois",
                  "antes",
                  "sobre",
                  "foi",
                  "ser",
                  "ter",
                  "fazer",
                  "não",
                  "nao",
                  "sim",
                  "vai",
                  "pode",
                  "bem",
                  "todo",
                  "toda",
                  "até",
                  "ate",
                  "agora"
                ])

  defp extract_top_keywords(messages, top_n) do
    messages
    |> Enum.join(" ")
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.reject(&MapSet.member?(@stopwords_pt, &1))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> -count end)
    |> Enum.take(top_n)
    |> Enum.map(fn {word, _count} -> word end)
  end

  defp find_highest_activity_date(period_df) do
    period_df
    |> DataFrame.mutate(date_only: cast(datetime, :date))
    |> DataFrame.group_by("date_only")
    |> DataFrame.summarise(count: count(message))
    |> then(fn df ->
      if DataFrame.n_rows(df) > 0 do
        rows = DataFrame.to_rows(df)
        max_row = Enum.max_by(rows, & &1["count"])
        %{date: max_row["date_only"], count: max_row["count"]}
      else
        nil
      end
    end)
  rescue
    e in [ArithmeticError, KeyError] ->
      Logger.debug("Find highest activity date failed: #{Exception.message(e)}")
      nil
  end

  defp format_segmentation_type(:weekly), do: "Semanal"
  defp format_segmentation_type(:biweekly), do: "Quinzenal"
  defp format_segmentation_type(:monthly), do: "Mensal"

  defp format_period_markdown(period) do
    sentiment_text =
      period.sentiment_distribution
      |> Enum.map_join(", ", fn {key, value} -> "#{key}: #{value}" end)

    themes_text =
      if Enum.empty?(period.dominant_themes) do
        "Nenhum identificado"
      else
        Enum.join(period.dominant_themes, ", ")
      end

    activity_text =
      if period.highest_activity_date do
        "#{period.highest_activity_date.date} (#{period.highest_activity_date.count} mensagens)"
      else
        "N/D"
      end

    response_time_text =
      if period.avg_response_time_minutes do
        "#{period.avg_response_time_minutes} minutos"
      else
        "N/D"
      end

    """
    ## #{period.period_key}

    **Período:** #{format_datetime(period.period_start)} a #{format_datetime(period.period_end)}

    ### Métricas
    - **Mensagens:** #{period.message_count} (#{period.messages_per_day} por dia)
    - **Tempo Médio de Resposta:** #{response_time_text}
    - **Maior Atividade:** #{activity_text}

    ### Indicadores de Sentimento
    #{sentiment_text}

    ### Temas Dominantes
    #{themes_text}

    ### Distribuição por Remetente
    #{format_sender_breakdown(period.sender_breakdown)}
    """
  end

  defp format_sender_breakdown(sender_counts) do
    sender_counts
    |> Enum.map_join("\n", fn {sender, count} -> "- #{sender}: #{count} mensagens" end)
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end
end
