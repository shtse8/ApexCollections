# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~17:43 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Performance Optimization & Benchmarking IN PROGRESS.**
    -   Benchmarks updated to include conversion operations (`toList`, `toMap`, `fromIterable`, `fromMap`).
    -   **ApexMap:**
        -   Shows **excellent** performance for bulk modifications (`addAll`, `remove`, `update`), iteration (`iterateEntries`), and conversion to native (`toMap`).
        -   Single `add`/`lookup` performance is acceptable but slower than competitors.
        -   **CRITICAL ISSUE:** `ApexMap.fromMap` performance is **extremely poor** and needs immediate investigation.
    -   **ApexList:**
        -   Shows good performance for single `add` (vs FIC) and `removeAt` (vs both). `addAll` is also good.
        -   Iteration (`iterateSum`), `removeWhere`, `sublist`, `concat(+)` performance needs improvement.
        -   Conversion performance (`toList`, `fromIterable`) is significantly slower than FIC and needs optimization.
    -   **KNOWN ISSUE (ApexList - RRB Tree):** The `_rebalanceOrMerge` logic in `RrbInternalNode` is incomplete for the "Cannot steal" edge case. (Status unchanged)

## Current Focus

-   **Phase 4: Performance Optimization & Benchmarking** (Fixing `ApexMap.fromMap`, Optimizing `ApexList` conversions and bulk ops, Refining RRB-Tree `removeAt`)

## Next Immediate Steps

1.  **FIX `ApexMap.fromMap` Performance:** Investigate the bottleneck in the `ApexMapImpl.fromMap` factory and implement a fix. **(Highest Priority)**
2.  **Optimize `ApexList` Conversions:** Improve `toList` and `fromIterable` performance.
3.  **Optimize `ApexList` Bulk/Range Operations:** Revisit `sublist`, `operator+`, `removeWhere` for node-level or transient optimizations.
4.  **(Lower Priority) Refine RRB-Tree `_rebalanceOrMerge`:** Implement proper handling for the "Cannot steal" edge case.
5.  **Re-run Benchmarks:** After fixes and optimizations, re-run benchmarks.
6.  **Begin Documentation:** Start writing basic API documentation.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to handle the "Cannot steal" edge case in `_rebalanceOrMerge`? (Needs research/decision)