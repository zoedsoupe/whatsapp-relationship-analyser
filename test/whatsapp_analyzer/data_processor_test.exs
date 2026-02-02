defmodule WhatsAppAnalyzer.DataProcessorTest do
  use ExUnit.Case, async: true

  alias WhatsAppAnalyzer.DataProcessor
  alias WhatsAppAnalyzer.Parser

  require Explorer.DataFrame, as: DF

  @fixtures_path "test/fixtures"

  describe "empty DataFrame handling" do
    test "enhance_dataframe does not crash on empty DataFrame" do
      empty_df = DF.new(datetime: [], sender: [], message: [])

      result = DataProcessor.enhance_dataframe(empty_df)

      assert DF.n_rows(result) == 0
      # Should not crash and should return a DataFrame
      assert is_struct(result, DF)
    end

    test "process_file handles system-only messages gracefully" do
      path = Path.join(@fixtures_path, "system_only_chat.txt")

      # Should not crash even when all messages are filtered out
      result = DataProcessor.process_file(path)

      # All SYSTEM messages are filtered in messages_to_dataframe
      assert DF.n_rows(result) == 0
    end

    test "process_file handles empty file" do
      path = Path.join(@fixtures_path, "empty_chat.txt")

      result = DataProcessor.process_file(path)

      assert DF.n_rows(result) == 0
    end
  end

  describe "response time calculation" do
    test "calculates response times correctly for normal chat" do
      path = Path.join(@fixtures_path, "normal_chat.txt")

      df = DataProcessor.process_file(path)

      assert DF.n_rows(df) > 0
      assert "response_time_minutes" in DF.names(df)

      # First message should have nil response time
      first_response = df["response_time_minutes"] |> Explorer.Series.first()
      assert is_nil(first_response)
    end

    test "does not crash on empty DataFrame" do
      messages = []
      df = DataProcessor.messages_to_dataframe(messages)

      result = DataProcessor.enhance_dataframe(df)

      assert DF.n_rows(result) == 0
    end
  end

  describe "conversation markers" do
    test "adds conversation markers to normal chat" do
      path = Path.join(@fixtures_path, "normal_chat.txt")

      df = DataProcessor.process_file(path)

      assert "new_conversation" in DF.names(df)
      assert "conversation_id" in DF.names(df)
    end

    test "handles empty DataFrame for conversation markers" do
      empty_df = DF.new(datetime: [], sender: [], message: [])

      result = DataProcessor.enhance_dataframe(empty_df)

      assert DF.n_rows(result) == 0
      # Empty DataFrame returns early, so won't have enhanced columns
      # This is the expected behavior as per the fix for the crash
    end
  end

  describe "message length" do
    test "calculates message lengths correctly" do
      path = Path.join(@fixtures_path, "normal_chat.txt")

      df = DataProcessor.process_file(path)

      assert "message_length" in DF.names(df)
      assert "word_count" in DF.names(df)

      # All message lengths should be > 0 for normal messages
      lengths = df["message_length"] |> Explorer.Series.to_list()
      assert Enum.all?(lengths, &(&1 > 0))
    end
  end

  describe "time features" do
    test "adds time features correctly" do
      path = Path.join(@fixtures_path, "normal_chat.txt")

      df = DataProcessor.process_file(path)

      assert "date" in DF.names(df)
      assert "hour" in DF.names(df)
      assert "day_of_week" in DF.names(df)

      # Check that hours are in valid range
      hours = df["hour"] |> Explorer.Series.to_list()
      assert Enum.all?(hours, &(&1 >= 0 and &1 <= 23))

      # Check that days of week are in valid range
      days = df["day_of_week"] |> Explorer.Series.to_list()
      assert Enum.all?(days, &(&1 >= 1 and &1 <= 7))
    end
  end
end
