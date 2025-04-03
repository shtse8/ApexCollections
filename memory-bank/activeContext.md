# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~17:27 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Performance Optimization & Benchmarking IN PROGRESS.**
    -   Initial benchmarks for `ApexList` and `ApexMap` completed.
    -   **ApexMap:** Shows strong performance for bulk modifications (`addAll`, `remove`, `update`) and iteration. Slower on single `add`/`lookup`.
    -   **ApexList:**
        -   Shows good performance for single `add`/`removeAt`/`lookup`.
        -   `addAll` optimized using transient `add`.
        -   `operator+` reverted to iterate/rebuild.
        -   `removeWhere` uses immutable filter/rebuild.
        -   `sublist`, `concat(+)` still use iterate/rebuild.
        -   Iteration performance optimized.
    -   **FIXED (Partially):** The `removeAt causes node merges/rebalancing` test now passes after implementing immutable merge and steal logic in `RrbInternalNode._rebalanceOrMerge`.
    -   **KNOWN ISSUE (ApexList):** The `_rebalanceOrMerge` logic is incomplete. The edge case where a node is underfull but cannot steal from neighbors (e.g., neighbors are also minimal size) currently returns unmodified nodes instead of performing a more complex rebalancing or allowing slightly underfull nodes temporarily. This needs proper implementation.

## Current Focus

-   **Phase 4: Performance Optimization & Benchmarking** (Refining RRB-Tree `removeAt` rebalancing, Optimizing Bulk Ops)

## Next Immediate Steps

1.  **(IN PROGRESS) Refine RRB-Tree `_rebalanceOrMerge`:** Implement proper handling for the "Cannot steal" edge case identified during testing.
2.  **Optimize `ApexList` Bulk Operations:** Revisit `sublist`, `operator+` for node-level optimizations. Consider transient builder.
3.  **Implement Transient Rebalancing:** Add merge/steal logic to the transient path in `_rebalanceOrMerge`.
4.  **Re-run Benchmarks:** After further optimizations, re-run benchmarks.
5.  **Begin Documentation:** Start writing basic API documentation.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to handle the "Cannot steal" edge case in `_rebalanceOrMerge`? (Needs research/decision)