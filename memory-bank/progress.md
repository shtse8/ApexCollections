# Progress: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~04:58 UTC+1)

**Phase 1: Research & Benchmarking COMPLETE.** Foundational research conducted, data structures selected (RRB-Trees, CHAMP Tries), baseline benchmarks established, and benchmark suite refined.
**Phase 2: Core Design & API Definition COMPLETE.** Public APIs for `ApexList` and `ApexMap` defined. Core node structure files outlined. Basic implementation classes created.

## What Works

-   Project directory structure created and Git repository initialized.
-   Core Memory Bank files established and updated through Phase 1 & start of Phase 2.
-   Basic Dart package structure confirmed (`pubspec.yaml`, etc.).
-   Baseline benchmark suite for native and FIC collections is functional.
-   Public API definitions for `ApexList` (`lib/src/list/apex_list_api.dart`) and `ApexMap` (`lib/src/map/apex_map_api.dart`).
-   Basic node structure outlines for RRB-Trees (`lib/src/list/rrb_node.dart`) and CHAMP Tries (`lib/src/map/champ_node.dart`).
-   `ApexMapImpl` `add`/`remove` methods updated to handle length correctly based on node operation results (`ChampAddResult`/`ChampRemoveResult`).
-   `ChampNode` subclasses (`add`/`remove`) updated to return result objects (`ChampAddResult`/`ChampRemoveResult`) indicating size changes.
-   `ChampInternalNode` helper methods (`_replaceDataWithNode`, `_replaceNodeWithData`) corrected with proper `bitpos` handling.
-   Local `bitCount` function defined and used in `champ_node.dart`.
-   Efficient iterators implemented for `ApexMapImpl` (`_ChampTrieIterator`) and `ApexListImpl` (`_RrbTreeIterator`).
-   Basic unit tests added for `ApexMap` core methods and iterator (`apex_map_test.dart`).
-   Partial implementation of RRB-Tree rebalancing/merging helpers (`_borrowFromLeft`, `_borrowFromRight`, `_mergeWithLeft`) in `RrbInternalNode` (leaf cases done, internal cases have TODOs).
-   Added basic unit tests for `ApexList` core methods and iterator (`apex_list_test.dart`).

## What's Left to Build (High-Level)

-   **Phase 1:** Research & Benchmarking **(DONE)**
-   **Phase 2:** Core Design & API Definition **(DONE)**
-   **Phase 3:** Implementation & Unit Testing (Core logic). **(IN PROGRESS)**
-   **Phase 4:** Performance Optimization & Benchmarking (Refinement).
-   **Phase 5:** Documentation & Examples (GitHub Pages, `dart doc`).
-   **Phase 6:** CI/CD & Publishing (`pub.dev`).

## Known Issues / Blockers

-   RRB-Tree rebalancing/merging logic in `RrbInternalNode.removeAt` needs implementation (currently placeholder).
-   `ApexListImpl` needs efficient implementations for modification methods (`insert`, `insertAll`, `removeWhere`, `sublist`, `operator+`, `indexOf`, `lastIndexOf`, etc.) and optimized `==`/`hashCode`.
-   `ApexMapImpl` needs efficient implementations for bulk operations (`fromMap`, `addAll`), `update`, `updateAll`, `removeWhere`, `mapEntries`, and optimized `==`/`hashCode`.

## Next Milestones (Phase 3 Continuation)

1.  **Implement RRB-Tree Rebalancing/Merging:** Implement the `_rebalanceOrMerge` logic in `RrbInternalNode` (`lib/src/list/rrb_node.dart`).
2.  **Implement Efficient `ApexListImpl` Methods:** Replace placeholder implementations in `ApexListImpl` with efficient node-based logic.
3.  **Complete `ApexList` Unit Tests:** Add tests for remaining methods and edge cases, especially those involving node rebalancing/merging once implemented (`apex_list_test.dart`).
4.  **Refine `ApexMapImpl` Methods:** Implement efficient bulk operations and `==`/`hashCode` for `ApexMapImpl`.