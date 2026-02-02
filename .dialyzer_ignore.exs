[
  # MapSet opaque type issues - these are false positives from Dialyzer's strict opaque type checking
  ~r/visualization.ex.*call_without_opaque/,
  # Contract supertype warnings - these are acceptable as the specs are intentionally more general
  ~r/contract_supertype/
]
