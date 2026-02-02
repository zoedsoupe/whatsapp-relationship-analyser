defmodule WhatsAppAnalyzer.AnalysisCache do
  @moduledoc """
  GenServer para gerenciar cache de análises com TTL.
  Usa ETS para armazenamento persistente com limpeza automática.
  """

  use GenServer
  require Logger

  @table_name :analysis_results
  @ttl :timer.hours(24)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec put(String.t(), map()) :: :ok
  def put(id, data) do
    GenServer.call(__MODULE__, {:put, id, data})
  end

  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, data, _ts}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def init(_opts) do
    _ = :ets.new(@table_name, [:set, :public, :named_table])
    schedule_cleanup()
    Logger.info("AnalysisCache started with #{@ttl}ms TTL")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, id, data}, _from, state) do
    timestamp = System.monotonic_time(:second)
    :ets.insert(@table_name, {id, data, timestamp})
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:second)
    ttl_sec = div(@ttl, 1000)

    expired =
      :ets.select(@table_name, [{{:"$1", :_, :"$2"}, [{:<, :"$2", {:-, now, ttl_sec}}], [:"$1"]}])

    count = length(expired)

    if count > 0 do
      Enum.each(expired, &:ets.delete(@table_name, &1))
      Logger.info("Cleaned up #{count} expired cache entries")
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.hours(1))
  end
end
