defmodule WhatsAppAnalyzer.StreamingParser do
  @moduledoc """
  True streaming parser for large WhatsApp chat files.

  Processes files line-by-line using File.stream!/1 and processes
  messages in chunks to handle memory constraints efficiently.
  """

  require Explorer.DataFrame, as: DF

  alias WhatsAppAnalyzer.{DataProcessor, DateTimeParser}

  @type message :: DateTimeParser.message()

  @doc """
  Parses a file using streaming for memory efficiency.

  Processes the file in chunks of 1000 messages, enhancing each chunk
  and combining at the end.
  """
  @spec parse_file_stream(Path.t(), pos_integer()) :: DF.t()
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
  @spec parse_with_continuations(Enumerable.t()) :: Enumerable.t()
  def parse_with_continuations(lines) do
    Stream.transform(lines, nil, fn line, acc ->
      case DateTimeParser.parse_line(line) do
        {:ok, message} ->
          if acc do
            {[acc], message}
          else
            {[], message}
          end

        :error ->
          if acc do
            updated = %{acc | message: acc.message <> "\n" <> line}
            {[], updated}
          else
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

  @spec messages_to_dataframe([message()]) :: DF.t()
  defp messages_to_dataframe(messages) do
    # Reject SYSTEM messages
    messages = Enum.reject(messages, &(&1.sender == "SYSTEM"))

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

  @spec combine_dataframes([DF.t()]) :: DF.t()
  defp combine_dataframes([]), do: DF.new(datetime: [], sender: [], message: [])
  defp combine_dataframes([single]), do: single

  defp combine_dataframes(dfs) do
    Enum.reduce(dfs, fn df, acc ->
      DF.concat_rows(acc, df)
    end)
  end
end
