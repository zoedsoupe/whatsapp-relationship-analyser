defmodule WhatsAppAnalyzer.StreamingParser do
  @moduledoc """
  True streaming parser for large WhatsApp chat files.

  Processes files line-by-line using File.stream!/1 and processes
  messages in chunks to handle memory constraints efficiently.
  """

  require Explorer.DataFrame, as: DF

  alias WhatsAppAnalyzer.DataProcessor

  @doc """
  Parses a file using streaming for memory efficiency.

  Processes the file in chunks of 1000 messages, enhancing each chunk
  and combining at the end.
  """
  def parse_file_stream(file_path, chunk_size \\ 1000) do
    file_path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> parse_with_continuations()
    |> Stream.chunk_every(chunk_size)
    |> Stream.map(&messages_to_dataframe/1)
    |> Stream.map(&DataProcessor.enhance_dataframe/1)
    |> Enum.to_list()
    |> combine_dataframes()
  end

  @doc """
  Parses lines with stateful multiline message handling.

  Uses Stream.transform/3 to maintain state across line processing,
  accumulating continuation lines into the previous message.
  """
  def parse_with_continuations(lines) do
    Stream.transform(lines, nil, fn line, acc ->
      case parse_line(line) do
        {:ok, message} ->
          # New message found
          if acc do
            {[acc], message}
          else
            {[], message}
          end

        :error ->
          # Continuation line - append to accumulator
          if acc do
            updated = %{acc | message: acc.message <> "\n" <> line}
            {[], updated}
          else
            # No previous message, skip this line
            {[], nil}
          end
      end
    end)
    |> Stream.concat([:final])
    |> Stream.transform(nil, fn
      :final, acc ->
        if acc, do: {[acc], nil}, else: {[], nil}

      message, _acc ->
        {[message], nil}
    end)
  end

  defp parse_line(line) do
    # Normalize Unicode whitespace characters (WhatsApp exports sometimes contain U+202F)
    # U+00A0 (non-breaking space), U+202F (narrow no-break space), U+2009 (thin space)
    line = String.replace(line, <<0xC2, 0xA0>>, " ")  # U+00A0
    line = String.replace(line, <<0xE2, 0x80, 0xAF>>, " ")  # U+202F
    line = String.replace(line, <<0xE2, 0x80, 0x89>>, " ")  # U+2009

    # Match formats with and without seconds, with or without AM/PM
    date_time_pattern = ~r/\[(\d{2}\/\d{2}\/\d{2,4}), (\d{1,2}:\d{2}(?::\d{2})?(?: [AP]M)?)\] ([^:]+): (.+)/

    case Regex.run(date_time_pattern, line) do
      [_, date, time, sender, message] ->
        {:ok, %{
          datetime: parse_datetime(date, time),
          sender: String.trim(sender),
          message: String.trim(message)
        }}

      _ ->
        # Try to handle system messages
        if String.contains?(line, "[") && String.contains?(line, "]") do
          system_pattern = ~r/\[(\d{2}\/\d{2}\/\d{2,4}), (\d{1,2}:\d{2}(?::\d{2})?(?: [AP]M)?)\] (.+)/

          case Regex.run(system_pattern, line) do
            [_, date, time, system_message] ->
              {:ok, %{
                datetime: parse_datetime(date, time),
                sender: "SYSTEM",
                message: String.trim(system_message)
              }}

            _ -> :error
          end
        else
          :error
        end
    end
  end

  defp parse_datetime(date, time) do
    try do
      [day, month, year_str] = String.split(date, "/")

      day = String.to_integer(day)
      month = String.to_integer(month)

      year = case String.length(year_str) do
        2 -> 2000 + String.to_integer(year_str)
        4 -> String.to_integer(year_str)
        _ -> 2000 + String.to_integer(year_str)
      end

      # Check for AM/PM and extract it
      {time_str, am_pm} =
        if String.ends_with?(time, " AM") or String.ends_with?(time, " PM") do
          [t, period] = String.split(time, " ")
          {t, period}
        else
          {time, nil}
        end

      time_parts = String.split(time_str, ":")
      {hour, minute, second} = case length(time_parts) do
        2 ->
          [h, m] = Enum.map(time_parts, &String.to_integer/1)
          {h, m, 0}
        3 ->
          [h, m, s] = Enum.map(time_parts, &String.to_integer/1)
          {h, m, s}
      end

      # Convert 12-hour format to 24-hour format if AM/PM is present
      hour = case am_pm do
        "AM" ->
          if hour == 12, do: 0, else: hour
        "PM" ->
          if hour == 12, do: 12, else: hour + 12
        nil ->
          hour
      end

      case NaiveDateTime.new(year, month, day, hour, minute, second) do
        {:ok, datetime} -> datetime
        {:error, _} -> ~N[1970-01-01 00:00:00]
      end
    rescue
      _ -> ~N[1970-01-01 00:00:00]
    end
  end

  defp messages_to_dataframe(messages) do
    # Reject SYSTEM messages
    messages = Enum.reject(messages, & &1.sender == "SYSTEM")

    if Enum.empty?(messages) do
      # Return empty DataFrame with correct schema
      DF.new(datetime: [], sender: [], message: [])
    else
      DF.new(
        datetime: Enum.map(messages, & &1.datetime),
        sender: Enum.map(messages, & &1.sender),
        message: Enum.map(messages, & &1.message)
      )
    end
  end

  defp combine_dataframes([]), do: DF.new(datetime: [], sender: [], message: [])
  defp combine_dataframes([single]), do: single
  defp combine_dataframes(dfs) do
    Enum.reduce(dfs, fn df, acc ->
      DF.concat_rows(acc, df)
    end)
  end
end
