# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~05:24 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing IN PROGRESS.**
    -   **ApexMap:** Basic implementation and tests complete. Needs refinement for bulk ops and `==`/`hashCode`.
    -   **ApexList:**
        -   RRB-Tree node logic (`rrb_node.dart`) implemented, including `insertAt`, rebalancing helpers (`_borrowFromLeft`, `_borrowFromRight`, `_mergeWithLeft`), and size table calculations.
        -   `ApexListImpl` methods (`add`, `insert`, `removeAt`, `update`, `addAll`, `insertAll`, `sublist`, `operator+`, `indexOf`, `lastIndexOf`, `clear`, `==`, `hashCode`) implemented using node operations or efficient iteration.
        -   Unit tests added for most `ApexList` methods, including node split/rebalance scenarios.
        -   **KNOWN ISSUE:** The `removeAt causes node merges/rebalancing` test still fails due to an assertion in `RrbLeafNode.removeAt`, indicating an invalid index calculation persists in complex rebalancing scenarios within `RrbInternalNode.removeAt`. Requires further debugging.

## Current Focus

-   **Continuing Phase 3: Implementation & Unit Testing**

## Next Immediate Steps

1.  **(Blocked/Deferred) Debug RRB-Tree `removeAt` Rebalancing:** Investigate the assertion failure in the `removeAt causes node merges/rebalancing` test. (Deferring due to difficulty pinpointing the exact interaction).
2.  **Refine `ApexMapImpl` Methods:** Implement efficient versions of remaining `ApexMapImpl` methods (`fromMap`, `addAll`, `update`, `updateAll`, `removeWhere`, `mapEntries`, `==`, `hashCode`).
3.  **Implement Remaining Efficient `ApexListImpl` Methods:** Implement efficient versions for `removeWhere`, `sort`, `shuffle`. Consider node-level optimizations for `sublist` and `operator+`.
4.  **Complete `ApexList` & `ApexMap` Unit Tests:** Add tests for remaining methods and edge cases.

## Open Questions / Decisions

-   Need for transient/mutable builders for efficient bulk operations (`fromIterable`, `addAll`, `insertAll`, `removeWhere`, etc.) in both `ApexList` and `ApexMap`. (Defer decision until core logic is stable and benchmarked).