defmodule WhatsAppAnalyzer.MLSummarizer do
  @moduledoc """
  ML-based conversation summarization using Bumblebee.

  This module provides text summarization capabilities for conversation
  segments using the facebook/bart-large-cnn model.
  """

  require Logger

  @max_input_length 1024

  @doc """
  Summarizes conversation text using a pre-trained model.

  ## Options
    - `:enable_ml` - Set to true to enable ML summarization (default: true)
    - `:max_length` - Maximum length of summary in tokens (default: 100)
    - `:min_length` - Minimum length of summary in tokens (default: 30)

  ## Returns
    - Summary text string if ML is enabled
    - nil if ML is disabled or an error occurs
  """
  def summarize_conversation_text(messages, opts \\ []) do
    if Keyword.get(opts, :enable_ml, true) do
      perform_ml_summarization(messages)
    else
      nil
    end
  end

  defp perform_ml_summarization(messages) when is_list(messages) do
    text = prepare_text(messages)
    do_ml_summarization(text, messages)
  end

  defp perform_ml_summarization(_), do: nil

  defp do_ml_summarization("", _messages), do: nil

  defp do_ml_summarization(text, messages) when is_binary(text) do
    case run_ml_model(text) do
      {:ok, summary} -> summary
      {:error, _} -> fallback_summary(messages)
    end
  end

  defp run_ml_model(text) do
    try do
      result = Nx.Serving.batched_run(WhatsAppAnalyzer.Serving.Summarizer, text)
      parse_ml_result(result)
    rescue
      e in [RuntimeError, ArgumentError, FunctionClauseError] ->
        Logger.warning("ML failed: #{Exception.message(e)}")
        {:error, e}
    end
  end

  defp parse_ml_result(%{results: [%{text: summary}]}) when is_binary(summary), do: {:ok, summary}

  defp parse_ml_result(_result) do
    Logger.warning("ML summarization returned unexpected format")
    {:error, :invalid_format}
  end

  # Prepares conversation text for summarization
  defp prepare_text(messages) do
    messages
    |> Enum.map_join(" ", fn
      msg when is_binary(msg) -> msg
      %{message: msg} -> msg
      _ -> ""
    end)
    |> String.slice(0, @max_input_length)
  end

  # Fallback summarization using keyword extraction
  defp fallback_summary(messages) do
    topics = extract_key_topics(messages, 5)

    if Enum.empty?(topics) do
      "Conversation with #{length(messages)} messages"
    else
      "Discussion about: #{Enum.join(topics, ", ")}"
    end
  end

  @doc """
  Extracts key topics from a conversation using simple keyword extraction.

  This is a lightweight alternative to full ML summarization.
  """
  def extract_key_topics(messages, top_n \\ 5) do
    # Simple frequency-based keyword extraction
    all_text = Enum.join(messages, " ")

    all_text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    # Only words longer than 3 chars
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> -count end)
    |> Enum.take(top_n)
    |> Enum.map(fn {word, count} -> "#{word} (#{count})" end)
  end

  @doc """
  Analyzes sentiment of conversation messages.

  Returns a simple sentiment score based on keyword presence.
  This is a lightweight alternative to ML-based sentiment analysis.
  """
  def analyze_sentiment(messages) do
    positive_words = ~w[love happy great good amazing wonderful excellent nice beautiful]
    negative_words = ~w[hate sad bad terrible awful horrible upset angry frustrated]

    all_text = messages |> Enum.join(" ") |> String.downcase()

    positive_count = Enum.count(positive_words, &String.contains?(all_text, &1))
    negative_count = Enum.count(negative_words, &String.contains?(all_text, &1))

    total = positive_count + negative_count

    sentiment =
      cond do
        total == 0 -> :neutral
        positive_count > negative_count -> :positive
        negative_count > positive_count -> :negative
        true -> :neutral
      end

    %{
      sentiment: sentiment,
      positive_count: positive_count,
      negative_count: negative_count,
      score: if(total > 0, do: (positive_count - negative_count) / total, else: 0)
    }
  end
end
