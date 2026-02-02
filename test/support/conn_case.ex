defmodule WhatsAppAnalyzerWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import WhatsAppAnalyzerWeb.ConnCase

      alias WhatsAppAnalyzerWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint WhatsAppAnalyzerWeb.Endpoint
    end
  end

  setup _tags do
    conn = Phoenix.ConnTest.build_conn()

    conn = %{
      conn
      | secret_key_base:
          Application.get_env(:whatsapp_analyser, WhatsAppAnalyzerWeb.Endpoint)[:secret_key_base]
    }

    {:ok, conn: conn}
  end
end
