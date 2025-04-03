# Progress: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~17:44 UTC+1)

**Phase 1: Research & Benchmarking COMPLETE.** Foundational research conducted, data structures selected (RRB-Trees, CHAMP Tries), baseline benchmarks established.
**Phase 2: Core Design & API Definition COMPLETE.** Public APIs for `ApexList` and `ApexMap` defined. Core node structure files outlined. Basic implementation classes created. `toMap` added to `ApexMap`.
**Phase 3: Implementation & Unit Testing COMPLETE** (Excluding deferred `removeAt` debugging). Core logic for `ApexListImpl` and `ApexMapImpl` implemented and unit tested. Transient logic refined. `toMap` implemented in `ApexMapImpl`.
**Phase 4: Performance Optimization & Benchmarking IN PROGRESS.** Benchmarks updated with conversion operations. `ApexMap.fromMap` identified as critical performance issue. `ApexList` conversion and bulk ops identified as needing optimization.

## What Works

-   Project directory structure created and Git repository initialized.
-   Core Memory Bank files established and updated.
-   Basic Dart package structure confirmed (`pubspec.yaml`, etc.).
-   Public API definitions for `ApexList` (`lib/src/list/apex_list_api.dart`) and `ApexMap` (`lib/src/map/apex_map_api.dart`).
-   Node structures implemented for RRB-Trees (`lib/src/list/rrb_node.dart`) and CHAMP Tries (`lib/src/map/champ_node.dart`), including transient mutation logic.
-   `ApexMapImpl` methods implemented, using transient operations for bulk methods. Shows strong performance for modifications/iteration and `toMap`.
-   `ApexListImpl` methods implemented using node operations or standard patterns. `addAll` optimized with transient logic. `operator+` reverted to iterate/rebuild. Shows good performance for single operations.
-   Efficient iterators implemented for `ApexMapImpl` (`_ChampTrieIterator`) and `ApexListImpl` (`_RrbTreeIterator`).
-   Unit tests added and improved for `ApexMap` and `ApexList` core methods, iterators, equality, hash codes, and edge cases.
-   Benchmark suite created (`benchmark/`) comparing `ApexList`/`ApexMap` against native and FIC collections. Conversion benchmarks added. Results gathered, highlighting `ApexMap.fromMap` issue and `ApexList` optimization needs.

## What's Left to Build (High-Level)

-   **Phase 1:** Research & Benchmarking **(DONE)**
-   **Phase 2:** Core Design & API Definition **(DONE)**
-   **Phase 3:** Implementation & Unit Testing **(DONE - Known Issue Deferred)**
-   **Phase 4:** Performance Optimization & Benchmarking **(IN PROGRESS)**
-   **Phase 5:** Documentation & Examples (GitHub Pages, `dart doc`).
-   **Phase 6:** CI/CD & Publishing (`pub.dev`).

## Known Issues / Blockers

-   **CRITICAL:** `ApexMap.fromMap` performance is extremely poor.
-   `ApexList` conversion performance (`toList`, `fromIterable`) is slow compared to FIC.
-   `ApexList` iteration performance (`_RrbTreeIterator`) is slower than native List and FIC IList.
-   `ApexList` `sublist`, `concat(+)`, and `removeWhere` performance needs improvement.
-   RRB-Tree rebalancing/merging logic in `RrbInternalNode._rebalanceOrMerge` is incomplete for the "Cannot steal" edge case. **(Lower Priority)**

## Next Milestones (Phase 4 Continuation)

1.  **FIX `ApexMap.fromMap` Performance:** Investigate and fix the bottleneck. **(Highest Priority)**
2.  **Optimize `ApexList` Conversions:** Improve `toList` and `fromIterable`.
3.  **Optimize `ApexList` Bulk/Range Operations:** Improve `sublist`, `operator+`, `removeWhere`.
4.  **(Lower Priority) Refine RRB-Tree `_rebalanceOrMerge`:** Address the "Cannot steal" edge case.
5.  **Re-run Benchmarks:** After fixes and optimizations.
6.  **Begin Documentation:** Start basic API docs.