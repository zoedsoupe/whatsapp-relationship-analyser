defmodule WhatsAppAnalyzer.SentimentScorer do
  @moduledoc """
  Análise de sentimento usando keywords em português.
  Suporte opcional a ML com fallback para keywords.
  """

  alias Explorer.{DataFrame, Series}
  alias WhatsAppAnalyzer.{AppConfig, Keywords}

  require Logger
  require Explorer.DataFrame

  @doc """
  Analisa sentimento de uma mensagem usando keywords.
  """
  def score_message(message) when is_binary(message) do
    message_lower = String.downcase(message)

    %{
      romantic: count_keywords(message_lower, Keywords.romantic()),
      intimacy: count_keywords(message_lower, Keywords.intimacy()),
      future_planning: count_keywords(message_lower, Keywords.future_planning())
    }
  end

  def score_message(_), do: zero_scores()

  @doc """
  Analisa sentimento com ML ou fallback para keywords.

  ## Opções
    - :use_ml - true para usar ML (default: false)
  """
  def score_message_ml(message, opts \\ [])

  def score_message_ml(message, opts) when is_binary(message) do
    if Keyword.get(opts, :use_ml, false) do
      try do
        result = Nx.Serving.batched_run(WhatsAppAnalyzer.Serving.Sentiment, message)
        parse_ml_sentiment(result)
      rescue
        e in [RuntimeError, ArgumentError, FunctionClauseError] ->
          Logger.warning("ML falhou, usando keywords: #{Exception.message(e)}")
          score_message(message)
      end
    else
      score_message(message)
    end
  end

  def score_message_ml(_, _opts), do: zero_scores()

  @doc """
  Adiciona colunas de sentimento ao DataFrame.
  """
  def add_sentiment_columns(%DataFrame{} = df) do
    messages = df |> DataFrame.pull("message") |> Series.to_list()
    message_types = df |> DataFrame.pull("message_type") |> Series.to_list()

    scores =
      Enum.zip(messages, message_types)
      |> Enum.map(fn {message, type} ->
        if type == "text", do: score_message(message), else: zero_scores()
      end)

    df
    |> DataFrame.put("romantic_score", Enum.map(scores, & &1.romantic))
    |> DataFrame.put("intimacy_score", Enum.map(scores, & &1.intimacy))
    |> DataFrame.put("future_planning_score", Enum.map(scores, & &1.future_planning))
  end

  @doc """
  Extrai top mensagens por categoria de sentimento.
  """
  def extract_top_excerpts(%DataFrame{} = df, category, limit \\ 10)
      when category in [:romantic, :intimacy, :future_planning] do
    score_column = "#{category}_score"

    excerpts =
      df
      |> DataFrame.filter_with(&Series.equal(&1["message_type"], "text"))
      |> DataFrame.sort_by(desc: ^score_column)
      |> DataFrame.slice(0, limit)
      |> DataFrame.select(["datetime", "sender", "message", score_column])
      |> DataFrame.to_rows()
      |> Enum.map(&format_excerpt(&1, score_column))

    Logger.debug("Extracted #{length(excerpts)} excerpts for #{category}")
    excerpts
  rescue
    e in [ArithmeticError, KeyError, ArgumentError] ->
      Logger.debug("Extract excerpts failed: #{Exception.message(e)}")
      []
  end

  # Privado

  defp count_keywords(message, keywords) do
    Enum.count(keywords, &String.contains?(message, String.downcase(&1)))
  end

  defp parse_ml_sentiment(%{predictions: [%{label: label, score: confidence}]}) do
    # Usa fatores configurados (sem magic numbers)
    romantic_factor = AppConfig.ml_romantic_factor()
    intimacy_factor = AppConfig.ml_intimacy_factor()

    base = %{
      romantic: 0,
      intimacy: 0,
      future_planning: 0,
      label: normalize_label(label),
      confidence: confidence
    }

    case normalize_label(label) do
      :positive ->
        %{
          base
          | romantic: round(confidence * romantic_factor),
            intimacy: round(confidence * intimacy_factor)
        }

      _ ->
        base
    end
  end

  defp parse_ml_sentiment(_), do: zero_scores()

  defp normalize_label(label) when is_binary(label) do
    case String.upcase(label) do
      l when l in ["POSITIVE", "POSITIVO", "POS"] -> :positive
      l when l in ["NEGATIVE", "NEGATIVO", "NEG"] -> :negative
      _ -> :neutral
    end
  end

  defp normalize_label(_), do: :neutral

  defp zero_scores, do: %{romantic: 0, intimacy: 0, future_planning: 0}

  defp format_excerpt(row, score_column) do
    %{
      datetime: row["datetime"],
      sender: row["sender"],
      message: row["message"],
      score: row[score_column] || 0
    }
  end
end
