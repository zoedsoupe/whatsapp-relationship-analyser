defmodule WhatsAppAnalyzerWeb.AnalysisControllerTest do
  use WhatsAppAnalyzerWeb.ConnCase, async: false

  @fixtures_path "test/fixtures"

  describe "POST /analyze" do
    test "handles file upload and redirects to results", %{conn: conn} do
      # Create a test upload
      upload = %Plug.Upload{
        path: Path.join(@fixtures_path, "normal_chat.txt"),
        filename: "normal_chat.txt"
      }

      conn = post(conn, Routes.analysis_path(conn, :create), %{"upload" => upload})

      assert redirected_to(conn) =~ "/results/"
      assert get_flash(conn, :info) == "Analysis completed successfully!"
    end

    test "handles empty file gracefully", %{conn: conn} do
      upload = %Plug.Upload{
        path: Path.join(@fixtures_path, "empty_chat.txt"),
        filename: "empty_chat.txt"
      }

      conn = post(conn, Routes.analysis_path(conn, :create), %{"upload" => upload})

      # Should still redirect but might show error
      assert redirected_to(conn) =~ "/"
    end

    test "handles system-only messages", %{conn: conn} do
      upload = %Plug.Upload{
        path: Path.join(@fixtures_path, "system_only_chat.txt"),
        filename: "system_only_chat.txt"
      }

      conn = post(conn, Routes.analysis_path(conn, :create), %{"upload" => upload})

      # Should handle gracefully
      assert redirected_to(conn) =~ "/"
    end

    test "requires upload parameter", %{conn: conn} do
      conn = post(conn, Routes.analysis_path(conn, :create), %{})

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :error) == "Please upload a WhatsApp chat export file."
    end
  end

  describe "GET /results/:id" do
    test "shows analysis results for valid ID", %{conn: conn} do
      # Insert test data into ETS
      analysis_id = "test_analysis_123"

      # Create a minimal VegaLite chart for testing
      test_chart = VegaLite.new(title: "Test Chart")
        |> VegaLite.data_from_values([%{x: 1, y: 2}])
        |> VegaLite.mark(:bar)

      test_results = %{
        total_messages: 10,
        total_days: 2,
        avg_messages_per_day: 5,
        avg_response_time: 30.5,
        relationship_classification: "friend",
        relationship_score: 45,
        sender_stats_chart: test_chart,
        hourly_chart: test_chart,
        daily_chart: test_chart,
        sentiment: %{
          romantic_count: 0,
          future_planning_count: 0,
          intimacy_count: 0
        },
        conversation_segments: []
      }

      :ets.insert(:analysis_results, {analysis_id, test_results})

      conn = get(conn, Routes.analysis_path(conn, :show, analysis_id))

      assert html_response(conn, 200) =~ "Analysis Results"
      assert html_response(conn, 200) =~ "10"  # total messages
    end

    test "redirects for invalid ID", %{conn: conn} do
      conn = get(conn, Routes.analysis_path(conn, :show, "nonexistent_id"))

      assert redirected_to(conn) == Routes.page_path(conn, :index)
      assert get_flash(conn, :error) == "Analysis not found or expired."
    end
  end
end
