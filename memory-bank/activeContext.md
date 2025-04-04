# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~21:50 UTC+1)

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
        -   **Refactored `ChampTrieIterator` logic to fix test failures.**
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All `apex_map_test.dart` tests pass.
        -   **(Resolved)** List Test Runtime Error: The `StateError: Cannot rebalance incompatible nodes...` in `RrbInternalNode._rebalanceOrMerge` has been addressed by implementing a plan-based rebalancing strategy (`_createRebalancePlan`, `_executeRebalancePlan`) for the immutable path. All `apex_list_test.dart` tests now pass.
        -   **(Resolved)** The transient path for `_rebalanceOrMerge` (plan-based case) now uses `_executeTransientRebalancePlan` to mutate nodes in place.
        -   **(Resolved)** Persistent Dart Analyzer errors related to `ChampArrayNode` resolved by fixing `champ_node.dart` structure, clearing `.dart_tool`, and using `git stash pop`.
        -   **(Resolved)** Multiple `ApexMap` test failures resolved by refactoring `ChampTrieIterator`. **All tests now pass.**
    -   **Performance Status (Updated 2025-04-04 ~21:50 UTC+1 - After fixing iterator & re-running benchmarks):**
        -   **ApexMap (Size: 10k):**
            -   `add`: ~4.16 us (Stable, slower than Native/FIC)
            -   `addAll`: ~30.89 us (Stable, Excellent)
            -   `lookup[]`: ~0.23 us (Stable, slower than Native/FIC)
            -   `remove`: ~3.80 us (Stable, much faster than FIC)
            -   `update`: ~8.55 us (Stable, faster than FIC)
            -   `iterateEntries`: ~2966.55 us (Slow - Previous fast result likely due to incorrect iteration logic before fix)
            -   `toMap`: ~8565.48 us (Slow - Previous fast result likely due to incorrect iteration logic before fix)
            -   `fromMap`: ~8453.27 us (Stable, slower than FIC)
            -   *Conclusion:* After fixing the iterator logic to ensure correctness (all tests pass), the iteration and `toMap` performance returned to slower levels, similar to before the `champ_node.dart` structural fixes. This confirms the previous "massive improvement" was an artifact of incorrect iteration. `addAll` remains excellent. Single-element operations are stable. Further optimization for iteration, `toMap`, and single-element ops remains deferred.
        -   **ApexList (Size: 10k):** (After iterator fix & re-run)
            -   `add`: ~26.74 us (Stable, much faster than FIC)
            -   `addAll`: ~32.34 us (Stable, Excellent)
            -   `lookup[]`: ~0.15 us (Stable, Excellent)
            -   `removeAt`: ~20.75 us (Stable, Excellent)
            -   `removeWhere`: ~2985.37 us (Stable, Competitive)
            -   `iterateSum`: ~271.81 us (Stable, Competitive)
            -   `sublist`: ~6.13 us (Stable, Excellent)
            -   `concat(+)`: ~7.82 us (Stable, Very good)
            -   `toList`: ~772.02 us (Stable, Competitive)
            -   `fromIterable`: ~3144.22 us (Stable, slower than FIC but accepted trade-off)
            -   *Conclusion:* Performance remains stable and largely consistent with previous runs after map iterator fixes. Minor fluctuations likely due to benchmark noise. Key operations maintain excellent performance relative to competitors.

## Current Focus

-   **ApexList:** Core logic stable.
-   **ApexMap:** Fixed structural errors in `champ_node.dart`. Updated Dartdocs.
-   **Testing:** Refactored `ChampTrieIterator` to fix map test failures. **All tests now pass.**
-   **Benchmarking:** Re-ran benchmarks after fixing `ChampTrieIterator`. Confirmed `ApexList` stability. Confirmed previous `ApexMap` iteration/`toMap` speedup was due to incorrect iterator logic; current (slower) results reflect correct behavior.
-   **Documentation:** Updated Dartdocs for `ApexList` and `ApexMap` based on latest changes and benchmarks.

## Next Immediate Steps

1.  **(DONE)** Fix `champ_node.dart` structural errors (missing `ChampArrayNode`, misplaced methods).
2.  **(DONE)** Resolve persistent Dart Analyzer errors via cache clearing and `git stash`.
3.  **(DONE)** Update `ApexList` Dartdocs.
4.  **(DONE)** Update `ApexMap` Dartdocs.
5.  **(DONE)** Re-run benchmarks for `ApexMap` and `ApexList`.
6.  **(DONE)** Refactor `ChampTrieIterator` and verify all tests pass.
7.  **(DONE)** Re-run benchmarks again to confirm results.
8.  **Update Memory Bank:** Reflect latest benchmark results and conclusions. (Current Step)
9.  **Phase 5:** Begin detailed documentation (README updates, examples, potentially GitHub Pages setup).
8.  **Phase 5:** Begin detailed documentation (README updates, examples, potentially GitHub Pages setup).

## Open Questions / Decisions

-   Need for transient/mutable builders? (Decision remains: Low priority for Map, explore for List later)
-   Further `ApexMap` single-op/`fromMap` optimization? (Decision remains: Deferred)