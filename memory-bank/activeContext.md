# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~04:57 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing IN PROGRESS.**
    -   Corrected `ChampInternalNode` helper methods (`_replaceDataWithNode`, `_replaceNodeWithData`) with proper `bitpos` handling (`champ_node.dart`).
    -   Defined and used a local `bitCount` function in `champ_node.dart` to resolve previous analyzer issues.
    -   Implemented efficient iterators (`_ChampTrieIterator`, `_RrbTreeIterator`) for `ApexMapImpl` and `ApexListImpl` (`apex_map.dart`, `apex_list.dart`).
    -   Added basic unit tests for `ApexMap` core methods (`add`, `remove`, `get`, `length`, `isEmpty`, `==`, `hashCode`, `containsValue`, `update`, `addAll`, `removeWhere`, `updateAll`, `mapEntries`) and iterator (`apex_map_test.dart`).
    -   Implemented leaf-leaf and internal-internal borrowing logic (`_borrowFromLeft`, `_borrowFromRight`) in `RrbInternalNode` (size table updates need review/completion).
    -   Implemented leaf-leaf and partial internal-internal merging logic (`_mergeWithLeft`) in `RrbInternalNode` (internal split case and size table updates need review/completion).
    -   Added basic unit tests for `ApexList` core methods (`add`, `removeAt`, `update`, `addAll`, `insert`) and iterator (`apex_list_test.dart`).

## Current Focus

-   **Continuing Phase 3: Implementation & Unit Testing**

## Next Immediate Steps

1.  **Implement RRB-Tree Rebalancing/Merging:** Focus on implementing the `_rebalanceOrMerge` logic (and its helpers like `_tryBorrowFromLeft`, `_mergeWithLeft`, etc.) in `RrbInternalNode` (`lib/src/list/rrb_node.dart`). This is critical for `removeAt` correctness.
2.  **Implement Efficient `ApexListImpl` Methods:** Replace inefficient placeholder implementations in `ApexListImpl` (`insert`, `insertAll`, `removeWhere`, `sublist`, `operator+`, `indexOf`, `lastIndexOf`, etc.) with versions that leverage RRB-Tree node operations.
3.  **Complete `ApexList` Unit Tests:** Add tests for remaining methods and edge cases, especially those involving node rebalancing/merging once implemented (`apex_list_test.dart`).
4.  **Refine `ApexMapImpl` Methods:** Implement efficient versions of remaining `ApexMapImpl` methods (`fromMap`, `addAll`, `update`, `updateAll`, `removeWhere`, `mapEntries`, `==`, `hashCode`).

## Open Questions / Decisions

-   Specific strategy for seamless `Iterable` integration (e.g., efficient custom iterators). (Deferred to iterator implementation)
-   Detailed implementation strategy for RRB-Tree rebalancing/merging (Now the immediate focus).
-   Need for transient/mutable builders for efficient bulk operations (`fromIterable`, `addAll`, `insertAll`, `removeWhere`, etc.) in both `ApexList` and `ApexMap`. (Defer decision until core logic is stable).
-   Optimization strategy for `==` and `hashCode` in both implementations (currently inefficient).