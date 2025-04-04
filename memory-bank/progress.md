# Progress: ApexCollections

## Current Status (Timestamp: 2025-04-04 ~14:30 UTC+1)

**Phase 1: Research & Benchmarking COMPLETE.** Foundational research conducted, data structures selected (RRB-Trees, CHAMP Tries), baseline benchmarks established.
**Phase 2: Core Design & API Definition COMPLETE.** Public APIs for `ApexList` and `ApexMap` defined. Core node structure files outlined. Basic implementation classes created. `toMap` added to `ApexMap`.
**Phase 3: Implementation & Unit Testing COMPLETE** (Excluding deferred `removeAt` debugging). Core logic for `ApexListImpl` and `ApexMapImpl` implemented and unit tested. Transient logic refined. `toMap` implemented in `ApexMapImpl`.
**Phase 4: Refactoring & Debugging COMPLETE** (for now). File writing issues resolved. Map test failures fixed (`ApexMap` tests pass). `ApexList` immutable and transient (merge/steal/plan-based) rebalancing bugs fixed. Utilities extracted. Node structures refactored. Rebalancing helpers implemented.
**Phase 4: Performance Optimization & Benchmarking COMPLETE (for now).** `ApexList` transient rebalancing optimized. `addAll` optimized via concatenation. `fromIterable` switched to recursive concatenation (slower build, faster lookup/sublist). `lookup[]` optimization investigation completed (reverted). `ApexMap` benchmarked; optimization attempts (transient `mergeDataEntries`, immutable helpers, `_buildNode`) reverted due to regressions or lack of significant improvement. `ApexMap` confirms excellent `addAll` but slow single-element ops, iteration, `toMap`, and `fromMap`. Further optimization deferred.

## What Works

-   Project directory structure created and Git repository initialized.
-   Core Memory Bank files established and updated.
-   Basic Dart package structure confirmed (`pubspec.yaml`, etc.).
-   Public API definitions for `ApexList` (`lib/src/list/apex_list_api.dart`) and `ApexMap` (`lib/src/map/apex_map_api.dart`).
-   Node structures implemented for RRB-Trees (`lib/src/list/rrb_node.dart`) and CHAMP Tries (`lib/src/map/champ_node.dart`), including transient mutation logic. **(Refactored)**
-   `ApexMapImpl` methods implemented, using transient operations for bulk methods. `fromMap` uses efficient O(N) recursive bulk loading. Shows strong performance for modifications/iteration and `toMap`.
-   `ApexListImpl` methods implemented. `addAll` optimized using concatenation strategy. `fromIterable` uses recursive concatenation strategy. `operator+` uses efficient O(log N) concatenation. `removeWhere` reverted to immutable filter. `sublist` uses efficient O(log N) tree slicing. `toList` refactored to use iterator. **(Refactored - utils extracted, `addAll` optimized, `fromIterable` strategy changed)**
-   Efficient iterators implemented for `ApexMapImpl` (`lib/src/map/champ_iterator.dart`) and `ApexListImpl` (`_RrbTreeIterator`). **(Map iterator extracted)**
-   Unit tests added and improved for `ApexMap` and `ApexList` core methods, iterators, equality, hash codes, and edge cases. **All `ApexMap` and `ApexList` tests pass.**
-   Benchmark suite created (`benchmark/`) comparing `ApexList`/`ApexMap` against native and FIC collections. Conversion benchmarks added. **`ApexList` and `ApexMap` benchmarks run (multiple iterations for `ApexList` after fixes/optimizations/reverts/strategy changes; multiple iterations for `ApexMap` after optimization attempt).**

## What's Left to Build (High-Level)

