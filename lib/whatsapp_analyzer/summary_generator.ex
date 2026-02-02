defmodule WhatsAppAnalyzer.SummaryGenerator do
  @moduledoc """
  Handles user-triggered ML summarization of conversation segments.

  Provides async summarization with status tracking via ETS.
  """
  require Logger

  alias WhatsAppAnalyzer.AnalysisCache

  @ets_table :analysis_results

  @doc """
  Generates ML summaries for all conversation segments asynchronously.

  Returns {:ok, :started} if the task was started successfully.
  Returns {:error, :not_found} if the analysis ID doesn't exist.
  """
  def generate_summaries_async(analysis_id) do
    case AnalysisCache.get(analysis_id) do
      {:ok, results} ->
        set_status(analysis_id, :processing)

        {:ok, _pid} =
          Task.Supervisor.start_child(WhatsAppAnalyzer.TaskSupervisor, fn ->
            try do
              # Generate summaries for each segment
              updated_segments =
                Enum.map(results.conversation_segments, fn segment ->
                  # Extract messages from the original data
                  messages = extract_messages_for_segment(analysis_id, segment.conversation_id)

                  # Generate ML summary with fallback
                  summary =
                    WhatsAppAnalyzer.MLSummarizer.summarize_conversation_text(messages) ||
                      fallback_summary(messages)

                  Map.put(segment, :text_summary, summary)
                end)

              # Update results in cache
              updated_results = Map.put(results, :conversation_segments, updated_segments)
              AnalysisCache.put(analysis_id, updated_results)

              set_status(analysis_id, :completed)
              Logger.info("Completed ML summarization for analysis #{analysis_id}")
            rescue
              error ->
                Logger.error("Summary generation failed: #{inspect(error)}")
                set_status(analysis_id, :failed)
            end
          end)

        {:ok, :started}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets the current status of summary generation for an analysis.

  Returns {:ok, status_map} with keys:
    - :status - :pending, :processing, :completed, or :failed
    - :updated_at - timestamp of last update
  """
  def get_status(analysis_id) do
    case :ets.lookup(@ets_table, {analysis_id, :summary_status}) do
      [{_, status}] -> {:ok, status}
      [] -> {:ok, %{status: :pending, updated_at: nil}}
    end
  end

  # Private functions

  defp set_status(analysis_id, status) do
    data = %{status: status, updated_at: DateTime.utc_now()}
    :ets.insert(@ets_table, {{analysis_id, :summary_status}, data})
  end

  defp extract_messages_for_segment(analysis_id, conversation_id) do
    # Retrieve the original dataframe from ETS and filter by conversation_id
    require Explorer.DataFrame, as: DF
    require Explorer.Series, as: S

    with {:ok, results} <- AnalysisCache.get(analysis_id),
         df when not is_nil(df) <- results.data,
         true <- DF.n_rows(df) > 0 do
      df
      |> DF.filter_with(fn rows -> S.equal(rows["conversation_id"], conversation_id) end)
      |> then(& &1["message"])
      |> S.to_list()
    else
      _ -> []
    end
  end

  defp fallback_summary(messages) do
    # Extract key topics using simple frequency analysis
    topics =
      messages
      |> Enum.join(" ")
      |> String.downcase()
      |> String.split(~r/\W+/, trim: true)
      |> Enum.filter(&(String.length(&1) > 3))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_word, count} -> -count end)
      |> Enum.take(3)
      |> Enum.map(fn {word, _count} -> word end)

    if Enum.empty?(topics) do
      "Conversation with #{length(messages)} messages"
    else
      "Discussion about: #{Enum.join(topics, ", ")}"
    end
  end
end
