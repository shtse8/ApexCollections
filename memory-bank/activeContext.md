# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~07:13 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Refactoring & Debugging IN PROGRESS.**
    -   **Refactoring:**
        -   Extracted RRB-Tree utility functions from `ApexListImpl` into `rrb_tree_utils.dart`.
        -   Refactored `ChampInternalNode` in `champ_node.dart` to separate transient/immutable logic paths.
        -   Extracted `ChampTrieIterator` from `ApexMapImpl` into `champ_iterator.dart`.
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All `apex_map_test.dart` tests pass.
        -   **(Known Issue)** List Test Runtime Error: Now throws `StateError: Cannot rebalance incompatible nodes (cannot merge/steal)...` in `RrbInternalNode._rebalanceOrMerge` (changed from `UnimplementedError` as an interim step). The specific case where nodes cannot be merged or stolen due to type/height mismatch remains unhandled. Requires significant refactor/research of rebalancing logic. The transient path also remains unimplemented.
    -   **Performance Status (from previous context, likely unchanged):**
        -   **ApexMap:**
            -   Bulk modifications (`addAll`, `remove`, `update`), iteration (`iterateEntries`), `toMap` remain **excellent**.
            -   Single `add`/`lookup` performance is acceptable but slower than competitors.
            -   **(Resolved)** `ApexMap.fromMap` performance significantly improved by implementing O(N) recursive bulk loading. (Needs new benchmarks).
        -   **ApexList:**
            -   `add`, `removeAt`, `addAll` performance remains good.
            -   `concat(+)` performance is **excellent** (`~6 us`).
            -   `removeWhere` performance is acceptable (`~2500 us`).
            -   `sublist` performance is **excellent** (`~32 us`).
            -   `toList` performance (`~960 us`) potentially improved by switching to iterator-based implementation (Needs new benchmarks).
            -   `fromIterable` performance (`~1760 us`) optimization attempted by modifying node constructors to avoid `sublist` copies (Needs new benchmarks).
            -   Iteration (`iterateSum`) performance (`~260-300 us`) is acceptable.

## Current Focus

-   **ApexList:** Addressing known issues (primarily the `_rebalanceOrMerge` implementation).
-   **Documentation:** Updating Memory Bank files (now complete for this step).

## Next Immediate Steps

1.  **(DONE)** **Update Memory Bank:** Reflected recent fixes and current state in `progress.md` and `activeContext.md`.
2.  **(Blocked / High Priority)** **FIX `_rebalanceOrMerge` Error:** Address the `UnimplementedError` for incompatible node rebalancing (immutable path) in `rrb_node.dart`. Also need to implement the transient path. (Requires significant refactor/research).
3.  **(Done - Needs Benchmarking)** **Optimize `ApexList.fromIterable`:** Implemented node constructor changes to avoid `sublist` copies.
4.  **(Lower Priority / Blocked by #2)** **Benchmark:** Re-run benchmarks for `ApexMap.fromMap`, `ApexList.toList`, and `ApexList.fromIterable` once list implementation is stable.
5.  **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`:** Explore potential micro-optimizations.
6.  **Continue Documentation:** Update API docs based on refactoring and fixes.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to correctly implement RRB-Tree rebalancing/merging/collapsing logic, especially for the immutable path in `removeAt` when nodes are incompatible (cannot merge/steal)? (Needs significant research/refactor - Related to Step 2 above)