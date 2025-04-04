# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~21:38 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Performance Optimization & Benchmarking IN PROGRESS.**
    -   **ApexMap:**
        -   Bulk modifications (`addAll`, `remove`, `update`), iteration (`iterateEntries`), `toMap` remain **excellent**.
        -   Single `add`/`lookup` performance is acceptable but slower than competitors.
        -   **CRITICAL ISSUE:** `ApexMap.fromMap` performance remains **extremely poor** (`~11000-12000 us`). Multiple bulk loading algorithm attempts (v1-v4) failed to improve performance significantly. Root cause unclear, likely requires profiling. Needs dedicated investigation/debugging.
    -   **ApexList:**
        -   `add`, `removeAt`, `addAll` performance remains good.
        -   `concat(+)` performance is now **excellent** (`~6 us`) after implementing O(log N) algorithm.
        -   `removeWhere` performance is acceptable (`~2500 us`) after reverting transient attempt. Faster than Native List, slower than FIC.
        -   `sublist` performance is now **excellent** (`~32 us`) after implementing O(log N) tree slicing (`_sliceTree`).
        -   `toList` performance (`~960 us`) improved by restoring recursive helper, but still slower than FIC (`~680 us`).
        -   `fromIterable` performance (`~1760 us`) is significantly slower than FIC (`~650 us`). Reverted from iterative transient add back to bottom-up transient build. Further optimization needed (e.g., optimize node/size table creation).
        -   Iteration (`iterateSum`) performance (`~260-300 us`) is acceptable, slightly faster than FIC.
    -   **KNOWN ISSUE (ApexList - RRB Tree):** The `_rebalanceOrMerge` logic in `RrbInternalNode` is incomplete for the "Cannot steal" edge case. (Status unchanged, deemed lower priority for now).

## Current Focus

-   **Phase 4: Performance Optimization & Benchmarking** (Implementing advanced algorithms for identified bottlenecks)

## Next Immediate Steps

1.  **FIX `ApexMap.fromMap` Performance:** Multiple bulk loading attempts failed. Performance remains critical issue. **Suggest profiling with DevTools or deferring.** **(Highest Priority - Blocked)**
2.  **Optimize `ApexList.sublist`:** **DONE.** Implemented O(log N) tree slicing (`_sliceTree`).
3.  **Optimize `ApexList.fromIterable`:** Reverted iterative transient add attempt. Bottom-up transient build is better but still needs optimization.
4.  **Optimize `ApexList.toList`:** Recursive helper (`~880 us`) is faster than iterator approach (`~2200 us`), but still slower than FIC (`~620 us`). Further optimization needed.
5.  **(Lower Priority) Refine RRB-Tree `_rebalanceOrMerge`:** **DONE.** Implemented merge-split logic for "Cannot steal" edge case in immutable path. (Transient path still unimplemented).
6.  **(Lower Priority) Investigate `ApexMap` `add`/`lookup`:** Explore potential micro-optimizations if needed after major issues resolved.
7.  **Begin Documentation:** **IN PROGRESS.** Updated `ApexList` and `ApexMap` API docs (complexity notes, known issues).

## Open Questions / Decisions

-   Need for transient/mutable builders?
    -   **ApexMap:** Decided - Low priority.
    -   **ApexList:** Decided - Worth exploring/implementing optimizations, pending iterator investigation.
-   How to handle the "Cannot steal" edge case in `_rebalanceOrMerge`? (Needs research/decision)