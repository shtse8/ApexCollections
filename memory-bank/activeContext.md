# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~10:41 UTC+1)

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
        -   Refactored `ApexMap._buildNode` to reduce intermediate list allocations (~10% `fromMap` improvement initially, but regressed after later changes were reverted).
        -   Fixed `ApexList.toList` performance regression by reverting to recursive helper.
        -   Attempted optimization of `RrbInternalNode.fromRange` (Reverted - worsened performance).
        -   Attempted optimization of `ChampInternalNode` immutable helpers (Reverted - worsened performance).
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All `apex_map_test.dart` tests pass.
        -   **(Resolved)** List Test Runtime Error: The `StateError: Cannot rebalance incompatible nodes...` in `RrbInternalNode._rebalanceOrMerge` has been addressed by implementing a plan-based rebalancing strategy (`_createRebalancePlan`, `_executeRebalancePlan`) for the immutable path. All `apex_list_test.dart` tests now pass.
        -   **(Known Issue)** The transient path for `_rebalanceOrMerge` (plan-based case) uses immutable node creation logic instead of mutating in place. Needs optimization.
    -   **Performance Status (Updated 2025-04-04 ~11:07 UTC+1 - Post `_rebalanceOrMerge` Fix):**
        -   **ApexMap (Size: 10k):** (No changes)
            -   `add`: ~4.02 us
            -   `addAll`: ~29.49 us
            -   `lookup[]`: ~0.23 us
            -   `remove`: ~3.61 us
            -   `update`: ~8.16 us
            -   `iterateEntries`: ~2497 us
            -   `toMap`: ~8413 us
            -   `fromMap`: ~7427 us
            -   *Conclusion:* Single-element ops remain slow compared to competitors.
        -   **ApexList (Size: 10k):**
            -   `add`: ~28.8 us (Much faster than FIC)
            -   `addAll`: ~192 us (Slower than FIC - Needs transient optimization)
            -   `lookup[]`: ~0.37 us (Slower than FIC/Native)
            -   `removeAt`: ~15.8 us (Excellent - Much faster than FIC/Native)
            -   `removeWhere`: ~2348 us (Competitive)
            -   `iterateSum`: ~245 us (Competitive)
            -   `sublist`: ~30.1 us (Excellent - Much faster than FIC/Native)
            -   `concat(+)`: ~5.7 us (Very good, slower than FIC)
            -   `toList`: ~717 us (Competitive)
            -   `fromIterable`: ~1794 us (Slower than FIC - Needs optimization)
            -   *Conclusion:* Core rebalancing fix successful. `removeAt` and `sublist` show excellent performance. Key optimization areas are `addAll`/`fromIterable` (transient path) and `lookup[]`.

## Current Focus

-   **ApexList:** Addressed the core `_rebalanceOrMerge` bug for the immutable path. Transient path still needs implementation.
-   **Testing:** Verified `ApexList` tests pass after rebalancing fix.
-   **Benchmarking:** Ran `ApexList` benchmarks.

## Next Immediate Steps

1.  **(DONE)** **Update Memory Bank:** Reflected previous fixes and state.
2.  **(DONE)** **FIX `_rebalanceOrMerge` Error (Immutable Path):** Implemented plan-based rebalancing. Verified with tests.
3.  **(DONE)** **Implement `_rebalanceOrMerge` Transient Path (Merge/Steal):** Implemented merge/steal logic for transient path. Verified with tests.
4.  **(DONE)** **Benchmark `ApexList`:** Ran benchmarks after fixes.
5.  **(TODO / High Priority)** **Optimize `_rebalanceOrMerge` Transient Path (Plan-based):** Modify `_executeRebalancePlan` or create a transient version to mutate nodes in place instead of creating new ones for the final rebalancing case. This is key for `addAll`/`fromIterable` performance.
6.  **(TODO / Medium Priority)** **Optimize `ApexList.fromIterable`:** Revisit bulk loading strategy alongside transient optimizations.
7.  **(TODO / Medium Priority)** **Optimize `ApexList.lookup[]`:** Investigate tree traversal/indexing logic.
4.  **(Lower Priority / Blocked by #2)** **Benchmark:** Re-run benchmarks once list implementation is stable. (Map benchmarks run during optimization attempts).
5.  **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`/`remove`/`update`:** Explore further potential micro-optimizations in immutable path list handling or core logic.
6.  **(Lower Priority)** **Investigate `ApexMap.fromMap`:** Revisit `_buildNode` refactor or explore alternative bulk load strategies.
7.  **Continue Documentation:** Update API docs based on refactoring and fixes.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to efficiently implement the *transient* plan-based rebalancing in `_rebalanceOrMerge` to avoid unnecessary node creation? (Related to Step 5 above)