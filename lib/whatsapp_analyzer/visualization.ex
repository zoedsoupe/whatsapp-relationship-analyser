defmodule WhatsAppAnalyzer.Visualization do
  @moduledoc """
  Cria visualizações dos dados de conversação do WhatsApp usando VegaLite.
  """

  alias Explorer.DataFrame
  alias VegaLite, as: Vl
  alias WhatsAppAnalyzer.AnalysisHelpers

  require Explorer.DataFrame

  @doc """
  Cria visualização de frequência de mensagens ao longo do tempo.
  """
  @spec message_frequency_chart(Explorer.DataFrame.t()) :: VegaLite.t()
  def message_frequency_chart(df) do
    daily_counts =
      df
      |> DataFrame.group_by("date")
      |> DataFrame.summarise(count: count(message))
      |> DataFrame.to_rows()

    Vl.new(title: "Frequência de Mensagens", width: "container", height: 300)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(daily_counts)
    |> Vl.mark(:line, point: true)
    |> Vl.encode_field(:x, "date",
      type: :temporal,
      title: "Data",
      axis: [format: "%b %Y", labelAngle: -45]
    )
    |> Vl.encode_field(:y, "count",
      type: :quantitative,
      title: "Número de Mensagens"
    )
  end

  @doc """
  Cria visualização de distribuição de mensagens por remetente.
  """
  @spec sender_distribution_chart(Explorer.DataFrame.t()) :: VegaLite.t()
  def sender_distribution_chart(df) do
    sender_counts =
      df
      |> DataFrame.group_by("sender")
      |> DataFrame.summarise(count: count(message))
      |> DataFrame.to_rows()

    Vl.new(title: "Mensagens por Remetente", width: "container", height: 250)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(sender_counts)
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "sender", type: :nominal, title: "Remetente")
    |> Vl.encode_field(:y, "count", type: :quantitative, title: "Número de Mensagens")
    |> Vl.encode(:color, field: "sender", type: :nominal)
  end

  @doc """
  Cria mapa de calor de atividade por horário do dia.
  """
  @spec time_of_day_heatmap(Explorer.DataFrame.t()) :: VegaLite.t()
  def time_of_day_heatmap(df) do
    messages_by_time =
      df
      |> DataFrame.select(["hour", "day_of_week"])
      |> DataFrame.group_by(["day_of_week", "hour"])
      |> DataFrame.summarise(count: count(hour))
      |> AnalysisHelpers.add_day_names()
      |> DataFrame.to_rows()

    Vl.new(title: "Atividade de Mensagens por Horário", width: "container", height: 400)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(messages_by_time)
    |> Vl.mark(:rect)
    |> Vl.encode_field(:x, "hour",
      type: :ordinal,
      title: "Hora do Dia",
      sort: :ascending
    )
    |> Vl.encode_field(:y, "day_name",
      type: :ordinal,
      title: "Dia da Semana",
      sort: [
        "Segunda-feira",
        "Terça-feira",
        "Quarta-feira",
        "Quinta-feira",
        "Sexta-feira",
        "Sábado",
        "Domingo"
      ]
    )
    |> Vl.encode_field(:color, "count",
      type: :quantitative,
      title: "Contagem de Mensagens",
      scale: [scheme: "blues"]
    )
  end

  @doc """
  Cria gráfico radar para indicadores de relacionamento.
  """
  @spec relationship_radar_chart(map()) :: VegaLite.t()
  def relationship_radar_chart(relationship_analysis) do
    scores = relationship_analysis.relationship_classification.component_scores

    radar_data = [
      %{category: "Linguagem Romântica", value: scores.romantic_indicators},
      %{category: "Intimidade", value: scores.intimacy},
      %{category: "Planejamento Futuro", value: scores.future_planning},
      %{category: "Frequência de Mensagens", value: scores.messaging_frequency},
      %{category: "Tempo de Resposta", value: scores.response_time}
    ]

    Vl.new(title: "Indicadores de Relacionamento", width: "container", height: 300)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(radar_data)
    |> Vl.transform(
      calculate: "0",
      as: "baseline"
    )
    |> Vl.layers([
      Vl.new()
      |> Vl.mark(:line, opacity: 0.2, color: "#000000")
      |> Vl.encode_field(:x, "category", type: :nominal)
      |> Vl.encode(:y, value: 0),
      Vl.new()
      |> Vl.mark(:line, color: "#3366CC", point: true)
      |> Vl.encode_field(:x, "category", type: :nominal)
      |> Vl.encode_field(:y, "value", type: :quantitative)
      |> Vl.encode_field(:order, "category", type: :nominal)
    ])
    |> Vl.resolve(:scale, y: :shared)
  end

  @doc """
  Cria visualização de classificação de relacionamento com pontuação.
  """
  @spec relationship_classification_chart(map()) :: VegaLite.t()
  def relationship_classification_chart(relationship_analysis) do
    classification = relationship_analysis.relationship_classification.classification
    score = relationship_analysis.relationship_classification.score

    class_data = [
      %{
        classification: classification,
        score: score
      }
    ]

    Vl.new(title: "Classificação do Relacionamento", width: "container", height: 200)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(class_data)
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "score",
      type: :quantitative,
      title: "Pontuação",
      scale: [domain: [0, 100]]
    )
    |> Vl.encode_field(:y, "classification", type: :nominal)
    |> Vl.encode_field(:color, "classification",
      type: :nominal,
      scale: [
        domain: ["Conhecido", "Amigo", "Amigo Próximo", "Romântico"],
        range: ["#91bfdb", "#ffffbf", "#fc8d59", "#d73027"]
      ]
    )
  end

  @doc """
  Cria linha do tempo de sentimento mostrando evolução dos indicadores.
  """
  @spec sentiment_timeline_chart(Explorer.DataFrame.t()) :: VegaLite.t()
  def sentiment_timeline_chart(df) do
    # Agrupa por data e agrega scores de sentimento
    sentiment_by_date =
      df
      |> DataFrame.group_by("date")
      |> DataFrame.summarise(
        romantic: sum(romantic_score),
        intimacy: sum(intimacy_score),
        future_planning: sum(future_planning_score)
      )
      |> DataFrame.to_rows()
      |> Enum.flat_map(fn row ->
        [
          %{date: row["date"], category: "Romântico", score: row["romantic"]},
          %{date: row["date"], category: "Intimidade", score: row["intimacy"]},
          %{date: row["date"], category: "Planejamento Futuro", score: row["future_planning"]}
        ]
      end)

    Vl.new(title: "Evolução de Sentimento", width: "container", height: 300)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(sentiment_by_date)
    |> Vl.mark(:line, point: true)
    |> Vl.encode_field(:x, "date",
      type: :temporal,
      title: "Data",
      axis: [format: "%b %Y", labelAngle: -45]
    )
    |> Vl.encode_field(:y, "score",
      type: :quantitative,
      title: "Pontuação de Sentimento"
    )
    |> Vl.encode_field(:color, "category",
      type: :nominal,
      title: "Categoria",
      scale: [
        domain: ["Romântico", "Intimidade", "Planejamento Futuro"],
        range: ["#ff6b9d", "#9b59b6", "#3498db"]
      ]
    )
  end

  @doc """
  Cria gráfico de frequência de palavras mais comuns.
  """
  @spec word_frequency_chart(Explorer.DataFrame.t()) :: VegaLite.t()
  def word_frequency_chart(df) do
    # Stopwords em português
    stopwords = pt_stopwords()

    # Extrai e conta palavras (somente mensagens de texto)
    text_df = DataFrame.filter_with(df, &Explorer.Series.equal(&1["message_type"], "text"))

    messages =
      text_df["message"]
      |> Explorer.Series.to_list()

    word_counts =
      messages
      |> Enum.join(" ")
      |> String.downcase()
      |> String.split(~r/\W+/, trim: true)
      |> Enum.filter(&(String.length(&1) > 3))
      |> Enum.reject(&is_stopword?(&1, stopwords))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_word, count} -> -count end)
      |> Enum.take(20)
      |> Enum.map(fn {word, count} -> %{word: word, frequency: count} end)

    Vl.new(title: "Top 20 Palavras Mais Frequentes", width: "container", height: 400)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(word_counts)
    |> Vl.mark(:bar)
    |> Vl.encode_field(:y, "word",
      type: :nominal,
      title: "Palavra",
      sort: "-x"
    )
    |> Vl.encode_field(:x, "frequency",
      type: :quantitative,
      title: "Frequência"
    )
    |> Vl.encode(:color,
      field: "frequency",
      type: :quantitative,
      scale: [scheme: "viridis"]
    )
  end

  @doc """
  Cria visualização de fluxo de conversa mostrando intensidade por remetente.
  """
  @spec conversation_flow_chart(Explorer.DataFrame.t()) :: VegaLite.t()
  def conversation_flow_chart(df) do
    # Agrupa por data e remetente
    flow_data =
      df
      |> DataFrame.group_by(["date", "sender"])
      |> DataFrame.summarise(count: count(message))
      |> DataFrame.to_rows()

    Vl.new(title: "Fluxo da Conversa", width: "container", height: 300)
    |> Vl.config(autosize: %{type: "fit", contains: "padding"})
    |> Vl.config(view: [stroke: nil])
    |> Vl.data_from_values(flow_data)
    |> Vl.mark(:area)
    |> Vl.encode_field(:x, "date",
      type: :temporal,
      title: "Data",
      axis: [format: "%b %Y", labelAngle: -45]
    )
    |> Vl.encode_field(:y, "count",
      type: :quantitative,
      title: "Contagem de Mensagens",
      stack: true
    )
    |> Vl.encode_field(:color, "sender",
      type: :nominal,
      title: "Remetente"
    )
  end

  defp pt_stopwords do
    MapSet.new([
      "que",
      "para",
      "com",
      "uma",
      "você",
      "voce",
      "vc",
      "ele",
      "ela",
      "por",
      "como",
      "mas",
      "seu",
      "sua",
      "esse",
      "essa",
      "esta",
      "este",
      "isso",
      "aqui",
      "ali",
      "muito",
      "mais",
      "quando",
      "onde",
      "porque",
      "pq",
      "qual",
      "quem",
      "depois",
      "antes",
      "sobre",
      "foi",
      "ser",
      "ter",
      "fazer",
      "não",
      "nao",
      "sim",
      "vai",
      "pode",
      "bem",
      "todo",
      "toda",
      "até",
      "ate",
      "agora"
    ])
  end

  defp is_stopword?(word, stopwords), do: MapSet.member?(stopwords, word)
end
