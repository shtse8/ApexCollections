# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~14:30 UTC+1)

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
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All `apex_map_test.dart` tests pass.
        -   **(Resolved)** List Test Runtime Error: The `StateError: Cannot rebalance incompatible nodes...` in `RrbInternalNode._rebalanceOrMerge` has been addressed by implementing a plan-based rebalancing strategy (`_createRebalancePlan`, `_executeRebalancePlan`) for the immutable path. All `apex_list_test.dart` tests now pass.
        -   **(Resolved)** The transient path for `_rebalanceOrMerge` (plan-based case) now uses `_executeTransientRebalancePlan` to mutate nodes in place.
    -   **Performance Status (Updated 2025-04-04 ~14:30 UTC+1 - Final state after optimization attempts):**
        -   **ApexMap (Size: 10k):** (Optimization attempts reverted)
            -   `add`: ~6.25 us (Slower than Native/FIC)
            -   `addAll`: ~31.60 us (Excellent - Much faster than Native/FIC)
            -   `lookup[]`: ~0.24 us (Slower than Native/FIC)
            -   `remove`: ~3.72 us (Much faster than FIC)
            -   `update`: ~8.91 us (Faster than FIC)
            -   `iterateEntries`: ~2794 us (Slow)
            -   `toMap`: ~8736 us (Slow)
            -   `fromMap`: ~8174 us (Slow)
            -   *Conclusion:* Attempts to optimize immutable helpers (list spreads) and `_buildNode` (single-pass) resulted in performance regressions for core operations and were reverted. `addAll` performance remains excellent. Single-element immutable operations, iteration, and `fromMap` remain significantly slower than competitors. Further map optimization is deferred.
        -   **ApexList (Size: 10k):** (Post `fromIterable` recursive concat strategy)
            -   `add`: ~27.1 us (Much faster than FIC)
            -   `addAll`: ~31.0 us (Excellent - `addAll` optimization holds)
            -   `lookup[]`: ~0.15 us (Excellent - Faster than FIC, approaching Native!)
            -   `removeAt`: ~18.9 us (Excellent - Much faster than FIC/Native)
            -   `removeWhere`: ~2743 us (Competitive)
            -   `iterateSum`: ~263 us (Competitive)
            -   `sublist`: ~5.8 us (Excellent - Much faster than FIC/Native!)
            -   `concat(+)`: ~7.2 us (Very good, slower than FIC)
            -   `toList`: ~727 us (Competitive)
            -   `fromIterable`: ~2960 us (Slower than previous bottom-up build, but acceptable trade-off)
            -   *Conclusion:* Recursive concatenation strategy for `fromIterable` adopted. While build time is slower, it yields significantly faster `lookup[]` and `sublist` performance. `addAll` optimization via concatenation successful. Transient rebalancing optimization successful. Lookup crash fixed. `removeAt` and `sublist` remain excellent.

## Current Focus

-   **ApexList:** Addressed the core `_rebalanceOrMerge` bug for the immutable path. Transient path still needs implementation.
-   **Testing:** Verified `ApexList` tests pass after rebalancing fix.
-   **Benchmarking:** Re-ran `ApexList` benchmarks after changing `fromIterable` strategy. Re-ran `ApexMap` benchmarks after attempting transient optimization in `mergeDataEntries` (no significant change).

## Next Immediate Steps

1.  **(DONE)** **Update Memory Bank:** Reflected previous fixes and state.
2.  **(DONE)** **FIX `_rebalanceOrMerge` Error (Immutable Path):** Implemented plan-based rebalancing. Verified with tests.
3.  **(DONE)** **Implement `_rebalanceOrMerge` Transient Path (Merge/Steal):** Implemented merge/steal logic for transient path. Verified with tests.
4.  **(DONE)** **Benchmark `ApexList`:** Ran benchmarks after fixes.
5.  **(DONE)** **Optimize `_rebalanceOrMerge` Transient Path (Plan-based):** Implemented `_executeTransientRebalancePlan` to mutate nodes in place for the plan-based rebalancing case. This is key for `addAll`/`fromIterable` performance.
6.  **(DONE)** **Benchmark `ApexMap`:** Established baseline performance. Identified optimization targets.
7.  **(DONE)** **Optimize `ApexList.addAll`:** Replaced transient add loop with concatenation strategy. Benchmarks show significant improvement.
8.  **(DONE)** **Optimize `ApexList.fromIterable`:** Switched to recursive concatenation strategy. Build slower, but `lookup`/`sublist` much faster.
9.  **(DONE)** **Optimize `ApexList.lookup[]`:** Investigated O(1) strict path calculation. Reverted due to correctness issues. Kept existing linear scan for strict nodes. Performance remains good due to `fromIterable` change.
10. **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`/`remove`/`update`:** Explore further potential micro-optimizations in immutable path list handling or core logic.
11. **(DONE - Reverted)** **Investigate `ApexMap.fromMap`:** Attempted single-pass `_buildNode` refactor. Improved `fromMap` but regressed other ops. Reverted.
12. **Continue Documentation:** Update API docs based on refactoring and fixes.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   **(Resolved)** Transient plan-based rebalancing implemented via `_executeTransientRebalancePlan`.