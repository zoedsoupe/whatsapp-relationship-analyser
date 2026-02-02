defmodule WhatsAppAnalyzerWeb.Router do
  use WhatsAppAnalyzerWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", WhatsAppAnalyzerWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
    post("/analyze", AnalysisController, :create)
    get("/results/:id", AnalysisController, :show)
    get("/results/:id/download", AnalysisController, :download_summary)
  end
end
