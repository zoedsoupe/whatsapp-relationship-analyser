defmodule WhatsAppAnalyzerWeb.VegaLiteHelper do
  @moduledoc """
  Helper module to convert VegaLite charts to embeddable JSON for web display.
  """

  import Phoenix.HTML

  @doc """
  Embeds a VegaLite chart in the HTML page.

  ## Parameters
    - chart: A VegaLite chart struct
    - dom_id: The DOM element ID where the chart should be embedded

  ## Returns
    A safe HTML string with the chart container and embedding script
  """
  def embed_chart(chart, dom_id) do
    spec = chart |> VegaLite.to_spec() |> Jason.encode!()

    """
    <div id="#{dom_id}"></div>
    <script>vegaEmbed('##{dom_id}', #{spec});</script>
    """
    |> raw()
  end
end
