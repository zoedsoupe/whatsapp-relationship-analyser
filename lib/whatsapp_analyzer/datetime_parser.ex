defmodule WhatsAppAnalyzer.DateTimeParser do
  @moduledoc """
  Shared datetime parsing utilities for WhatsApp chat exports.

  Handles multiple formats:
  - Date formats: DD/MM/YY or DD/MM/YYYY
  - Time formats: 12h (with AM/PM) or 24h
  - With or without seconds in time

  Also handles Unicode whitespace normalization present in some WhatsApp exports.
  """

  require Logger

  @message_pattern ~r/\[(\d{2}\/\d{2}\/\d{2,4}), (\d{1,2}:\d{2}(?::\d{2})?(?: [AP]M)?)\] ([^:]+): (.+)/
  @system_pattern ~r/\[(\d{2}\/\d{2}\/\d{2,4}), (\d{1,2}:\d{2}(?::\d{2})?(?: [AP]M)?)\] (.+)/

  @unicode_spaces [
    # U+00A0 non-breaking space
    <<0xC2, 0xA0>>,
    # U+202F narrow no-break space
    <<0xE2, 0x80, 0xAF>>,
    # U+2009 thin space
    <<0xE2, 0x80, 0x89>>
  ]

  @type message :: %{
          datetime: NaiveDateTime.t(),
          sender: String.t(),
          message: String.t()
        }

  @doc """
  Normalizes Unicode whitespace characters to standard ASCII space.

  WhatsApp exports sometimes contain special Unicode whitespace characters
  that need to be normalized for proper parsing.
  """
  @spec normalize_unicode(String.t()) :: String.t()
  def normalize_unicode(line) do
    Enum.reduce(@unicode_spaces, line, fn unicode_char, acc ->
      String.replace(acc, unicode_char, " ")
    end)
  end

  @doc """
  Parses a single line from a WhatsApp chat export.

  Attempts to match:
  1. Regular message format: [DD/MM/YY, HH:MM] Sender: Message
  2. System message format: [DD/MM/YY, HH:MM] System Message

  Returns {:ok, message_map} on success or :error if line doesn't match expected format.
  """
  @spec parse_line(String.t()) :: {:ok, message()} | :error
  def parse_line(line) do
    line = normalize_unicode(line)

    case Regex.run(@message_pattern, line) do
      [_, date, time, sender, message] ->
        {:ok, build_message(date, time, sender, message)}

      _ ->
        parse_system_message(line)
    end
  end

  @doc """
  Parses date and time strings into a NaiveDateTime.

  Handles multiple date formats (2-digit or 4-digit year) and time formats
  (12h with AM/PM or 24h), with or without seconds.

  Returns a fallback datetime (~N[1970-01-01 00:00:00]) if parsing fails,
  logging a warning in such cases.
  """
  @spec parse_datetime(String.t(), String.t()) :: NaiveDateTime.t()
  def parse_datetime(date, time) do
    case do_parse_datetime(date, time) do
      {:ok, datetime} ->
        datetime

      {:error, reason} ->
        Logger.warning("Failed to parse datetime #{date} #{time}: #{reason}")
        ~N[1970-01-01 00:00:00]
    end
  end

  # Private Functions

  @spec parse_system_message(String.t()) :: {:ok, message()} | :error
  defp parse_system_message(line) do
    if String.contains?(line, "[") && String.contains?(line, "]") do
      case Regex.run(@system_pattern, line) do
        [_, date, time, system_message] ->
          {:ok,
           %{
             datetime: parse_datetime(date, time),
             sender: "SYSTEM",
             message: String.trim(system_message)
           }}

        _ ->
          :error
      end
    else
      :error
    end
  end

  @spec build_message(String.t(), String.t(), String.t(), String.t()) :: message()
  defp build_message(date, time, sender, message) do
    %{
      datetime: parse_datetime(date, time),
      sender: String.trim(sender),
      message: String.trim(message)
    }
  end

  @spec do_parse_datetime(String.t(), String.t()) ::
          {:ok, NaiveDateTime.t()} | {:error, String.t()}
  defp do_parse_datetime(date, time) do
    try do
      with {:ok, year, month, day} <- parse_date_parts(date),
           {:ok, hour, minute, second} <- parse_time_parts(time),
           {:ok, datetime} <- NaiveDateTime.new(year, month, day, hour, minute, second) do
        {:ok, datetime}
      else
        {:error, reason} -> {:error, inspect(reason)}
      end
    rescue
      e in [ArgumentError, MatchError] ->
        {:error, Exception.message(e)}
    end
  end

  @spec parse_date_parts(String.t()) :: {:ok, integer(), integer(), integer()} | {:error, term()}
  defp parse_date_parts(date) do
    [day, month, year_str] = String.split(date, "/")

    day = String.to_integer(day)
    month = String.to_integer(month)

    year =
      case String.length(year_str) do
        2 -> 2000 + String.to_integer(year_str)
        4 -> String.to_integer(year_str)
        _ -> 2000 + String.to_integer(year_str)
      end

    {:ok, year, month, day}
  rescue
    e -> {:error, e}
  end

  @spec parse_time_parts(String.t()) :: {:ok, integer(), integer(), integer()} | {:error, term()}
  defp parse_time_parts(time) do
    {time_str, am_pm} = extract_period(time)
    {hour, minute, second} = extract_time_components(time_str)
    hour = convert_to_24h(hour, am_pm)

    {:ok, hour, minute, second}
  rescue
    e -> {:error, e}
  end

  @spec extract_period(String.t()) :: {String.t(), String.t() | nil}
  defp extract_period(time) do
    if String.ends_with?(time, " AM") or String.ends_with?(time, " PM") do
      [t, period] = String.split(time, " ")
      {t, period}
    else
      {time, nil}
    end
  end

  @spec extract_time_components(String.t()) :: {integer(), integer(), integer()}
  defp extract_time_components(time_str) do
    time_parts = String.split(time_str, ":")

    case length(time_parts) do
      2 ->
        [h, m] = Enum.map(time_parts, &String.to_integer/1)
        {h, m, 0}

      3 ->
        [h, m, s] = Enum.map(time_parts, &String.to_integer/1)
        {h, m, s}
    end
  end

  @spec convert_to_24h(integer(), String.t() | nil) :: integer()
  defp convert_to_24h(hour, "AM") when hour == 12, do: 0
  defp convert_to_24h(hour, "AM"), do: hour
  defp convert_to_24h(hour, "PM") when hour == 12, do: 12
  defp convert_to_24h(hour, "PM"), do: hour + 12
  defp convert_to_24h(hour, nil), do: hour
end
