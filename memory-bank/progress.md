# Progress: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~07:07 UTC+1)

**Phase 1: Research & Benchmarking COMPLETE.** Foundational research conducted, data structures selected (RRB-Trees, CHAMP Tries), baseline benchmarks established.
**Phase 2: Core Design & API Definition COMPLETE.** Public APIs for `ApexList` and `ApexMap` defined. Core node structure files outlined. Basic implementation classes created. `toMap` added to `ApexMap`.
**Phase 3: Implementation & Unit Testing COMPLETE** (Excluding deferred `removeAt` debugging). Core logic for `ApexListImpl` and `ApexMapImpl` implemented and unit tested. Transient logic refined. `toMap` implemented in `ApexMapImpl`.
**Phase 4: Refactoring & Debugging IN PROGRESS.** File writing issues resolved. Map test failures fixed (`ApexMap` tests pass). `ApexList` rebalancing bug remains. Utilities extracted (`rrb_tree_utils.dart`, `champ_iterator.dart`). Node structures refactored.
**Phase 4: Performance Optimization & Benchmarking IN PROGRESS.** `ApexMap.fromMap` optimized (needs benchmarking). `ApexList.toList` refactored (needs benchmarking). `ApexList.fromIterable` optimization attempted (needs benchmarking).

## What Works

-   Project directory structure created and Git repository initialized.
-   Core Memory Bank files established and updated.
-   Basic Dart package structure confirmed (`pubspec.yaml`, etc.).
-   Public API definitions for `ApexList` (`lib/src/list/apex_list_api.dart`) and `ApexMap` (`lib/src/map/apex_map_api.dart`).
-   Node structures implemented for RRB-Trees (`lib/src/list/rrb_node.dart`) and CHAMP Tries (`lib/src/map/champ_node.dart`), including transient mutation logic. **(Refactored)**
-   `ApexMapImpl` methods implemented, using transient operations for bulk methods. `fromMap` uses efficient O(N) recursive bulk loading. Shows strong performance for modifications/iteration and `toMap`.
-   `ApexListImpl` methods implemented. `addAll` uses transient logic. `operator+` uses efficient O(log N) concatenation. `removeWhere` reverted to immutable filter. `sublist` uses efficient O(log N) tree slicing. `toList` refactored to use iterator. **(Refactored - utils extracted)**
-   Efficient iterators implemented for `ApexMapImpl` (`lib/src/map/champ_iterator.dart`) and `ApexListImpl` (`_RrbTreeIterator`). **(Map iterator extracted)**
-   Unit tests added and improved for `ApexMap` and `ApexList` core methods, iterators, equality, hash codes, and edge cases. **`ApexMap` tests pass.** `ApexList` tests fail due to known `removeAt` issue.
-   Benchmark suite created (`benchmark/`) comparing `ApexList`/`ApexMap` against native and FIC collections. Conversion benchmarks added. Latest results gathered (need updating for recent optimizations).

## What's Left to Build (High-Level)

-   **Phase 1:** Research & Benchmarking **(DONE)**
-   **Phase 2:** Core Design & API Definition **(DONE)**
-   **Phase 3:** Implementation & Unit Testing **(DONE - Known Issue Deferred)**
-   **Phase 4:** Refactoring & Debugging **(IN PROGRESS - List `removeAt` bug)**
-   **Phase 4:** Performance Optimization & Benchmarking **(IN PROGRESS - Benchmarking)**
-   **Phase 5:** Documentation & Examples (GitHub Pages, `dart doc`).
-   **Phase 6:** CI/CD & Publishing (`pub.dev`).

## Known Issues / Blockers

-   **(Known Issue)** List Test Runtime Error: Now throws `StateError: Cannot rebalance incompatible nodes (cannot merge/steal)...` in `RrbInternalNode._rebalanceOrMerge` (changed from `UnimplementedError` as an interim step). This occurs when incompatible nodes cannot be merged or steal elements. Requires significant refactor of rebalancing logic. **(High Priority Block)**
-   **(Needs Benchmarking)** `ApexMap.fromMap` performance optimization needs verification via benchmarks.
-   **(Needs Benchmarking)** `ApexList.fromIterable` performance optimization attempt needs verification via benchmarks.
-   **(Needs Benchmarking)** `ApexList.toList` performance improvement from iterator refactor needs verification via benchmarks.
-   `ApexMap` single `add`/`lookup` performance is acceptable but slower than competitors (lower priority).
-   RRB-Tree rebalancing/merging logic in `RrbInternalNode._rebalanceOrMerge` (immutable path) is flawed (throws `StateError` for incompatible nodes) and requires redesign. Transient path remains unimplemented. (Related to the High Priority Block).

## Next Milestones (Reflecting Active Context)

1.  **(Blocked)** **FIX `_rebalanceOrMerge` Error:** Address the `Bad state` error in `rrb_node.dart`. (Requires significant refactor).
2.  **(Lower Priority)** **Benchmark:** Re-run benchmarks for `ApexMap.fromMap`, `ApexList.toList`, and `ApexList.fromIterable`.
3.  **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`:** Explore potential micro-optimizations.
4.  **Continue Documentation:** Update API docs and Memory Bank based on recent changes.