defmodule WhatsAppAnalyzer.TimeHelpers do
  @moduledoc """
  Funções auxiliares para mapeamento temporal em português.
  """

  @day_names %{
    1 => "Segunda-feira",
    2 => "Terça-feira",
    3 => "Quarta-feira",
    4 => "Quinta-feira",
    5 => "Sexta-feira",
    6 => "Sábado",
    7 => "Domingo"
  }

  @doc """
  Retorna o nome do dia em português dado seu número (1-7).
  """
  @spec day_name(integer()) :: String.t()
  def day_name(day_number) when day_number in 1..7 do
    Map.get(@day_names, day_number)
  end

  def day_name(_), do: "Desconhecido"

  @doc """
  Retorna o período do dia para uma hora (0-23).
  """
  @spec time_period(integer()) :: String.t()
  def time_period(hour) when hour in 6..11, do: "manhã"
  def time_period(hour) when hour in 12..17, do: "tarde"
  def time_period(hour) when hour in 18..22, do: "noite"
  def time_period(_hour), do: "madrugada"
end
