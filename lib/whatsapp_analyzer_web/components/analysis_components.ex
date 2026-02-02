defmodule WhatsAppAnalyzerWeb.AnalysisComponents do
  @moduledoc """
  Reusable components for analysis results display.
  """
  use Phoenix.Component

  @doc """
  Renders a metric card.
  """
  attr(:title, :string, required: true)
  attr(:value, :any, required: true)

  def metric_card(assigns) do
    ~H"""
    <div class="metric-card">
      <h4><%= @title %></h4>
      <p class="metric-value"><%= @value %></p>
    </div>
    """
  end

  @doc """
  Renders a sentiment card with click interaction.
  """
  attr(:category, :atom, required: true)
  attr(:label, :string, required: true)
  attr(:count, :integer, required: true)

  def sentiment_card(assigns) do
    category_str = to_string(assigns.category)

    assigns = assign(assigns, :category_str, category_str)

    ~H"""
    <div class={"sentiment-card #{@category_str}"} onclick={"toggleExcerpts('#{@category_str}')"}>
      <h4><%= @label %></h4>
      <div class="value"><%= @count %></div>
      <div class="action">Click to view excerpts ↓</div>
    </div>
    """
  end

  @doc """
  Renders a single excerpt item.
  """
  attr(:excerpt, :map, required: true)

  def excerpt_item(assigns) do
    ~H"""
    <div class="excerpt-item">
      <div class="excerpt-header">
        <span>
          <strong><%= @excerpt.sender %></strong>
          - <%= Calendar.strftime(@excerpt.datetime, "%Y-%m-%d %H:%M") %>
        </span>
        <span class="excerpt-score">Score: <%= @excerpt.score %></span>
      </div>
      <div class="excerpt-text"><%= @excerpt.message %></div>
    </div>
    """
  end
end
