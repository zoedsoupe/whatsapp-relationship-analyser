defmodule WhatsAppAnalyzer.Parser do
  @moduledoc """
  Parses WhatsApp chat export files into structured data.
  """

  alias WhatsAppAnalyzer.DateTimeParser

  @type message :: DateTimeParser.message()

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
  @spec parse_file(Path.t()) :: [message()]
  def parse_file(file_path) do
    File.read!(file_path)
    |> String.split("\n")
    |> Enum.filter(&(String.length(&1) > 0))
    |> parse_lines([])
  end

  @spec parse_lines([String.t()], [message()]) :: [message()]
  defp parse_lines([], acc), do: Enum.reverse(acc)

  defp parse_lines([line | rest], acc) do
    case DateTimeParser.parse_line(line) do
      {:ok, message} ->
        parse_lines(rest, [message | acc])

      :error ->
        handle_continuation(line, rest, acc)
    end
  end

  @spec handle_continuation(String.t(), [String.t()], [message()]) :: [message()]
  defp handle_continuation(line, rest, [prev | tail]) do
    updated = %{prev | message: prev.message <> "\n" <> line}
    parse_lines(rest, [updated | tail])
  end

  defp handle_continuation(_line, rest, []), do: parse_lines(rest, [])
end
