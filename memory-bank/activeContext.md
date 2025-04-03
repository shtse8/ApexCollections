# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~13:21 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE** (Excluding deferred `removeAt` debugging).
-   **Phase 4: Performance Optimization & Benchmarking IN PROGRESS.**
    -   Initial benchmarks for `ApexList` and `ApexMap` against native and FIC collections completed.
    -   **ApexMap:** Shows strong performance for bulk modifications (`addAll`, `remove`, `update`) and iteration due to internal transient logic. Slower on single `add`/`lookup`.
    -   **ApexList:**
        -   Shows good performance for single `add`/`removeAt`/`lookup`.
        -   `addAll` optimized using transient `add`, showing significant improvement.
        -   `operator+` reverted to iterate/rebuild after transient `add` approach caused regression.
        -   `removeWhere` uses immutable filter/rebuild.
        -   `sublist`, `concat(+)` still use iterate/rebuild.
        -   **Iteration performance is notably slower than native/FIC.**
    -   **KNOWN ISSUE (ApexList):** The `removeAt causes node merges/rebalancing` test still fails due to an assertion in `RrbLeafNode.removeAt`, indicating an invalid index calculation persists in complex rebalancing scenarios within `RrbInternalNode.removeAt`. Requires further debugging.

## Current Focus

-   **Phase 4: Performance Optimization & Benchmarking** (Investigating ApexList iteration)

## Next Immediate Steps

1.  **(Deferred) Debug RRB-Tree `removeAt` Rebalancing:** Investigate the assertion failure.
2.  **(Decision Made) Evaluate Transient Builders:**
    -   **ApexMap:** Dedicated public builder is **low priority**.
    -   **ApexList:** Transient builders or node-level ops **worthwhile**.
3.  **Investigate `ApexList` Iterator Performance:** Analyze `_RrbTreeIterator` implementation for potential bottlenecks causing slow iteration compared to alternatives.
4.  **Optimize `ApexList` Bulk Operations (Post-Iterator Fix):** Revisit `sublist`, `operator+` for node-level optimizations if iterator improvements aren't sufficient or if further gains are desired. Consider transient builder if node ops are too complex.
5.  **Re-run Benchmarks:** After optimizations, re-run benchmarks.
6.  **Begin Documentation:** Start writing basic API documentation.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.