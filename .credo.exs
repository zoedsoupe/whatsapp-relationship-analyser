%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: %{
        enabled: [
          {Credo.Check.Readability.MaxLineLength, max_length: 120},
          {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 10},
          {Credo.Check.Refactor.Nesting, max_nesting: 2},
          {Credo.Check.Refactor.FunctionArity, max_arity: 5}
        ]
      }
    }
  ]
}
