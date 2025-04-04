# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~10:21 UTC+1)

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
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All `apex_map_test.dart` tests pass.
        -   **(Known Issue)** List Test Runtime Error: Now throws `StateError: Cannot rebalance incompatible nodes (cannot merge/steal)...` in `RrbInternalNode._rebalanceOrMerge` (changed from `UnimplementedError` as an interim step). The specific case where nodes cannot be merged or stolen due to type/height mismatch remains unhandled. Requires significant refactor/research of rebalancing logic. The transient path also remains unimplemented.
    -   **Performance Status (Updated 2025-04-04 ~10:14 UTC+1):**
        -   **ApexMap (Size: 10k):**
            -   `add`: ~4.09 us (Still slower than Native ~0.08us, FIC ~0.16us)
            -   `addAll`: ~31.1 us (Excellent)
            -   `lookup[]`: ~0.23 us (Still slower than Native ~0.03us, FIC ~0.06us)
            -   `remove`: ~3.59 us
            -   `update`: ~8.26 us
            -   `iterateEntries`: ~2622 us
            -   `toMap`: ~8191 us
            -   `fromMap`: ~8558 us (Excellent - O(N) bulk load)
            -   *Conclusion:* `containsKey` and `bitCount` optimizations did not significantly close the gap for single `add`/`lookup` vs competitors. Bulk operations remain very fast.
        -   **ApexList (Size: 10k):**
            -   `add`: ~26.88 us
            -   `addAll`: ~187.83 us
            -   `lookup[]`: ~0.42 us
            -   `removeAt`: ~16.44 us (Note: May be affected by known bug)
            -   `removeWhere`: ~2429 us
            -   `iterateSum`: ~243.83 us
            -   `sublist`: ~31.63 us (Excellent)
            -   `concat(+)`: ~6.03 us (Excellent)
            -   `toList`: ~2179 us (Slower than previous context/FIC)
            -   `fromIterable`: ~1821 us (Similar to previous context, slower than FIC)
            -   *Conclusion:* `toList` performance seems to have regressed or is slower than expected. `fromIterable` optimization attempt was ineffective. Further list optimization blocked by `removeAt` bug.

## Current Focus

-   **ApexList:** Addressing known issues (primarily the `_rebalanceOrMerge` implementation).
-   **Documentation:** Updating Memory Bank files (now complete for this step).

## Next Immediate Steps

1.  **(DONE)** **Update Memory Bank:** Reflected recent fixes and current state in `progress.md` and `activeContext.md`.
2.  **(Blocked / High Priority)** **FIX `_rebalanceOrMerge` Error:** Address the `UnimplementedError` for incompatible node rebalancing (immutable path) in `rrb_node.dart`. Also need to implement the transient path. (Requires significant refactor/research).
3.  **(Done - Needs Benchmarking)** **Optimize `ApexList.fromIterable`:** Implemented node constructor changes to avoid `sublist` copies.
4.  **(Lower Priority / Blocked by #2)** **Benchmark:** Re-run benchmarks for `ApexMap.fromMap`, `ApexList.toList`, and `ApexList.fromIterable` once list implementation is stable.
5.  **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`:** Explore further potential micro-optimizations.
6.  **(Lower Priority / Blocked by #2)** **Benchmark `containsKey`:** Verify performance impact of the dedicated `containsKey` implementation.
7.  **(Lower Priority / Blocked by #2)** **Benchmark `bitCount`:** Verify performance impact of the optimized `bitCount` function (affects `add`/`get`/`remove`/etc.).
8.  **Continue Documentation:** Update API docs based on refactoring and fixes.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to correctly implement RRB-Tree rebalancing/merging/collapsing logic, especially for the immutable path in `removeAt` when nodes are incompatible (cannot merge/steal)? (Needs significant research/refactor - Related to Step 2 above)