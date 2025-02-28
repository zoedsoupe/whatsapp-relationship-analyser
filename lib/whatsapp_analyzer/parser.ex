defmodule WhatsAppAnalyzer.Parser do
  @moduledoc """
  Parses WhatsApp chat export files into structured data.
  """

  @doc """
  Parses a WhatsApp chat export file into a list of message maps.
  
  ## Parameters
    - file_path: Path to the WhatsApp chat export file
    
  ## Returns
    - List of message maps with keys:
      - :datetime - NaiveDateTime
      - :sender - String
      - :message - String
  """
  def parse_file(file_path) do
    File.read!(file_path)
    |> String.split("\n")
    |> Enum.filter(&(String.length(&1) > 0))
    |> parse_lines([])
  end

  defp parse_lines([], acc), do: Enum.reverse(acc)
  defp parse_lines([line | rest], acc) do
    case parse_line(line) do
      {:ok, message} -> parse_lines(rest, [message | acc])
      :error -> parse_lines(rest, acc)
    end
  end

  defp parse_line(line) do
    # Match both formats with and without seconds
    # [DD/MM/YY, HH:MM:SS] Sender: Message or [DD/MM/YY, HH:MM] Sender: Message
    date_time_pattern = ~r/\[(\d{2}\/\d{2}\/\d{2,4}), (\d{1,2}:\d{2}(?::\d{2})?)\] ([^:]+): (.+)/

    case Regex.run(date_time_pattern, line) do
      [_, date, time, sender, message] ->
        {:ok, %{
          datetime: parse_datetime(date, time),
          sender: String.trim(sender),
          message: String.trim(message)
        }}
      _ -> 
        # Try to handle system messages or other non-standard formats
        if String.contains?(line, "[") && String.contains?(line, "]") do
          # It's likely a system message
          system_pattern = ~r/\[(\d{2}\/\d{2}\/\d{2,4}), (\d{1,2}:\d{2}(?::\d{2})?)\] (.+)/
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
          # It might be a continuation of a previous message
          :error
        end
    end
  end

  defp parse_datetime(date, time) do
    # Handle both date formats: DD/MM/YY and DD/MM/YYYY
    [day, month, year_str] = String.split(date, "/")
    
    day = String.to_integer(day)
    month = String.to_integer(month)
    
    # Adjust year if needed (e.g., "22" -> 2022)
    year = case String.length(year_str) do
      2 -> 2000 + String.to_integer(year_str)
      4 -> String.to_integer(year_str)
      _ -> 2000 + String.to_integer(year_str)
    end
    
    # Handle time both with and without seconds
    time_parts = String.split(time, ":")
    {hour, minute, second} = case length(time_parts) do
      2 -> 
        [h, m] = Enum.map(time_parts, &String.to_integer/1)
        {h, m, 0}
      3 -> 
        [h, m, s] = Enum.map(time_parts, &String.to_integer/1)
        {h, m, s}
    end
    
    {:ok, datetime} = NaiveDateTime.new(year, month, day, hour, minute, second)
    datetime
  end
end
