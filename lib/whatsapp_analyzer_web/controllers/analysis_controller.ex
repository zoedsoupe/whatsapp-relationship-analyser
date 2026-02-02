defmodule WhatsAppAnalyzerWeb.AnalysisController do
  use WhatsAppAnalyzerWeb, :controller

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

  def show(conn, %{"id" => id}) do
    case :ets.lookup(:analysis_results, id) do
      [{^id, results}] ->
        html(conn, render_results_page(conn, results, id))

      [] ->
        conn
        |> put_flash(:error, "Analysis not found or expired.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end

  defp render_results_page(conn, results, _analysis_id) do
    alias WhatsAppAnalyzerWeb.VegaLiteHelper

    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8"/>
        <title>Analysis Results - WhatsApp Analyzer</title>
        <link rel="stylesheet" href="/css/app.css"/>
        <script src="https://cdn.jsdelivr.net/npm/vega@5"></script>
        <script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
        <script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
      </head>
      <body>
        <header>
          <nav>
            <h1>WhatsApp Relationship Analyzer</h1>
          </nav>
        </header>

        <main>
          <div class="container">
            <div class="analysis-header">
              <h2>Analysis Results</h2>
              <a href="#{Routes.page_path(conn, :index)}" class="btn-secondary">Analyze Another Chat</a>
            </div>

            <!-- Relationship Classification -->
            <div class="section">
              <h3>Relationship Classification</h3>
              <div class="classification-result">
                <div class="classification-badge #{results.relationship_classification}">
                  #{String.upcase(to_string(results.relationship_classification))}
                </div>
                <p class="confidence">Confidence Score: #{results.relationship_score}/100</p>
              </div>
            </div>

            <!-- Metrics Overview -->
            <div class="section">
              <h3>Key Metrics</h3>
              <div class="metrics-grid">
                <div class="metric-card">
                  <h4>Total Messages</h4>
                  <p class="metric-value">#{results.total_messages}</p>
                </div>
                <div class="metric-card">
                  <h4>Total Days</h4>
                  <p class="metric-value">#{results.total_days}</p>
                </div>
                <div class="metric-card">
                  <h4>Avg Messages/Day</h4>
                  <p class="metric-value">#{results.avg_messages_per_day}</p>
                </div>
                <div class="metric-card">
                  <h4>Response Time</h4>
                  <p class="metric-value">#{Float.round(results.avg_response_time, 1)} min</p>
                </div>
              </div>
            </div>

            <!-- Charts -->
            <div class="section">
              <h3>Messages by Sender</h3>
              #{VegaLiteHelper.embed_chart(results.sender_stats_chart, "sender-chart") |> Phoenix.HTML.safe_to_string()}
            </div>

            <!-- Sentiment -->
            <div class="section">
              <h3>Sentiment Overview</h3>
              <div class="metrics-grid">
                <div class="metric-card">
                  <h4>Romantic Indicators</h4>
                  <p class="metric-value">#{results.sentiment.romantic_count}</p>
                </div>
                <div class="metric-card">
                  <h4>Future Planning</h4>
                  <p class="metric-value">#{results.sentiment.future_planning_count}</p>
                </div>
                <div class="metric-card">
                  <h4>Intimacy Indicators</h4>
                  <p class="metric-value">#{results.sentiment.intimacy_count}</p>
                </div>
              </div>
            </div>

            <!-- Conversation Segments -->
            #{if length(results.conversation_segments) > 0 do
              render_conversation_segments(results.conversation_segments)
            else
              ""
            end}
          </div>
        </main>
      </body>
    </html>
    """
  end

  defp render_conversation_segments(segments) do
    """
    <div class="section">
      <h3>Conversation Segments</h3>
      <p>Total Conversations: #{length(segments)}</p>

      <div class="segments-list">
        #{Enum.take(segments, 10)
          |> Enum.map(&render_segment/1)
          |> Enum.join("\n")}
      </div>

      #{if length(segments) > 10 do
        ~s(<p class="note">Showing first 10 of #{length(segments)} conversations</p>)
      else
        ""
      end}
    </div>
    """
  end

  defp render_segment(segment) do
    """
    <div class="segment-card">
      <h4>Conversation ##{segment.conversation_id}</h4>
      <p><strong>Time:</strong> #{Calendar.strftime(segment.start_time, "%Y-%m-%d %H:%M")} - #{Calendar.strftime(segment.end_time, "%Y-%m-%d %H:%M")}</p>
      <p><strong>Messages:</strong> #{segment.message_count}</p>
      <p><strong>Participants:</strong> #{Enum.join(segment.participants, ", ")}</p>
    </div>
    """
  end

  defp process_and_store(file_path, analysis_id) do
    try do
      # Use the unified API which handles both regular and streaming parsing
      analysis_results = WhatsAppAnalyzer.analyze_chat(file_path)

      # Check if analysis was successful
      if Map.has_key?(analysis_results, :error) do
        {:error, analysis_results.error}
      else
        # Store results in ETS (temporary storage)
        :ets.insert(:analysis_results, {analysis_id, serialize_results(analysis_results)})
        :ok
      end
    rescue
      e ->
        {:error, Exception.message(e)}
    end
  end

  defp serialize_results(analysis_results) do
    # Convert analysis results to a serializable format for display
    %{
      total_messages: analysis_results.analysis.total_messages,
      total_days: analysis_results.analysis.time_span.days,
      avg_messages_per_day: analysis_results.analysis.messaging_frequency.messages_per_day,
      avg_response_time: analysis_results.analysis.response_patterns.overall_avg_minutes || 0,
      relationship_classification: analysis_results.analysis.relationship_classification.classification |> String.downcase() |> String.replace(" ", "_"),
      relationship_score: analysis_results.analysis.relationship_classification.score,
      sender_stats_chart: analysis_results.visualizations.sender_distribution,
      hourly_chart: analysis_results.visualizations.time_heatmap,
      daily_chart: analysis_results.visualizations.message_frequency,
      sentiment: %{
        romantic_count: analysis_results.analysis.romantic_indicators.total_indicators,
        future_planning_count: analysis_results.analysis.future_planning.total_indicators,
        intimacy_count: analysis_results.analysis.intimacy_indicators.total_indicators
      },
      conversation_segments: analysis_results.conversation_segments
    }
  end
end
