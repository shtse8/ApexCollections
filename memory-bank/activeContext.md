# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~04:15 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
    -   `ApexList` API defined (`apex_list_api.dart`).
    -   `ApexMap` API defined (`apex_map_api.dart`).
    -   Core node structure files outlined (`rrb_node.dart`, `champ_node.dart`).
    -   Basic `ApexListImpl` and `ApexMapImpl` created with placeholder methods.
    -   Empty instance handling implemented.
    -   `progress.md` updated.
-   All changes committed and pushed.

## Current Focus

-   **Starting Phase 3: Implementation & Unit Testing**

## Next Immediate Steps

1.  **Implement RRB-Tree Node Logic:** Focus on `add`, `update`, `removeAt` in `RrbInternalNode` and `RrbLeafNode` (`lib/src/list/rrb_node.dart`), including handling node splits, merges, and rebalancing (addressing TODOs).
2.  **Implement CHAMP Trie Node Logic:** Focus on `add`, `remove` in `ChampInternalNode` and `ChampCollisionNode` (`lib/src/map/champ_node.dart`), including fixing helper methods (`_replaceDataWithNode`, etc.) and handling canonicalization (addressing TODOs).
3.  **Refine `ApexListImpl` / `ApexMapImpl`:** Update methods like `add`, `remove`, `insert`, `sublist`, `operator+` to use the efficient node logic once available. Implement efficient iterators. Fix length tracking in `ApexMapImpl`.
4.  **Write Unit Tests:** Start writing tests for the core node operations and the basic list/map methods.

## Open Questions / Decisions

-   Specific strategy for seamless `Iterable` integration (e.g., efficient custom iterators). (Deferred to iterator implementation)
-   Detailed implementation strategy for RRB-Tree rebalancing/merging.
-   Detailed implementation strategy for CHAMP Trie canonicalization and helper methods.
-   Need for transient/mutable builders for efficient bulk operations (`fromIterable`, `addAll`, `insertAll`, `removeWhere`).