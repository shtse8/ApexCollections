# Progress: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~06:36 UTC+1)

**Phase 1: Research & Benchmarking COMPLETE.** Foundational research conducted, data structures selected (RRB-Trees, CHAMP Tries), baseline benchmarks established.
**Phase 2: Core Design & API Definition COMPLETE.** Public APIs for `ApexList` and `ApexMap` defined. Core node structure files outlined. Basic implementation classes created. `toMap` added to `ApexMap`.
**Phase 3: Implementation & Unit Testing COMPLETE** (Excluding deferred `removeAt` debugging). Core logic for `ApexListImpl` and `ApexMapImpl` implemented and unit tested. Transient logic refined. `toMap` implemented in `ApexMapImpl`.
**Phase 4: Refactoring & Debugging IN PROGRESS.** File writing issues resolved. Map test failures fixed. `ApexMap.fromMap` performance addressed. `ApexList.toList` refactored. `ApexList` rebalancing bug remains.
**Phase 4: Performance Optimization & Benchmarking IN PROGRESS.** `ApexMap.fromMap` optimized. `ApexList.toList` refactored. `ApexList.fromIterable` optimization attempted (needs benchmarking).

## What Works

-   Project directory structure created and Git repository initialized.
-   Core Memory Bank files established and updated.
-   Basic Dart package structure confirmed (`pubspec.yaml`, etc.).
-   Public API definitions for `ApexList` (`lib/src/list/apex_list_api.dart`) and `ApexMap` (`lib/src/map/apex_map_api.dart`).
-   Node structures implemented for RRB-Trees (`lib/src/list/rrb_node.dart`) and CHAMP Tries (`lib/src/map/champ_node.dart`), including transient mutation logic. **(Refactored)**
-   `ApexMapImpl` methods implemented, using transient operations for bulk methods. `fromMap` uses efficient O(N) recursive bulk loading. Shows strong performance for modifications/iteration and `toMap`.
-   `ApexListImpl` methods implemented. `addAll` uses transient logic. `operator+` uses efficient O(log N) concatenation. `removeWhere` reverted to immutable filter. `sublist` uses efficient O(log N) tree slicing. `toList` refactored to use iterator. **(Refactored - utils extracted)**
-   Efficient iterators implemented for `ApexMapImpl` (`lib/src/map/champ_iterator.dart`) and `ApexListImpl` (`_RrbTreeIterator`). **(Map iterator extracted)**
-   Unit tests added and improved for `ApexMap` and `ApexList` core methods, iterators, equality, hash codes, and edge cases. `ApexMap` tests pass. `ApexList` tests fail due to known `removeAt` issue.
-   Benchmark suite created (`benchmark/`) comparing `ApexList`/`ApexMap` against native and FIC collections. Conversion benchmarks added. Latest results gathered.

## What's Left to Build (High-Level)

-   **Phase 1:** Research & Benchmarking **(DONE)**
-   **Phase 2:** Core Design & API Definition **(DONE)**
-   **Phase 3:** Implementation & Unit Testing **(DONE - Known Issue Deferred)**
-   **Phase 4:** Refactoring & Debugging **(IN PROGRESS - List `removeAt` bug)**
-   **Phase 4:** Performance Optimization & Benchmarking **(IN PROGRESS - Benchmarking)**
-   **Phase 5:** Documentation & Examples (GitHub Pages, `dart doc`).
-   **Phase 6:** CI/CD & Publishing (`pub.dev`).

## Known Issues / Blockers

-   **(Resolved)** File writing tool issues.
-   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error).
-   **(Known Issue)** List Test Runtime Error: `Bad state: Cannot merge-split nodes of different types or heights: RrbLeafNode<int> and RrbInternalNode<int>` in `RrbInternalNode._rebalanceOrMerge`. Requires significant refactor of rebalancing logic.
-   **(Resolved)** `ApexMap.fromMap` performance issue addressed with O(N) bulk loading.
-   `ApexList.fromIterable` performance (`~1760 us`) optimization attempted by modifying node constructors to avoid `sublist` (needs benchmarking).
-   `ApexList.toList` performance (`~880 us`) potentially improved by using iterator (needs benchmarking).
-   `ApexMap` single `add`/`lookup` performance is acceptable but slower than competitors (lower priority).
-   RRB-Tree rebalancing/merging logic in `RrbInternalNode._rebalanceOrMerge` (immutable path) is flawed and requires redesign. Transient path remains unimplemented.

## Next Milestones

1.  **(Lower Priority / Blocked)** **FIX `_rebalanceOrMerge` Error:** Address the `Bad state` error in `rrb_node.dart`. (Requires significant refactor).
2.  **(Done - Needs Benchmarking)** **Optimize `ApexList.fromIterable`:** Implemented node constructor changes to avoid `sublist`.
3.  **(Lower Priority)** **Benchmark:** Re-run benchmarks for `ApexMap.fromMap` and `ApexList.toList`.
4.  **(Lower Priority)** **Investigate `ApexMap` `add`/`lookup`:** Explore potential micro-optimizations.
5.  **Continue Documentation:** Update API docs and Memory Bank based on recent changes.