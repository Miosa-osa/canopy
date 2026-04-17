%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "config/"],
        excluded: ["priv/"]
      },
      strict: true,
      color: true,
      checks: %{
        enabled: [
          # Design
          {Credo.Check.Design.AliasUsage, priority: :low, if_nested_deeper_than: 2},
          {Credo.Check.Design.TagTODO, exit_status: 0},
          {Credo.Check.Design.TagFIXME, exit_status: 0},

          # Consistency
          {Credo.Check.Consistency.ExceptionNames},
          {Credo.Check.Consistency.LineEndings},
          {Credo.Check.Consistency.ParameterPatternMatching},
          {Credo.Check.Consistency.SpaceAroundOperators},
          {Credo.Check.Consistency.SpaceInParentheses},
          {Credo.Check.Consistency.TabsOrSpaces},
          {Credo.Check.Consistency.UnusedVariableNames},

          # Readability
          {Credo.Check.Readability.AliasOrder},
          {Credo.Check.Readability.FunctionNames},
          {Credo.Check.Readability.LargeNumbers},
          {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 120},
          {Credo.Check.Readability.ModuleAttributeNames},
          {Credo.Check.Readability.ModuleDoc},
          {Credo.Check.Readability.ModuleNames},
          {Credo.Check.Readability.ParenthesesInCondition},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs},
          {Credo.Check.Readability.PreferImplicitTry},
          {Credo.Check.Readability.PredicateFunctionNames},
          {Credo.Check.Readability.StrictModuleLayout},
          {Credo.Check.Readability.StringSigils},
          {Credo.Check.Readability.UnnecessaryAliasExpansion},
          {Credo.Check.Readability.VariableNames},

          # Refactoring
          {Credo.Check.Refactor.Apply},
          {Credo.Check.Refactor.CondStatements},
          {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 9},
          {Credo.Check.Refactor.FunctionArity, max_arity: 6},
          {Credo.Check.Refactor.LongQuoteBlocks},
          {Credo.Check.Refactor.MapInto},
          {Credo.Check.Refactor.MatchInCondition},
          {Credo.Check.Refactor.NegatedConditionsInUnless},
          {Credo.Check.Refactor.NegatedConditionsWithElse},
          {Credo.Check.Refactor.Nesting, max_nesting: 3},
          {Credo.Check.Refactor.UnlessWithElse},

          # Warnings
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute},
          {Credo.Check.Warning.BoolOperationOnSameValues},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck},
          {Credo.Check.Warning.IExPry},
          {Credo.Check.Warning.IoInspect},
          {Credo.Check.Warning.LazyLogging},
          {Credo.Check.Warning.MixEnv},
          {Credo.Check.Warning.OperationOnSameValues},
          {Credo.Check.Warning.OperationWithConstantResult},
          {Credo.Check.Warning.RaiseInsideRescue},
          {Credo.Check.Warning.SpecWithStruct},
          {Credo.Check.Warning.UnsafeExec},
          {Credo.Check.Warning.UnsafeToAtom},
          {Credo.Check.Warning.UnusedEnumOperation},
          {Credo.Check.Warning.UnusedFileOperation},
          {Credo.Check.Warning.UnusedKeywordOperation},
          {Credo.Check.Warning.UnusedListOperation},
          {Credo.Check.Warning.UnusedPathOperation},
          {Credo.Check.Warning.UnusedRegexOperation},
          {Credo.Check.Warning.UnusedStringOperation},
          {Credo.Check.Warning.UnusedTupleOperation},
          {Credo.Check.Warning.WrongTestFileExtension}
        ]
      }
    }
  ]
}
