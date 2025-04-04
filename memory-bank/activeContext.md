# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~06:36 UTC+1)

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
        -   **(Known Issue)** List Test Runtime Error: `Bad state: Cannot merge-split nodes of different types or heights: RrbLeafNode<int> and RrbInternalNode<int>` in `RrbInternalNode._rebalanceOrMerge`. Attempts to fix were reverted. Requires deeper investigation/refactor of rebalancing logic.
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
 
-   **ApexList:** Addressing known issues and performance optimizations.
-   **Documentation:** Updating Memory Bank files.

## Next Immediate Steps
 
1.  **Update Memory Bank:** Reflect recent fixes and current state in `progress.md`.
2.  **(Lower Priority / Blocked)** **FIX `_rebalanceOrMerge` Error:** Address the `Bad state` error in `rrb_node.dart`. (Requires significant refactor).
3.  **(Done - Needs Benchmarking)** **Optimize `ApexList.fromIterable`:** Implemented node constructor changes to avoid `sublist` copies.
4.  **(Lower Priority)** **Benchmark:** Re-run benchmarks for `ApexMap.fromMap` and `ApexList.toList`.
5.  **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`:** Explore potential micro-optimizations.
6.  **Continue Documentation:** Update API docs based on refactoring and fixes.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to correctly implement RRB-Tree rebalancing/merging/collapsing logic, especially for the immutable path in `removeAt`? (Needs significant research/refactor - Related to Step 2 above)