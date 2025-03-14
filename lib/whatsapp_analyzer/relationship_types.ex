defmodule WhatsAppAnalyzer.RelationshipTypes do
  @doc """
  Relationship dimensions that avoid hierarchical assumptions
  """

  def dimensions do
    [
      :emotional_intimacy,
      :intellectual_connection,
      :physical_affinity,
      :resource_sharing,
      :communication_cadence,
      :mutual_investment
    ]
  end
end
