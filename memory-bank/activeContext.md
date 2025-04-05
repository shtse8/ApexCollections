<!-- Version: 1.14 | Last Updated: 2025-04-05 | Updated By: Cline -->
# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-05 ~05:25 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Refactoring & Debugging COMPLETE.** (Core bugs fixed, iterator reverted to correct but slow version)
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
        -   Fixed `champ_node.dart` structural errors (missing `ChampArrayNode` definition, misplaced methods).
        -   Refactored `ChampTrieIterator` logic to fix test failures (Reverted optimization attempts).
        -   **Split `apex_map_test.dart` and `apex_list_test.dart` into smaller files based on test groups to adhere to <500 LoC rule.**
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All map tests pass after splitting.
        -   **(Resolved)** List Test Runtime Error: The `StateError: Cannot rebalance incompatible nodes...` in `RrbInternalNode._rebalanceOrMerge` has been addressed by implementing a plan-based rebalancing strategy (`_createRebalancePlan`, `_executeRebalancePlan`) for the immutable path. All list tests pass after splitting.
        -   **(Resolved)** The transient path for `_rebalanceOrMerge` (plan-based case) now uses `_executeTransientRebalancePlan` to mutate nodes in place.
        -   **(Resolved)** Persistent Dart Analyzer errors related to `ChampArrayNode` resolved by fixing `champ_node.dart` structure, clearing `.dart_tool`, and using `git stash pop`.
        -   **(Resolved)** Multiple `ApexMap` test failures resolved by refactoring `ChampTrieIterator`. **All tests now pass with the reverted (slower) iterator.**
    -   **Performance Status (Updated 2025-04-05 ~01:33 UTC+1 - After iterator refactoring attempt):**
        -   **ApexMap (Size: 10k):**
            -   `add`: ~4.80 us (Slightly slower than previous)
            -   `addAll`: ~36.39 us (Slightly slower than previous, still Excellent)
            -   `lookup[]`: ~0.22 us (Stable)
            -   `remove`: ~4.21 us (Slightly slower than previous, still much faster than FIC)
            -   `update`: ~9.53 us (Slightly slower than previous, still faster than FIC)
            -   `iterateEntries`: **~3485 us** (**Worsened**, now **~2.95x slower than FIC** ~1181 us)
            -   `toMap`: **~10907 us** (**Worsened**, now ~1.69x slower than FIC ~6454 us)
            -   `fromMap`: ~9888 us (Slightly slower than previous)
            -   *Conclusion:* The iterator refactoring (avoiding MapEntry in moveNext, changing traversal order) **failed to improve iteration performance and slightly worsened most operations**. The core performance issues with CHAMP in Dart persist, particularly the iteration bottleneck likely related to `iterator.current` overhead or fundamental structure/traversal costs.
        -   **ApexList (Size: 10k):** (No recent changes)
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
-   **Testing:** Refactored `ChampTrieIterator` to fix map test failures. **Split large test files (`apex_map_test.dart`, `apex_list_test.dart`) into smaller, focused files.** All tests now pass.
-   **Benchmarking:** Attempted several `ApexMap` iterator optimizations (state machine, List stack, reduced bitCount calls, `_BitmapPayloadRef` to avoid temporary `MapEntry`) - **all failed due to introducing logic errors and were reverted.** Attempted element hash code consolidation - failed and reverted. Optimized `ApexMapImpl._buildNode` second pass - Success (`fromMap` improved). **Refactored iterator again (avoid MapEntry in moveNext, change traversal order) - benchmarks show performance worsened.**
-   **Documentation:** Updated Dartdocs for `ApexList` and `ApexMap`. Added docs for new iterator getters.

## Next Immediate Steps

1.  **(DONE)** Fix `champ_node.dart` structural errors.
2.  **(DONE)** Resolve persistent Dart Analyzer errors.
3.  **(DONE)** Update `ApexList` Dartdocs.
4.  **(DONE)** Update `ApexMap` Dartdocs.
5.  **(DONE)** Re-run benchmarks (initial).
6.  **(DONE)** Refactor `ChampTrieIterator` (initial fix).
7.  **(DONE)** Re-run benchmarks (confirmed slow iteration).
8.  **(DONE)** Attempt iterator optimization (`_BitmapPayloadRef`) - Failed (logic errors).
9.  **(DONE)** Revert iterator optimization attempt.
10. **(DONE)** Attempt iterator optimization (`_BitmapPayloadRef` - 2nd try) - Failed (logic errors).
11. **(DONE)** Revert iterator optimization attempt (using `write_to_file`).
12. **(DONE)** Verify tests pass with reverted iterator.
13. **(DONE)** Run final benchmarks with correct (but slow) iterator.
14. **(DONE)** Update Memory Bank: Reflect final CHAMP benchmarks and decision.
15. **(DONE)** Commit Changes: Commit the current working state (correct but slow iterator).
16. **(DONE)** Strategic Pivot: Based on persistent iteration performance issues and failed optimization attempts, **abandon CHAMP** as the underlying structure for `ApexMap`.
17. **(DONE)** Research HAMT: Begin research into Hash Array Mapped Tries (HAMT) as the alternative data structure, focusing on implementations optimized for iteration and lookup performance in Dart/JVM/JS environments.
18. **(DONE)** Split large test files (`apex_map_test.dart`, `apex_list_test.dart`). (This step)
19. **Commit Changes:** Commit the test file splitting changes.
20. **Phase 4.5:** Reconfirm pivot and begin HAMT research/design, focusing on efficient iterator.

## Open Questions / Decisions

-   Need for transient/mutable builders? (Decision remains: Low priority for Map, explore for List later)
-   Further `ApexMap` CHAMP optimization? **(Decision: Re-abandoned after refactoring failed to improve performance)**
-   How to best approach HAMT research and implementation for `ApexMap`? (Focus on iterator design avoiding temporary objects)