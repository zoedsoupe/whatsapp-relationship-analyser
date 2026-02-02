defmodule WhatsAppAnalyzerWeb.VegaLiteHelper do
  @moduledoc """
  Helper module to convert VegaLite charts to embeddable JSON for web display.
  """

  import Phoenix.HTML
  require Logger

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

    # Log for debugging (first 100 chars of spec)
    Logger.debug("Embedding chart #{dom_id}: #{String.slice(spec, 0, 100)}...")

    """
    <div id="#{dom_id}" style="width: 100%; min-height: 300px;"></div>
    <script>
      vegaEmbed('##{dom_id}', #{spec}, {actions: false})
        .then(result => console.log('Chart #{dom_id} embedded successfully'))
        .catch(error => {
          console.error('Error embedding chart #{dom_id}:', error);
          document.getElementById('#{dom_id}').innerHTML =
            '<div style="padding: 20px; color: red; border: 1px solid red;">Error loading chart: ' + error.message + '</div>';
        });
    </script>
    """
    |> raw()
  end
end
