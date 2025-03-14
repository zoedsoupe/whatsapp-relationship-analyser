defmodule WhatsAppAnalyzer.RelationshipAnalyzer do
  @moduledoc """
  Analyzes WhatsApp conversation data to extract relationship indicators.
  """

  require Explorer.DataFrame, as: DF
  require Explorer.Series, as: S

  @romantic_indicators [
    # Portuguese terms
    "amor",
    "amo",
    "amo você",
    "te amo",
    "amorzinho",
    "meu amor",
    "minha vida",
    "querido",
    "querida",
    "saudade",
    "sinto sua falta",
    "beijo",
    "beijinho",
    "gostoso",
    "gostosa",
    "lindo",
    "linda",
    "tesão",
    "sdds",
    "apaixonado",
    "apaixonada",
    "namorar",
    "namorado",
    "namorada",
    "carinho",

    # English terms
    "love",
    "miss you",
    "missing you",
    "darling",
    "babe",
    "baby",
    "honey",
    "sweetheart",
    "beautiful",
    "gorgeous",
    "handsome",
    "kiss",
    "kisses",
    "boyfriend",
    "girlfriend",
    "passion",
    "passionate",
    "romantic",
    "date"
  ]

  @future_planning [
    # Portuguese
    "planejar",
    "futuro",
    "morar",
    "juntos",
    "juntas",
    "casa",
    "viajar",
    "férias",
    "feriado",
    "fim de semana",
    "amanhã",
    "semana que vem",

    # English
    "plan",
    "future",
    "live together",
    "house",
    "travel",
    "vacation",
    "holiday",
    "weekend",
    "tomorrow",
    "next week"
  ]

  @intimacy_indicators [
    # Portuguese
    "sinto",
    "sentir",
    "sentimento",
    "emoção",
    "confiar",
    "confio",
    "segredo",
    "pessoal",
    "íntimo",
    "íntima",
    "vulnerável",
    "abrir",
    "coração",
    "alma",

    # English
    "feel",
    "feeling",
    "emotion",
    "trust",
    "secret",
    "personal",
    "intimate",
    "vulnerable",
    "open up",
    "heart",
    "soul"
  ]

  @doc """
  Analyzes a DF with conversation data to extract relationship indicators.
  Returns a map of analysis results.
  """
  def analyze_relationship(df) do
    df = DF.sort_by(df, datetime)

    %{
      total_messages: DF.n_rows(df),
      time_span: get_time_span(df),

      messaging_frequency: calculate_messaging_frequency(df),
      response_patterns: analyze_response_patterns(df),
      conversation_initiation: analyze_conversation_initiation(df),

      romantic_indicators: count_indicators(df, @romantic_indicators),
      future_planning: count_indicators(df, @future_planning),
      intimacy_indicators: count_indicators(df, @intimacy_indicators),

      time_of_day_patterns: analyze_time_of_day(df),
      day_of_week_patterns: analyze_day_of_week(df),

      relationship_classification: classify_relationship(df)
    }
  end

  @doc """
  Provides summary metrics for a quick overview of the relationship.
  """
  def relationship_summary(df) do
    senders =
      df["sender"]
      |> S.distinct()
      |> S.to_list()
      |> Enum.reject(&(&1 == "SYSTEM"))

    message_counts =
      Enum.map(senders, fn sender ->
        count =
          df
          |> DF.filter_with(fn rows -> S.equal(rows["sender"], sender) end)
          |> DF.n_rows()

        {sender, count}
      end)
      |> Map.new()

    avg_lengths =
      Enum.map(senders, fn sender ->
        avg =
          df
          |> DF.filter_with(fn rows -> S.equal(rows["sender"], sender) end)
          |> DF.pull("message_length")
          |> S.mean()

        {sender, avg}
      end)
      |> Map.new()

    romantic_count = count_indicators(df, @romantic_indicators)

    initiations = analyze_conversation_initiation(df)

    classification = classify_relationship(df)

    %{
      senders: senders,
      message_counts: message_counts,
      avg_message_length: avg_lengths,
      romantic_indicator_count: romantic_count,
      conversation_initiations: initiations,
      classification: classification
    }
  end

  # Helper functions

  defp get_time_span(df) do
    first_date = df["datetime"] |> S.min()
    last_date = df["datetime"] |> S.max()

    days = NaiveDateTime.diff(last_date, first_date) / (60 * 60 * 24)

    %{
      first_message: first_date,
      last_message: last_date,
      days: Float.round(days, 1),
      months: Float.round(days / 30, 1)
    }
  end

  defp calculate_messaging_frequency(df) do
    %{days: days} = get_time_span(df)

    messages_per_day = DF.n_rows(df) / days

    messages_by_sender =
      df["sender"]
      |> S.frequencies()
      |> DF.to_rows()
      |> Enum.map(fn %{"counts" => count, "values" => sender} -> {sender, count / days} end)
      |> Map.new()

    %{
      messages_per_day: Float.round(messages_per_day, 2),
      by_sender: messages_by_sender
    }
  end

  defp analyze_response_patterns(df) do
    response_df =
      df
      |> DF.filter_with(fn rows -> S.is_not_nil(rows["response_time_minutes"]) end)

    avg_response_time = response_df["response_time_minutes"] |> S.mean()

    senders =
      df["sender"]
      |> S.distinct()
      |> S.to_list()
      |> Enum.reject(&(&1 == "SYSTEM"))

    response_by_sender =
      Enum.map(senders, fn sender ->
        sender_responses =
          response_df
          |> DF.filter_with(fn rows -> S.equal(rows["sender"], sender) end)

        avg_time =
          if DF.n_rows(sender_responses) > 0 do
            sender_responses["response_time_minutes"] |> S.mean()
          else
            nil
          end

        {sender, avg_time}
      end)
      |> Enum.reject(fn {_, time} -> is_nil(time) end)
      |> Map.new()

    %{
      overall_avg_minutes: avg_response_time,
      by_sender: response_by_sender
    }
  end

  defp analyze_conversation_initiation(df) do
    initiations =
      df
      |> DF.filter_with(fn rows -> S.equal(rows["new_conversation"], 1) end)
      |> DF.group_by("sender")
      |> DF.summarise(count: count(sender))
      |> DF.to_rows()
      |> Enum.map(fn row -> {row["sender"], row["count"]} end)
      |> Map.new()

    total_conversations = df["new_conversation"] |> S.sum()

    initiation_percentage =
      initiations
      |> Enum.map(fn {sender, count} ->
        {sender, Float.round(count / total_conversations * 100, 1)}
      end)
      |> Map.new()

    %{
      total_conversations: total_conversations,
      initiations_by_sender: initiations,
      initiation_percentage: initiation_percentage
    }
  end

  defp count_indicators(df, indicator_list) do
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

    indicator_percentage = messages_with_indicators / DF.n_rows(df) * 100

    %{
      total_indicators: total_indicators,
      by_sender: indicators_by_sender,
      percentage_of_messages: Float.round(indicator_percentage, 1)
    }
  end

  defp analyze_time_of_day(df) do
    time_periods = [
      {"morning", 5, 11},
      {"afternoon", 12, 17},
      {"evening", 18, 22},
      {"night", 23, 4}
    ]

    time_period =
      df["hour"]
      |> S.transform(fn hour ->
        Enum.find_value(time_periods, "other", fn {period, start, end_hour} ->
          if start <= end_hour do
            if hour >= start && hour <= end_hour, do: period
          else
            if hour >= start || hour <= end_hour, do: period
          end
        end)
      end)

    df_with_period = DF.put(df, "time_period", time_period)

    time_distribution =
      df_with_period
      |> DF.group_by("time_period")
      |> DF.summarise(count: count(time_period))
      |> DF.to_rows()
      |> Enum.map(fn row -> {row["time_period"], row["count"]} end)
      |> Map.new()

    total = DF.n_rows(df)

    percentage_distribution =
      time_distribution
      |> Enum.map(fn {period, count} ->
        {period, Float.round(count / total * 100, 1)}
      end)
      |> Map.new()

    %{
      count_by_period: time_distribution,
      percentage_by_period: percentage_distribution
    }
  end

  defp analyze_day_of_week(df) do
    day_names = %{
      1 => "Monday",
      2 => "Tuesday",
      3 => "Wednesday",
      4 => "Thursday",
      5 => "Friday",
      6 => "Saturday",
      7 => "Sunday"
    }

    day_name =
      df["day_of_week"]
      |> S.transform(fn day -> Map.get(day_names, day) end)

    df_with_day_names = DF.put(df, "day_name", day_name)

    day_distribution =
      df_with_day_names
      |> DF.group_by("day_name")
      |> DF.summarise(count: count(day_name))
      |> DF.to_rows()
      |> Enum.map(fn row -> {row["day_name"], row["count"]} end)
      |> Map.new()

    total = DF.n_rows(df)

    percentage_distribution =
      day_distribution
      |> Enum.map(fn {day, count} ->
        {day, Float.round(count / total * 100, 1)}
      end)
      |> Map.new()

    weekday_count =
      Enum.sum(for day <- 1..5, do: Map.get(day_distribution, Map.get(day_names, day), 0))

    weekend_count =
      Enum.sum(for day <- 6..7, do: Map.get(day_distribution, Map.get(day_names, day), 0))

    %{
      count_by_day: day_distribution,
      percentage_by_day: percentage_distribution,
      weekday_vs_weekend: %{
        weekday: weekday_count,
        weekend: weekend_count,
        weekday_percentage: Float.round(weekday_count / total * 100, 1),
        weekend_percentage: Float.round(weekend_count / total * 100, 1)
      }
    }
  end

  defp classify_relationship(df) do
    romantic_score = count_indicators(df, @romantic_indicators)
    intimacy_score = count_indicators(df, @intimacy_indicators)
    future_planning_score = count_indicators(df, @future_planning)

    %{messages_per_day: messages_per_day} = calculate_messaging_frequency(df)

    # maybe use it later?
    # _conversation_patterns = analyze_conversation_initiation(df)
    response_patterns = analyze_response_patterns(df)

    weights = %{
      romantic_indicators: 0.35,
      intimacy: 0.25,
      future_planning: 0.15,
      messaging_frequency: 0.15,
      response_time: 0.10,
      conversation_initiation: 0.10
    }

    romantic_normalized = min(romantic_score.percentage_of_messages * 5, 100)
    intimacy_normalized = min(intimacy_score.percentage_of_messages * 5, 100)
    future_normalized = min(future_planning_score.percentage_of_messages * 10, 100)

    frequency_normalized = min(messages_per_day / 20 * 100, 100)

    response_normalized =
      if is_nil(response_patterns.overall_avg_minutes) do
        50
      else
        max(100 - response_patterns.overall_avg_minutes * 2, 0)
      end

    weighted_score =
      romantic_normalized * weights.romantic_indicators +
        intimacy_normalized * weights.intimacy +
        future_normalized * weights.future_planning +
        frequency_normalized * weights.messaging_frequency +
        response_normalized * weights.response_time

    classification =
      cond do
        weighted_score >= 70 -> "Romantic"
        weighted_score >= 40 -> "Close Friend"
        weighted_score >= 20 -> "Friend"
        true -> "Acquaintance"
      end

    %{
      classification: classification,
      score: round(weighted_score),
      component_scores: %{
        romantic_indicators: round(romantic_normalized),
        intimacy: round(intimacy_normalized),
        future_planning: round(future_normalized),
        messaging_frequency: round(frequency_normalized),
        response_time: response_normalized
      }
    }
  end
end
