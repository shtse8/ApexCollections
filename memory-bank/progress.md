# Progress: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~21:39 UTC+1)

**Phase 1: Research & Benchmarking COMPLETE.** Foundational research conducted, data structures selected (RRB-Trees, CHAMP Tries), baseline benchmarks established.
**Phase 2: Core Design & API Definition COMPLETE.** Public APIs for `ApexList` and `ApexMap` defined. Core node structure files outlined. Basic implementation classes created. `toMap` added to `ApexMap`.
**Phase 3: Implementation & Unit Testing COMPLETE** (Excluding deferred `removeAt` debugging). Core logic for `ApexListImpl` and `ApexMapImpl` implemented and unit tested. Transient logic refined. `toMap` implemented in `ApexMapImpl`.
**Phase 4: Performance Optimization & Benchmarking IN PROGRESS.** Benchmarks updated. `ApexMap.fromMap` remains critical issue (multiple attempts failed). `ApexList.concat` and `ApexList.sublist` optimized. Other `ApexList` ops still need work.

## What Works

-   Project directory structure created and Git repository initialized.
-   Core Memory Bank files established and updated.
-   Basic Dart package structure confirmed (`pubspec.yaml`, etc.).
-   Public API definitions for `ApexList` (`lib/src/list/apex_list_api.dart`) and `ApexMap` (`lib/src/map/apex_map_api.dart`).
-   Node structures implemented for RRB-Trees (`lib/src/list/rrb_node.dart`) and CHAMP Tries (`lib/src/map/champ_node.dart`), including transient mutation logic.
-   `ApexMapImpl` methods implemented, using transient operations for bulk methods. Shows strong performance for modifications/iteration and `toMap`. `fromMap` reverted to iterative add due to failed bulk load attempts.
-   `ApexListImpl` methods implemented. `addAll` uses transient logic. `operator+` uses efficient O(log N) concatenation. `removeWhere` reverted to immutable filter. `sublist` uses efficient O(log N) tree slicing. `toList` reverted to recursive helper.
-   Efficient iterators implemented for `ApexMapImpl` (`_ChampTrieIterator`) and `ApexListImpl` (`_RrbTreeIterator`).
-   Unit tests added and improved for `ApexMap` and `ApexList` core methods, iterators, equality, hash codes, and edge cases.
-   Benchmark suite created (`benchmark/`) comparing `ApexList`/`ApexMap` against native and FIC collections. Conversion benchmarks added. Latest results gathered.

## What's Left to Build (High-Level)

-   **Phase 1:** Research & Benchmarking **(DONE)**
-   **Phase 2:** Core Design & API Definition **(DONE)**
-   **Phase 3:** Implementation & Unit Testing **(DONE - Known Issue Deferred)**
-   **Phase 4:** Performance Optimization & Benchmarking **(IN PROGRESS)**
-   **Phase 5:** Documentation & Examples (GitHub Pages, `dart doc`).
-   **Phase 6:** CI/CD & Publishing (`pub.dev`).

## Known Issues / Blockers

-   **CRITICAL:** `ApexMap.fromMap` performance is extremely poor. Bulk loading attempts failed. Reverted to iterative add.
-   `ApexList.sublist` performance is now **excellent** (O(log N) tree slicing). **(FIXED)**
-   `ApexList.fromIterable` performance (`~1760 us`) is slow compared to FIC (`~650 us`). Bottom-up transient build is better than iterative add, but needs further optimization.
-   `ApexList.toList` performance (`~880 us`) using recursive helper is slower than FIC (`~620 us`). Iterator approach was slower.
-   `ApexMap` single `add`/`lookup` performance is slower than competitors.
-   RRB-Tree rebalancing/merging logic in `RrbInternalNode._rebalanceOrMerge` now handles the "Cannot steal" edge case via merge-split (immutable path only). Transient path still needs implementation. **(Partially Addressed - Lower Priority)**

## Next Milestones (Phase 4 Continuation)

1.  **FIX `ApexMap.fromMap` Performance:** Dedicated investigation/debugging of bulk loading. **(Highest Priority)**
2.  **Optimize `ApexList.sublist`:** **DONE.**
3.  **Optimize `ApexList.fromIterable`:** Reverted iterative transient add. Bottom-up transient build needs further optimization.
4.  **Optimize `ApexList.toList`:** Recursive helper is current best, but further optimization needed.
5.  **(Lower Priority) Refine RRB-Tree `_rebalanceOrMerge`:** **DONE (Immutable Path).** Transient path still needs implementation.
6.  **(Lower Priority) Investigate `ApexMap` `add`/`lookup`:** Explore micro-optimizations.
7.  **Begin Documentation:** **IN PROGRESS.** Updated `ApexList` and `ApexMap` API docs (complexity notes, known issues).