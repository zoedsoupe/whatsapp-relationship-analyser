defmodule WhatsAppAnalyzerWeb.AnalysisController do
  use WhatsAppAnalyzerWeb, :controller

  plug(:put_root_layout, false)
  plug(:put_layout, false)

  alias WhatsAppAnalyzer.AnalysisCache

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"upload" => %Plug.Upload{path: path}}) do
    # Generate unique ID for this analysis
    analysis_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    # Process the file
    case process_and_store(path, analysis_id) do
      :ok ->
        conn
        |> put_flash(:info, "Analysis completed successfully!")
        |> redirect(to: Routes.analysis_path(conn, :show, analysis_id))

      {:error, reason} ->
        conn
        |> put_flash(:error, "Analysis failed: #{inspect(reason)}")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Please upload a WhatsApp chat export file.")
    |> redirect(to: Routes.page_path(conn, :index))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    case AnalysisCache.get(id) do
      {:ok, results} ->
        render(conn, :show, results: results, analysis_id: id)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Analysis not found or expired.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  # Download action for temporal summary
  def download_summary(conn, %{"id" => id, "format" => format}) do
    case AnalysisCache.get(id) do
      {:ok, results} ->
        content = results.temporal_summary.summary_text

        case format do
          "txt" ->
            conn
            |> put_resp_content_type("text/plain")
            |> put_resp_header(
              "content-disposition",
              ~s(attachment; filename="temporal_summary.txt")
            )
            |> send_resp(200, content)

          "md" ->
            conn
            |> put_resp_content_type("text/markdown")
            |> put_resp_header(
              "content-disposition",
              ~s(attachment; filename="temporal_summary.md")
            )
            |> send_resp(200, content)

          _ ->
            conn
            |> put_flash(:error, "Invalid format")
            |> redirect(to: Routes.analysis_path(conn, :show, id))
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Analysis not found")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  @spec generate_summaries(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def generate_summaries(conn, %{"id" => id}) do
    case WhatsAppAnalyzer.SummaryGenerator.generate_summaries_async(id) do
      {:ok, :started} ->
        conn
        |> put_flash(:info, "Generating ML summaries... This may take a few moments.")
        |> redirect(to: Routes.analysis_path(conn, :show, id))

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Analysis not found")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  @spec summary_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def summary_status(conn, %{"id" => id}) do
    {:ok, status} = WhatsAppAnalyzer.SummaryGenerator.get_status(id)
    json(conn, status)
  end

  @spec process_and_store(Path.t(), String.t()) :: :ok | {:error, String.t()}
  defp process_and_store(file_path, analysis_id) do
    with {:ok, results} <- analyze_file(file_path),
         :ok <- validate_results(results),
         :ok <- AnalysisCache.put(analysis_id, serialize_results(results)) do
      :ok
    end
  end

  defp analyze_file(path) do
    try do
      {:ok, WhatsAppAnalyzer.analyze_chat(path)}
    rescue
      e in [File.Error, ArgumentError] -> {:error, Exception.message(e)}
    end
  end

  defp validate_results(%{error: err}), do: {:error, err}
  defp validate_results(_), do: :ok

  @spec serialize_results(map()) :: map()
  defp serialize_results(analysis_results) do
    # Extract sentiment excerpts from the data
    sentiment_excerpts = extract_sentiment_excerpts(analysis_results.data)

    # Convert analysis results to a serializable format for display
    %{
      total_messages: analysis_results.analysis.total_messages,
      total_days: analysis_results.analysis.time_span.days,
      avg_messages_per_day: analysis_results.analysis.messaging_frequency.messages_per_day,
      avg_response_time: analysis_results.analysis.response_patterns.overall_avg_minutes || 0,
      relationship_classification:
        analysis_results.analysis.relationship_classification.classification
        |> String.downcase()
        |> String.replace(" ", "_"),
      relationship_score: analysis_results.analysis.relationship_classification.score,
      sender_stats_chart: analysis_results.visualizations.sender_distribution,
      hourly_chart: analysis_results.visualizations.time_heatmap,
      daily_chart: analysis_results.visualizations.message_frequency,
      # New visualizations
      sentiment_timeline_chart: analysis_results.visualizations.sentiment_timeline,
      word_frequency_chart: analysis_results.visualizations.word_frequency,
      conversation_flow_chart: analysis_results.visualizations.conversation_flow,
      sentiment: %{
        romantic_count: analysis_results.analysis.romantic_indicators.total_indicators,
        future_planning_count: analysis_results.analysis.future_planning.total_indicators,
        intimacy_count: analysis_results.analysis.intimacy_indicators.total_indicators
      },
      sentiment_excerpts: sentiment_excerpts,
      conversation_segments: analysis_results.conversation_segments,
      temporal_summary: analysis_results.temporal_summary,
      # Store DataFrame for later ML summarization
      data: analysis_results.data
    }
  end

  @spec extract_sentiment_excerpts(Explorer.DataFrame.t()) :: map()
  defp extract_sentiment_excerpts(df) do
    alias WhatsAppAnalyzer.SentimentScorer

    %{
      romantic: SentimentScorer.extract_top_excerpts(df, :romantic, 10),
      intimacy: SentimentScorer.extract_top_excerpts(df, :intimacy, 10),
      future_planning: SentimentScorer.extract_top_excerpts(df, :future_planning, 10)
    }
  end
end
