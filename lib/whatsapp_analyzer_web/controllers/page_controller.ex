defmodule WhatsAppAnalyzerWeb.PageController do
  use WhatsAppAnalyzerWeb, :controller

  def index(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8"/>
        <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>WhatsApp Relationship Analyzer</title>
        <link rel="stylesheet" href="/css/app.css"/>
      </head>
      <body>
        <header>
          <nav>
            <h1>WhatsApp Relationship Analyzer</h1>
          </nav>
        </header>

        <main>
          #{render_flash(conn)}

          <div class="container">
            <div class="upload-section">
              <h2>Upload WhatsApp Chat Export</h2>
              <p>Export your WhatsApp chat (without media) and upload the text file here for analysis.</p>

              <form action="#{Routes.analysis_path(conn, :create)}" method="post" enctype="multipart/form-data">
                <input type="hidden" name="_csrf_token" value="#{Plug.CSRFProtection.get_csrf_token()}">

                <div class="form-group">
                  <label for="upload">Select Chat Export File:</label>
                  <input type="file" name="upload" id="upload" required accept=".txt">
                </div>

                <div class="form-group">
                  <button type="submit" class="btn-primary">Analyze Chat</button>
                </div>
              </form>

              <div class="info-section">
                <h3>How to export your WhatsApp chat:</h3>
                <ol>
                  <li>Open WhatsApp and go to the chat you want to analyze</li>
                  <li>Tap the three dots menu (⋮) or contact name</li>
                  <li>Select "More" → "Export chat"</li>
                  <li>Choose "Without media"</li>
                  <li>Save the file and upload it here</li>
                </ol>

                <p class="note">
                  <strong>Note:</strong> Your chat data is processed locally and temporarily.
                  Results are not permanently stored.
                </p>
              </div>
            </div>
          </div>
        </main>

        <script src="/js/app.js"></script>
      </body>
    </html>
    """)
  end

  defp render_flash(conn) do
    info = Phoenix.Flash.get(conn.assigns[:flash] || %{}, :info)
    error = Phoenix.Flash.get(conn.assigns[:flash] || %{}, :error)

    cond do
      info ->
        ~s(<div class="alert alert-info">#{Phoenix.HTML.html_escape(info) |> Phoenix.HTML.safe_to_string()}</div>)

      error ->
        ~s(<div class="alert alert-error">#{Phoenix.HTML.html_escape(error) |> Phoenix.HTML.safe_to_string()}</div>)

      true ->
        ""
    end
  end
end
