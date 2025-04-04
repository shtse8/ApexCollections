# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~19:30 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Refactoring & Debugging IN PROGRESS.**
    -   **Refactoring:**
        -   Extracted RRB-Tree utility functions from `ApexListImpl` into `rrb_tree_utils.dart`.
        -   Refactored `ChampInternalNode` in `champ_node.dart` to separate transient/immutable logic paths.
        -   Extracted `ChampTrieIterator` from `ApexMapImpl` into `champ_iterator.dart`.
        -   Optimized `ApexMapImpl.containsKey` by adding dedicated `ChampNode.containsKey` method.
        -   Optimized `bitCount` helper function in `champ_node.dart` using SWAR algorithm.
        -   Refactored `ApexMap._buildNode` (Attempted single-pass strategy, improved `fromMap` but regressed other ops, reverted).
        -   Fixed `ApexList.toList` performance regression by reverting to recursive helper.
        -   Attempted optimization of `RrbInternalNode.fromRange` (Reverted - worsened performance).
        -   Attempted optimization of `ChampInternalNode` immutable helpers using list spreads (Reverted - worsened single-element performance).
        -   **Fixed `champ_node.dart` structural errors (missing `ChampArrayNode` definition, misplaced methods).**
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All `apex_map_test.dart` tests pass.
        -   **(Resolved)** List Test Runtime Error: The `StateError: Cannot rebalance incompatible nodes...` in `RrbInternalNode._rebalanceOrMerge` has been addressed by implementing a plan-based rebalancing strategy (`_createRebalancePlan`, `_executeRebalancePlan`) for the immutable path. All `apex_list_test.dart` tests now pass.
        -   **(Resolved)** The transient path for `_rebalanceOrMerge` (plan-based case) now uses `_executeTransientRebalancePlan` to mutate nodes in place.
        -   **(Resolved)** Persistent Dart Analyzer errors related to `ChampArrayNode` resolved by fixing `champ_node.dart` structure, clearing `.dart_tool`, and using `git stash pop`.
    -   **Performance Status (Updated 2025-04-04 ~19:30 UTC+1 - After fixing `champ_node.dart`):**
        -   **ApexMap (Size: 10k):**
            -   `add`: ~4.08 us (Improved, but slower than Native/FIC)
            -   `addAll`: ~31.70 us (Excellent - Much faster than Native/FIC)
            -   `lookup[]`: ~0.24 us (Stable, slower than Native/FIC)
            -   `remove`: ~3.73 us (Stable, much faster than FIC)
            -   `update`: ~8.47 us (Slightly improved, faster than FIC)
            -   `iterateEntries`: **~24.87 us** (**Massive Improvement!** Faster than Native/FIC)
            -   `toMap`: **~51.84 us** (**Massive Improvement!** Faster than Native/FIC)
            -   `fromMap`: ~8333.64 us (Slightly slower, slower than FIC)
            -   *Conclusion:* Fixing `champ_node.dart` structure dramatically improved iteration and `toMap` performance, likely due to correct iterator/node interaction. `add` also improved. `addAll` remains excellent. Single-element lookups/removals stable. `fromMap` slightly regressed. Further optimization deferred.
        -   **ApexList (Size: 10k):** (Post `champ_node.dart` fix)
            -   `add`: ~24.12 us (Slightly improved, much faster than FIC)
            -   `addAll`: ~29.38 us (Slightly improved, Excellent)
            -   `lookup[]`: ~0.15 us (Stable, Excellent)
            -   `removeAt`: ~18.86 us (Stable, Excellent)
            -   `removeWhere`: ~2753.31 us (Stable, Competitive)
            -   `iterateSum`: ~261.48 us (Stable, Competitive)
            -   `sublist`: ~5.65 us (Slightly improved, Excellent)
            -   `concat(+)`: ~7.04 us (Slightly improved, Very good)
            -   `toList`: ~716.06 us (Slightly improved, Competitive)
            -   `fromIterable`: ~2858.17 us (Slightly improved, slower than FIC but accepted trade-off)
            -   *Conclusion:* Performance remains stable and excellent for key operations after fixing unrelated map node issues. Minor improvements observed across several operations. Recursive concatenation strategy for `fromIterable` continues to provide good lookup/sublist performance.

## Current Focus

-   **ApexList:** Core logic stable.
-   **ApexMap:** Fixed structural errors in `champ_node.dart`. Updated Dartdocs.
-   **Testing:** All tests pass.
-   **Benchmarking:** Re-ran benchmarks after fixing `champ_node.dart`. Confirmed `ApexList` stability and observed significant improvements in `ApexMap` iteration/`toMap`.
-   **Documentation:** Updated Dartdocs for `ApexList` and `ApexMap` based on latest changes and benchmarks.

## Next Immediate Steps

1.  **(DONE)** Fix `champ_node.dart` structural errors (missing `ChampArrayNode`, misplaced methods).
2.  **(DONE)** Resolve persistent Dart Analyzer errors via cache clearing and `git stash`.
3.  **(DONE)** Update `ApexList` Dartdocs.
4.  **(DONE)** Update `ApexMap` Dartdocs.
5.  **(DONE)** Re-run benchmarks for `ApexMap` and `ApexList`.
6.  **Update Memory Bank:** Reflect latest fixes, benchmark results, and documentation updates. (Current Step)
7.  **Phase 5:** Begin detailed documentation (README updates, examples, potentially GitHub Pages setup).

## Open Questions / Decisions

-   Need for transient/mutable builders? (Decision remains: Low priority for Map, explore for List later)
-   Further `ApexMap` single-op/`fromMap` optimization? (Decision remains: Deferred)