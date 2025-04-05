<!-- Version: 1.11 | Last Updated: 2025-04-05 | Updated By: Cline -->
# Progress: ApexCollections

## Current Status (Timestamp: 2025-04-05 ~07:38 UTC+1)

**Phase 1: Research & Benchmarking COMPLETE.** Foundational research conducted, data structures selected (RRB-Trees, CHAMP Tries), baseline benchmarks established.
**Phase 2: Core Design & API Definition COMPLETE.** Public APIs for `ApexList` and `ApexMap` defined. Core node structure files outlined. Basic implementation classes created. `toMap` added to `ApexMap`.
**Phase 3: Implementation & Unit Testing COMPLETE** (Excluding deferred `removeAt` debugging). Core logic for `ApexListImpl` and `ApexMapImpl` implemented and unit tested. Transient logic refined. `toMap` implemented in `ApexMapImpl`.
**Phase 4: Refactoring & Debugging COMPLETE.** File writing issues resolved. `ApexList` rebalancing bugs fixed. Utilities extracted. `champ_node.dart` structure fixed. Persistent analyzer errors resolved. `ChampTrieIterator` refactored to fix map test failures. **All tests now pass.**
**Phase 4: Performance Optimization & Benchmarking COMPLETE (CHAMP Attempt).** `ApexList` performance stable. `ApexMap` iteration/`toMap` performance confirmed to be significantly slower (~2.5x) than FIC with the correct iterator logic (which requires creating temporary `MapEntry` objects). Multiple attempts to optimize the iterator by avoiding temporary objects (`_BitmapPayloadRef`) failed due to introducing logic errors and were reverted. `_buildNode` optimization improved `fromMap`, but it remains much slower than FIC. **Decision: Abandoning CHAMP for `ApexMap` due to persistent iteration performance issues and optimization complexity.**
**Phase 4: Code Structure Management COMPLETE.** Split large test files (`apex_map_test.dart`, `apex_list_test.dart`) into smaller files based on test groups to adhere to the 500 LoC rule. Split node files (`rrb_node.dart`, `champ_array_node.dart`). Reverted `ApexMapImpl` splitting.
**Phase 4: Final Benchmarking COMPLETE.** Latest benchmarks run, confirming CHAMP issues and providing current `ApexList` numbers.

## What Works

-   Project directory structure created and Git repository initialized.
-   Core Memory Bank files established and updated.
-   Basic Dart package structure confirmed (`pubspec.yaml`, etc.).
-   Public API definitions for `ApexList` (`lib/src/list/apex_list_api.dart`) and `ApexMap` (`lib/src/map/apex_map_api.dart`).
-   Node structures implemented for RRB-Trees (`lib/src/list/rrb_*.dart`) and CHAMP Tries (`lib/src/map/champ_*.dart`), including transient mutation logic. **(Refactored & Fixed `champ_node.dart` structure, split node files)**
-   `ApexMapImpl` (CHAMP version) methods implemented and re-verified for accuracy. `addAll`, `remove`, `update` show strong performance vs FIC. However, `add`, `lookup`, `fromMap`, `iterateEntries`, and `toMap` are significantly slower than FIC. Iteration performance remains the primary bottleneck (**~2.93x slower** than FIC after latest benchmark run).
-   `ApexListImpl` methods implemented. `addAll` optimized using concatenation strategy. `fromIterable` uses recursive concatenation strategy. `operator+` uses efficient O(log N) concatenation. `removeWhere` reverted to immutable filter. `sublist` uses efficient O(log N) tree slicing. `toList` refactored to use iterator. **(Refactored - utils extracted, `addAll` optimized, `fromIterable` strategy changed, node files split)**
-   Iterator for `ApexMapImpl` (CHAMP version) (`lib/src/map/champ_iterator.dart`) refactored multiple times. Initial optimization attempts failed. Latest refactoring (avoid MapEntry in moveNext, change traversal order) completed, but worsened performance. Efficient iterator for `ApexListImpl` (`_RrbTreeIterator`) implemented.
-   Unit tests added and improved for `ApexMap` and `ApexList` core methods, iterators, equality, hash codes, and edge cases. **Split large test files into smaller, focused files.** All tests pass after latest iterator refactoring and test splitting.
-   Benchmark suite created (`benchmark/`). Latest benchmarks run.

## What's Left to Build (High-Level)

-   **Phase 1:** Research & Benchmarking **(DONE)**
-   **Phase 2:** Core Design & API Definition **(DONE)**
-   **Phase 3:** Implementation & Unit Testing **(DONE - Known Issue Deferred)**
-   **Phase 4:** Refactoring & Debugging **(COMPLETE - Core bugs fixed, CHAMP iterator reverted to correct but slow version, all tests pass)**
-   **Phase 4:** Performance Optimization & Benchmarking (CHAMP Attempt) **(COMPLETE - Final benchmarks run, multiple optimization/refactoring attempts failed, CHAMP re-abandoned for Map)**
-   **Phase 4:** Code Structure Management **(COMPLETE - Test files split, node files split, MapImpl splitting reverted)**
-   **Phase 4:** Final Benchmarking **(COMPLETE)**
-   **Phase 4.5:** Research & Design (HAMT for `ApexMap`). **(Confirmed Next Phase)**
-   **Phase 5:** Implementation & Unit Testing (HAMT `ApexMap`).
-   **Phase 6:** Documentation & Examples (GitHub Pages, `dart doc`).
-   **Phase 7:** CI/CD & Publishing (`pub.dev`).

## Known Issues / Blockers

-   **(Resolved)** List Test Runtime Error: The `StateError` in `RrbInternalNode._rebalanceOrMerge` was fixed.
-   **(Resolved)** `champ_node.dart` structural errors fixed.
-   **(Resolved)** Persistent Dart Analyzer errors resolved.
-   **(Resolved)** `ApexMap` test failures resolved by reverting CHAMP iterator optimizations.
-   **(Decision: Re-abandon CHAMP)** `ApexMap` (CHAMP version) performance issues (Updated 2025-04-05 ~07:38 UTC+1):
    -   `iterateEntries`: ~3475.83 us (**~2.93x slower** than FIC ~1186.95 us). Multiple optimization/refactoring attempts failed. **Primary reason for abandoning CHAMP.**
    -   `toMap`: ~9148.89 us (~1.21x slower than FIC ~7573.21 us).
    -   `add`: ~4.18 us (Slower than FIC ~0.19 us).
    -   `lookup[]`: ~0.22 us (Slower than FIC ~0.07 us).
    -   `fromMap`: ~8977.48 us (~4.36x slower than FIC ~2060.06 us).
-   **(Stable - Accepted)** `ApexList` performance remains stable and generally competitive or superior to FIC in structural modifications, but slower in iteration/conversion.

## Next Milestones (Reflecting Active Context)

 1.  ... (Previous steps DONE) ...
23. **(DONE)** Split large test files (`apex_map_test.dart`, `apex_list_test.dart`).
24. **(DONE)** Commit Changes: Commit the test file splitting changes.
25. **(DONE)** Split `rrb_node.dart`.
26. **(DONE)** Split `champ_array_node.dart`.
27. **(DONE)** Revert `ApexMapImpl` splitting.
28. **(DONE)** Update Memory Bank: Record node file splitting.
29. **(DONE)** Commit Changes: Commit node file splitting changes.
30. **(DONE)** Run Benchmarks.
31. **Update Memory Bank:** Record latest benchmark results. (This step)
32. **Commit Changes:** Commit Memory Bank updates.
33. **Phase 4.5:** Begin HAMT research/design, focusing on efficient iterator.