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
        -   **(Known Issue)** List Test Runtime Error: Now throws `StateError: Cannot rebalance incompatible nodes (cannot merge/steal)...` in `RrbInternalNode._rebalanceOrMerge` (changed from `UnimplementedError` as an interim step). The specific case where nodes cannot be merged or stolen due to type/height mismatch remains unhandled. Requires significant refactor/research of rebalancing logic. The transient path also remains unimplemented.
    -   **Performance Status (Updated 2025-04-04 ~10:41 UTC+1):**
        -   **ApexMap (Size: 10k):**
            -   `add`: ~4.02 us (Slower than Native/FIC)
            -   `addAll`: ~29.49 us (Excellent)
            -   `lookup[]`: ~0.23 us (Slower than Native/FIC)
            -   `remove`: ~3.61 us (Slower than Native/FIC)
            -   `update`: ~8.16 us (Slower than Native/FIC)
            -   `iterateEntries`: ~2497 us
            -   `toMap`: ~8413 us
            -   `fromMap`: ~7427 us (Improved vs previous, but still slower than FIC)
            -   *Conclusion:* `_buildNode` refactor provides ~10-15% `fromMap` improvement. Micro-optimizations (`containsKey`, `bitCount`) had minimal impact. Single-element ops remain slow.
        -   **ApexList (Size: 10k):**
            -   `add`: ~27.10 us
            -   `addAll`: ~198.18 us
            -   `lookup[]`: ~0.35 us
            -   `removeAt`: ~17.38 us (Note: May be affected by known bug)
            -   `removeWhere`: ~2595 us
            -   `iterateSum`: ~247.67 us
            -   `sublist`: ~33.09 us (Excellent)
            -   `concat(+)`: ~6.49 us (Excellent)
            -   `toList`: ~744 us (Regression fixed, now competitive with FIC)
            -   `fromIterable`: ~1991 us (Slower than FIC; optimization attempt reverted)
            -   *Conclusion:* `toList` performance restored. `fromIterable` remains slow. Further list optimization blocked by `removeAt` bug.

## Current Focus

-   **ApexList:** Addressing known issues (primarily the `_rebalanceOrMerge` implementation).
-   **Documentation:** Updating Memory Bank files (now complete for this step).

## Next Immediate Steps

1.  **(DONE)** **Update Memory Bank:** Reflected recent fixes and current state in `progress.md` and `activeContext.md`.
2.  **(Blocked / High Priority)** **FIX `_rebalanceOrMerge` Error:** Address the `UnimplementedError` for incompatible node rebalancing (immutable path) in `rrb_node.dart`. Also need to implement the transient path. (Requires significant refactor/research).
3.  **(Done - Needs Benchmarking)** **Optimize `ApexList.fromIterable`:** Implemented node constructor changes to avoid `sublist` copies. (Optimization attempt reverted).
4.  **(Lower Priority / Blocked by #2)** **Benchmark:** Re-run benchmarks once list implementation is stable. (Map benchmarks run during optimization attempts).
5.  **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`/`remove`/`update`:** Explore further potential micro-optimizations in immutable path list handling or core logic.
6.  **(Lower Priority)** **Investigate `ApexMap.fromMap`:** Revisit `_buildNode` refactor or explore alternative bulk load strategies.
7.  **Continue Documentation:** Update API docs based on refactoring and fixes.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to correctly implement RRB-Tree rebalancing/merging/collapsing logic, especially for the immutable path in `removeAt` when nodes are incompatible (cannot merge/steal)? (Needs significant research/refactor - Related to Step 2 above)