defmodule WhatsAppAnalyzer.Visualization do
  @moduledoc """
  Creates visualizations from WhatsApp conversation data using VegaLite.
  """
  
  alias VegaLite, as: Vl
  alias Explorer.DataFrame

  require Explorer.DataFrame

  @doc """
  Creates a message frequency over time visualization.
  """
  def message_frequency_chart(df) do
    daily_counts = df
      |> DataFrame.group_by("date")
      |> DataFrame.summarise(count: count(message))
      |> DataFrame.to_rows()
    
    Vl.new(title: "Message Frequency Over Time")
    |> Vl.data_from_values(daily_counts)
    |> Vl.mark(:line, point: true)
    |> Vl.encode_field(:x, "date", 
        type: :temporal, 
        title: "Date",
        axis: [format: "%b %Y", labelAngle: -45]
      )
    |> Vl.encode_field(:y, "count", 
        type: :quantitative, 
        title: "Number of Messages"
      )
  end

  @doc """
  Creates a visualization of message count by sender.
  """
  def sender_distribution_chart(df) do
    sender_counts = df
      |> DataFrame.group_by("sender")
      |> DataFrame.summarise(count: count(message))
      |> DataFrame.to_rows()
    
    Vl.new(title: "Messages by Sender")
    |> Vl.data_from_values(sender_counts)
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "sender", type: :nominal, title: "Sender")
    |> Vl.encode_field(:y, "count", type: :quantitative, title: "Number of Messages")
    |> Vl.encode(:color, field: "sender", type: :nominal)
  end

  @doc """
  Creates a time of day activity heatmap.
  """
  def time_of_day_heatmap(df) do
    messages_by_time = df
      |> DataFrame.select(["hour", "day_of_week"])
      |> DataFrame.group_by(["day_of_week", "hour"])
      |> DataFrame.summarise(count: count(hour))
      |> DataFrame.to_rows()
    
    messages_by_time = Enum.map(messages_by_time, fn row ->
      day_name = case row["day_of_week"] do
        1 -> "Monday"
        2 -> "Tuesday"
        3 -> "Wednesday"
        4 -> "Thursday"
        5 -> "Friday"
        6 -> "Saturday"
        7 -> "Sunday"
      end
      
      Map.put(row, "day_name", day_name)
    end)
    
    Vl.new(title: "Message Activity by Time of Day")
    |> Vl.data_from_values(messages_by_time)
    |> Vl.mark(:rect)
    |> Vl.encode_field(:x, "hour", 
        type: :ordinal, 
        title: "Hour of Day",
        sort: :ascending
      )
    |> Vl.encode_field(:y, "day_name", 
        type: :ordinal, 
        title: "Day of Week",
        sort: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
      )
    |> Vl.encode_field(:color, "count", 
        type: :quantitative,
        title: "Message Count",
        scale: [scheme: "blues"]
      )
  end

  @doc """
  Creates a radar chart for relationship indicators.
  """
  def relationship_radar_chart(relationship_analysis) do
    scores = relationship_analysis.relationship_classification.component_scores
    
    radar_data = [
      %{category: "Romantic Language", value: scores.romantic_indicators},
      %{category: "Intimacy", value: scores.intimacy},
      %{category: "Future Planning", value: scores.future_planning},
      %{category: "Message Frequency", value: scores.messaging_frequency},
      %{category: "Response Time", value: scores.response_time}
    ]
    
    Vl.new(title: "Relationship Indicators")
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
    |> Vl.config(view: [stroke: nil])
  end

  @doc """
  Creates a visualization of relationship classification with confidence score.
  """
  def relationship_classification_chart(relationship_analysis) do
    classification = relationship_analysis.relationship_classification.classification
    score = relationship_analysis.relationship_classification.score
    
    class_data = [%{
      classification: classification,
      score: score
    }]
    
    Vl.new(title: "Relationship Classification")
    |> Vl.data_from_values(class_data)
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "score", 
        type: :quantitative, 
        title: "Confidence Score",
        scale: [domain: [0, 100]]
      )
    |> Vl.encode_field(:y, "classification", type: :nominal)
    |> Vl.encode_field(:color, "classification", 
        type: :nominal,
        scale: [
          domain: ["Acquaintance", "Friend", "Close Friend", "Romantic"],
          range: ["#91bfdb", "#ffffbf", "#fc8d59", "#d73027"]
        ]
      )
  end
end
