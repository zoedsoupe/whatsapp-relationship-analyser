defmodule WhatsAppAnalyzer.AppConfig do
  @moduledoc """
  Acesso centralizado à configuração da aplicação.
  Elimina magic numbers no código.
  """

  # ML Models
  def sentiment_model, do: get(:sentiment_model)
  def summarization_model, do: get(:summarization_model)

  # ML Serving
  def summary_max_tokens, do: ml_config().summary_max_tokens
  def summary_min_tokens, do: ml_config().summary_min_tokens
  def batch_size, do: ml_config().batch_size
  def batch_timeout_ms, do: ml_config().batch_timeout_ms
  def summarizer_max_length, do: ml_config().summarizer_max_length
  def sentiment_max_length, do: ml_config().sentiment_max_length
  def model_load_timeout_ms, do: ml_config().model_load_timeout_ms

  # Analysis thresholds
  def romantic_threshold, do: analysis_config().romantic_threshold
  def close_friend_threshold, do: analysis_config().close_friend_threshold
  def friend_threshold, do: analysis_config().friend_threshold

  # Weights
  def classification_weights do
    cfg = analysis_config()

    %{
      romantic: cfg.romantic_weight,
      intimacy: cfg.intimacy_weight,
      future_planning: cfg.future_planning_weight,
      frequency: cfg.frequency_weight,
      response_time: cfg.response_time_weight
    }
  end

  # Multipliers
  def romantic_multiplier, do: analysis_config().romantic_multiplier
  def intimacy_multiplier, do: analysis_config().intimacy_multiplier
  def future_multiplier, do: analysis_config().future_multiplier

  # ML score conversion
  def ml_romantic_factor, do: analysis_config().ml_romantic_factor
  def ml_intimacy_factor, do: analysis_config().ml_intimacy_factor

  # File processing
  def large_file_threshold, do: analysis_config().large_file_threshold_bytes

  # Private helpers
  defp get(key), do: Application.get_env(:whatsapp_analyzer, key)
  defp ml_config, do: get(:ml_config)
  defp analysis_config, do: get(:analysis_config)
end