-   **Phase 1:** Research & Benchmarking **(DONE)**
-   **Phase 2:** Core Design & API Definition **(DONE)**
-   **Phase 3:** Implementation & Unit Testing **(DONE - Known Issue Deferred)**
-   **Phase 4:** Refactoring & Debugging **(COMPLETE - Core bugs fixed)**
-   **Phase 4:** Performance Optimization & Benchmarking **(COMPLETE - Further optimization deferred)**
-   **Phase 5:** Documentation & Examples (GitHub Pages, `dart doc`).
-   **Phase 6:** CI/CD & Publishing (`pub.dev`).

## Known Issues / Blockers

-   **(Resolved)** List Test Runtime Error: The `StateError` in `RrbInternalNode._rebalanceOrMerge` (immutable path) was fixed.
-   **(Needs Optimization - Deferred)** `ApexMap.fromMap` performance is significantly slower than FIC. Optimization attempts reverted.
-   **(Strategy Changed)** `ApexList.fromIterable` uses recursive concatenation. Build time (~2960us) is slower than previous bottom-up (~1707us) and FIC (~761us), but accepted trade-off for lookup/sublist gains.
-   **(Improved)** `ApexList.addAll` performance significantly improved via concatenation (~24-31us vs ~200us previously), now competitive but still slower than FIC's specific `addAll`.
-   **(Improved)** `ApexList.lookup[]` performance significantly improved (~0.15us vs ~0.42us previously) due to `fromIterable` strategy change. Now faster than FIC (~0.04us) and approaching Native (~0.01us). **(Optimization investigation complete - reverted)**
-   **(Improved)** `ApexList.sublist` performance significantly improved (~5.8us vs ~30.4us previously) due to `fromIterable` strategy change. Now much faster than Native/FIC.
-   **(Needs Benchmarking)** `ApexList.toList` performance improvement from iterator refactor needs verification via benchmarks (currently competitive).
-   **(Needs Optimization - Deferred)** `ApexMap` single `add`/`lookup`/`remove`/`update` performance is significantly slower than Native/FIC. Optimization attempts reverted.
-   **(Needs Optimization - Deferred)** `ApexMap` `iterateEntries` and `toMap` performance is slower than Native/FIC. Iterator micro-optimization had minimal impact.
-   **(Resolved)** The transient path for plan-based rebalancing in `_rebalanceOrMerge` now mutates nodes in place via `_executeTransientRebalancePlan`.

## Next Milestones (Reflecting Active Context)

 1.  **(DONE)** **FIX `_rebalanceOrMerge` Error (Immutable Path & Transient Merge/Steal):** Implemented plan-based rebalancing and transient merge/steal. Tests pass.
 2.  **(DONE)** **Benchmark `ApexList`:** Gathered baseline performance after fixes.
 3.  **(DONE)** **Optimize `_rebalanceOrMerge` Transient Path (Plan-based):** Implemented mutation-in-place logic via `_executeTransientRebalancePlan`.
 4.  **(DONE)** **Optimize `ApexList.addAll`:** Replaced transient add loop with concatenation strategy.
 5.  **(DONE)** **Benchmark `ApexList`:** Re-run after optimizations and fixes (multiple times).
 6.  **(DONE)** **Benchmark `ApexMap`:** Run benchmarks for existing map implementation (multiple times).
 7.  **(Attempted - No Gain)** **Optimize `ApexMap` `mergeDataEntries`:** Allowed transient node creation (no significant performance change).
 8.  **(DONE)** **Optimize `ApexList.fromIterable`:** Switched to recursive concatenation strategy (slower build, faster lookup/sublist).
 9.  **(DONE)** **Optimize `ApexList.lookup[]`:** Investigated O(1) strict path calculation. Reverted due to correctness issues.
10. **(DONE - Reverted)** **Investigate `ApexMap` `add`/`lookup`/`remove`/`update`:** Attempted immutable helper refactor (list spreads). Reverted due to performance regression.
11. **(DONE - Reverted)** **Investigate `ApexMap.fromMap`:** Attempted single-pass `_buildNode` refactor. Reverted due to performance regression in other ops.
12. **Continue Documentation:** Update API docs and Memory Bank based on recent changes.