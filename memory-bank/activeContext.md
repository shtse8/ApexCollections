# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~21:38 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Performance Optimization & Benchmarking IN PROGRESS.**
    -   **ApexMap:**
        -   Bulk modifications (`addAll`, `remove`, `update`), iteration (`iterateEntries`), `toMap` remain **excellent**.
        -   Single `add`/`lookup` performance is acceptable but slower than competitors.
        -   **CRITICAL ISSUE:** `ApexMap.fromMap` performance remains **extremely poor** (`~13000-15000 us`). Bulk loading attempts failed/reverted. Needs dedicated investigation/debugging.
    -   **ApexList:**
        -   `add`, `removeAt`, `addAll` performance remains good.
        -   `concat(+)` performance is now **excellent** (`~6 us`) after implementing O(log N) algorithm.
        -   `removeWhere` performance is acceptable (`~2500 us`) after reverting transient attempt. Faster than Native List, slower than FIC.
        -   `sublist` performance is poor (`~2400 us`). O(log N) attempt reverted. Needs improvement.
        -   `toList` performance (`~960 us`) improved by restoring recursive helper, but still slower than FIC (`~680 us`).
        -   `fromIterable` performance (`~2000 us`) is significantly slower than FIC (`~790 us`). Needs optimization (bulk loading?).
        -   Iteration (`iterateSum`) performance (`~260-300 us`) is acceptable, slightly faster than FIC.
    -   **KNOWN ISSUE (ApexList - RRB Tree):** The `_rebalanceOrMerge` logic in `RrbInternalNode` is incomplete for the "Cannot steal" edge case. (Status unchanged, deemed lower priority for now).

## Current Focus

-   **Phase 4: Performance Optimization & Benchmarking** (Implementing advanced algorithms for identified bottlenecks)

## Next Immediate Steps

1.  **FIX `ApexMap.fromMap` Performance:** Reverted failed bulk loading attempts. Needs dedicated investigation and debugging of the bulk loading algorithm. **(Highest Priority)**
2.  **Optimize `ApexList.sublist`:** Reverted failed O(log N) attempt. Needs investigation/re-implementation of efficient slicing.
3.  **Optimize `ApexList.fromIterable`:** Investigate **RRB-Tree bulk loading** or other optimizations.
4.  **Optimize `ApexList.toList`:** Recursive helper is better than `List.of`, but still slower than FIC. Further investigation needed (iterator vs direct traversal).
5.  **(Lower Priority) Refine RRB-Tree `_rebalanceOrMerge`:** Implement proper handling for the "Cannot steal" edge case.
6.  **(Lower Priority) Investigate `ApexMap` `add`/`lookup`:** Explore potential micro-optimizations if needed after major issues resolved.
7.  **Begin Documentation:** Start writing basic API documentation.

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to handle the "Cannot steal" edge case in `_rebalanceOrMerge`? (Needs research/decision)