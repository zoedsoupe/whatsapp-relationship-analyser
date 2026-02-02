defmodule WhatsAppAnalyzer.Servings do
  @moduledoc """
  Especificações de serving para modelos ML.
  Otimizado para Mac M1 (batch_size menor).
  """

  require Logger
  alias WhatsAppAnalyzer.AppConfig

  @doc """
  Serving para sumarização em português.
  Usa PTT5-base (modelo menor, eficiente para M1).
  """
  def summarizer_spec do
    model_id = AppConfig.summarization_model()
    Logger.info("Carregando modelo de sumarização: #{model_id}")

    serving = build_generation_serving(model_id, :summarization)

    Logger.info("Modelo de sumarização carregado")

    build_nx_serving(
      WhatsAppAnalyzer.Serving.Summarizer,
      serving,
      AppConfig.batch_size(),
      AppConfig.batch_timeout_ms()
    )
  end

  @doc """
  Serving para análise de sentimento em português.
  Usa BERTimbau (bert-base-portuguese-cased).
  """
  def sentiment_spec do
    model_id = AppConfig.sentiment_model()
    Logger.info("Carregando modelo de sentimento: #{model_id}")

    serving = build_classification_serving(model_id, :sentiment)

    Logger.info("Modelo de sentimento carregado")

    build_nx_serving(
      WhatsAppAnalyzer.Serving.Sentiment,
      serving,
      AppConfig.batch_size(),
      AppConfig.batch_timeout_ms()
    )
  end

  # Helpers privados (DRY)

  @spec build_generation_serving(String.t(), :summarization) :: Nx.Serving.t()
  defp build_generation_serving(model_id, :summarization) do
    rev = "e78923f1"
    {:ok, model} = Bumblebee.load_model({:hf, model_id, revision: rev})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_id, revision: rev})
    {:ok, gen_config} = Bumblebee.load_generation_config({:hf, model_id, revision: rev})

    gen_config =
      Bumblebee.configure(gen_config,
        max_new_tokens: AppConfig.summary_max_tokens()
      )

    Bumblebee.Text.generation(
      model,
      tokenizer,
      gen_config,
      compile: [
        batch_size: AppConfig.batch_size(),
        sequence_length: AppConfig.summarizer_max_length()
      ],
      defn_options: [compiler: EXLA]
    )
  end

  @spec build_classification_serving(String.t(), :sentiment) :: Nx.Serving.t()
  defp build_classification_serving(model_id, :sentiment) do
    rev = "b34b9e93"
    {:ok, model} = Bumblebee.load_model({:hf, model_id, revision: rev})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_id, revision: rev})

    Bumblebee.Text.text_classification(
      model,
      tokenizer,
      compile: [
        batch_size: AppConfig.batch_size(),
        sequence_length: AppConfig.sentiment_max_length()
      ],
      defn_options: [compiler: EXLA]
    )
  end

  @spec build_nx_serving(atom(), Nx.Serving.t(), pos_integer(), pos_integer()) ::
          {module(), keyword()}
  defp build_nx_serving(name, serving, batch_size, batch_timeout) do
    {Nx.Serving,
     [
       name: name,
       serving: serving,
       batch_size: batch_size,
       batch_timeout: batch_timeout
     ]}
  end
end
