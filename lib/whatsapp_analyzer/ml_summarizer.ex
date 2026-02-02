defmodule WhatsAppAnalyzer.MLSummarizer do
  @moduledoc """
  Optional ML-based conversation summarization using Bumblebee.

  This module provides text summarization capabilities for conversation
  segments. It's only used when explicitly enabled by the user.
  """

  @doc """
  Summarizes conversation text using a pre-trained model.

  ## Options
    - `:enable_ml` - Set to true to enable ML summarization (default: false)
    - `:max_length` - Maximum length of summary in tokens (default: 100)
    - `:min_length` - Minimum length of summary in tokens (default: 30)

  ## Returns
    - Summary text string if ML is enabled
    - nil if ML is disabled
  """
  def summarize_conversation_text(messages, opts \\ []) do
    if Keyword.get(opts, :enable_ml, false) do
      perform_summarization(messages, opts)
    else
      nil
    end
  end

  defp perform_summarization(_messages, opts) do
    # TODO: Implement actual Bumblebee summarization
    # This would require:
    # 1. Loading a summarization model (e.g., BART, T5)
    # 2. Concatenating messages into a single text
    # 3. Running inference
    # 4. Returning the summary

    # For now, return a placeholder
    max_length = Keyword.get(opts, :max_length, 100)
    min_length = Keyword.get(opts, :min_length, 30)

    """
    [ML Summarization Not Yet Implemented]

    This would use Bumblebee to generate a summary of the conversation
    with max_length: #{max_length}, min_length: #{min_length}.

    To implement:
    1. Load a summarization model (e.g., facebook/bart-large-cnn)
    2. Prepare input text from messages
    3. Run model inference
    4. Return generated summary
    """
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
