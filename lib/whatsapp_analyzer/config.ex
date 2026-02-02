defmodule WhatsAppAnalyzer.Config do
  @moduledoc """
  Configuration constants for relationship analysis indicators and temporal mappings.
  """

  @romantic_indicators [
    # Portuguese terms
    "amor",
    "amo",
    "amo você",
    "te amo",
    "amorzinho",
    "meu amor",
    "minha vida",
    "querido",
    "querida",
    "saudade",
    "sinto sua falta",
    "beijo",
    "beijinho",
    "gostoso",
    "gostosa",
    "lindo",
    "linda",
    "tesão",
    "sdds",
    "apaixonado",
    "apaixonada",
    "namorar",
    "namorado",
    "namorada",
    "carinho",
    # English terms
    "love",
    "miss you",
    "missing you",
    "darling",
    "babe",
    "baby",
    "honey",
    "sweetheart",
    "beautiful",
    "gorgeous",
    "handsome",
    "kiss",
    "kisses",
    "boyfriend",
    "girlfriend",
    "passion",
    "passionate",
    "romantic",
    "date"
  ]

  @future_planning [
    # Portuguese
    "planejar",
    "futuro",
    "morar",
    "juntos",
    "juntas",
    "casa",
    "viajar",
    "férias",
    "feriado",
    "fim de semana",
    "amanhã",
    "semana que vem",
    # English
    "plan",
    "future",
    "live together",
    "house",
    "travel",
    "vacation",
    "holiday",
    "weekend",
    "tomorrow",
    "next week"
  ]

  @intimacy_indicators [
    # Portuguese
    "sinto",
    "sentir",
    "sentimento",
    "emoção",
    "confiar",
    "confio",
    "segredo",
    "pessoal",
    "íntimo",
    "íntima",
    "vulnerável",
    "abrir",
    "coração",
    "alma",
    # English
    "feel",
    "feeling",
    "emotion",
    "trust",
    "secret",
    "personal",
    "intimate",
    "vulnerable",
    "open up",
    "heart",
    "soul"
  ]

  @day_names %{
    1 => "Monday",
    2 => "Tuesday",
    3 => "Wednesday",
    4 => "Thursday",
    5 => "Friday",
    6 => "Saturday",
    7 => "Sunday"
  }

  @time_periods %{
    "morning" => 6..11,
    "afternoon" => 12..17,
    "evening" => 18..22,
    "night" => [23, 0, 1, 2, 3, 4, 5]
  }

  @doc """
  Returns the list of romantic indicator keywords.
  """
  def romantic_indicators, do: @romantic_indicators

  @doc """
  Returns the list of future planning indicator keywords.
  """
  def future_planning, do: @future_planning

  @doc """
  Returns the list of intimacy indicator keywords.
  """
  def intimacy_indicators, do: @intimacy_indicators

  @doc """
  Returns the day names mapping (1-7 to weekday names).
  """
  def day_names, do: @day_names

  @doc """
  Returns the time period definitions.
  """
  def time_periods, do: @time_periods

  @doc """
  Returns the name of a day given its number (1-7).
  """
  def day_name(day_number) when day_number in 1..7 do
    Map.get(@day_names, day_number)
  end

  def day_name(_), do: "Unknown"

  @doc """
  Returns the time period for a given hour (0-23).
  """
  def time_period(hour) when hour in 6..11, do: "morning"
  def time_period(hour) when hour in 12..17, do: "afternoon"
  def time_period(hour) when hour in 18..22, do: "evening"
  def time_period(_hour), do: "night"
end
