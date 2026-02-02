defmodule WhatsAppAnalyzer.ParserTest do
  use ExUnit.Case, async: true

  alias WhatsAppAnalyzer.Parser

  @fixtures_path "test/fixtures"

  describe "parse_file/1" do
    test "handles empty chat file" do
      path = Path.join(@fixtures_path, "empty_chat.txt")
      messages = Parser.parse_file(path)

      assert messages == []
    end

    test "handles system-only messages" do
      path = Path.join(@fixtures_path, "system_only_chat.txt")
      messages = Parser.parse_file(path)

      assert length(messages) == 3
      assert Enum.all?(messages, &(&1.sender == "SYSTEM"))
    end

    test "preserves multiline messages" do
      path = Path.join(@fixtures_path, "multiline_chat.txt")
      messages = Parser.parse_file(path)

      # Find Bob's first multiline message
      bobs_first_msg =
        Enum.find(messages, &(&1.sender == "Bob" && String.contains?(&1.message, "big project")))

      assert bobs_first_msg != nil
      assert String.contains?(bobs_first_msg.message, "I'm doing great!")
      assert String.contains?(bobs_first_msg.message, "Just finished a big project")
      assert String.contains?(bobs_first_msg.message, "It was really challenging")
    end

    test "parses normal chat correctly" do
      path = Path.join(@fixtures_path, "normal_chat.txt")
      messages = Parser.parse_file(path)

      assert messages != []
      assert Enum.any?(messages, &(&1.sender == "Alice"))
      assert Enum.any?(messages, &(&1.sender == "Bob"))
    end

    test "handles date parsing without crashes" do
      path = Path.join(@fixtures_path, "normal_chat.txt")

      assert_raise File.Error, fn ->
        Parser.parse_file("nonexistent.txt")
      end

      # Should not crash on valid file
      messages = Parser.parse_file(path)
      assert is_list(messages)
    end

    test "handles romantic indicators" do
      path = Path.join(@fixtures_path, "romantic_chat.txt")
      messages = Parser.parse_file(path)

      assert messages != []

      romantic_message = Enum.find(messages, &String.contains?(&1.message, "amor"))
      assert romantic_message != nil
      assert romantic_message.sender in ["João", "Maria"]
    end
  end

  describe "datetime parsing" do
    test "handles dates without crashing on invalid input" do
      path = Path.join(@fixtures_path, "normal_chat.txt")
      messages = Parser.parse_file(path)

      # All messages should have valid datetimes (or fallback datetime)
      assert Enum.all?(messages, fn msg ->
               is_struct(msg.datetime, NaiveDateTime)
             end)
    end
  end
end
