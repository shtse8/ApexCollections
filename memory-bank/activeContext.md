<!-- Version: 1.15 | Last Updated: 2025-04-05 | Updated By: Cline -->
# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-05 ~06:45 UTC+1)

-   **Phase 1: Research & Benchmarking COMPLETE.**
-   **Phase 2: Core Design & API Definition COMPLETE.**
-   **Phase 3: Implementation & Unit Testing COMPLETE.**
-   **Phase 4: Refactoring & Debugging COMPLETE.** (Core bugs fixed, iterator reverted to correct but slow version)
    -   **Refactoring:**
        -   Extracted RRB-Tree utility functions from `ApexListImpl` into `rrb_tree_utils.dart`.
        -   Refactored `ChampInternalNode` in `champ_node.dart` to separate transient/immutable logic paths.
        -   Extracted `ChampTrieIterator` from `ApexMapImpl` into `champ_iterator.dart`.
        -   Optimized `ApexMapImpl.containsKey` by adding dedicated `ChampNode.containsKey` method.
        -   Optimized `bitCount` helper function in `champ_node.dart` using SWAR algorithm.
        -   Refactored `ApexMap._buildNode` (Attempted single-pass strategy, improved `fromMap` but regressed other ops, reverted).
        -   Fixed `ApexList.toList` performance regression by reverting to recursive helper.
        -   Attempted optimization of `RrbInternalNode.fromRange` (Reverted - worsened performance).
        -   Attempted optimization of `ChampInternalNode` immutable helpers using list spreads (Reverted - worsened single-element performance).
        -   Fixed `champ_node.dart` structural errors (missing `ChampArrayNode` definition, misplaced methods).
        -   Refactored `ChampTrieIterator` logic to fix test failures (Reverted optimization attempts).
        -   Split `apex_map_test.dart` and `apex_list_test.dart` into smaller files based on test groups to adhere to <500 LoC rule.
        -   **Split `rrb_node.dart` into `rrb_node_base.dart`, `rrb_internal_node.dart`, `rrb_leaf_node.dart`.**
        -   **Split `champ_array_node.dart` into `champ_array_node_base.dart`, `champ_array_node_impl.dart`, and extension files (`_get`, `_add`, `_remove`, `_update`, `_mutation_utils`).**
        -   **Reverted `ApexMapImpl` splitting due to extension/private access issues. Merged methods back into `apex_map.dart`.** (Note: `apex_map.dart` now exceeds 500 LoC, deferred).
    -   **Testing Issues:**
        -   **(Resolved)** File writing tools seem stable.
        -   **(Resolved)** Map Test Load Error (`ApexMapImpl.add` type error) and subsequent test failures fixed. All map tests pass after splitting.
        -   **(Resolved)** List Test Runtime Error: The `StateError: Cannot rebalance incompatible nodes...` in `RrbInternalNode._rebalanceOrMerge` has been addressed by implementing a plan-based rebalancing strategy (`_createRebalancePlan`, `_executeRebalancePlan`) for the immutable path. All list tests pass after splitting.
        -   **(Resolved)** The transient path for `_rebalanceOrMerge` (plan-based case) now uses `_executeTransientRebalancePlan` to mutate nodes in place.
        -   **(Resolved)** Persistent Dart Analyzer errors related to `ChampArrayNode` resolved by fixing `champ_node.dart` structure, clearing `.dart_tool`, and using `git stash pop`.
        -   **(Resolved)** Multiple `ApexMap` test failures resolved by refactoring `ChampTrieIterator`. **All tests now pass with the reverted (slower) iterator.**
        -   **(Resolved)** Errors related to splitting `rrb_node.dart` and `champ_array_node.dart` fixed.
    -   **Performance Status (Updated 2025-04-05 ~01:33 UTC+1 - After iterator refactoring attempt):** (No change)
        -   **ApexMap (Size: 10k):** ...
        -   **ApexList (Size: 10k):** ...

## Current Focus

-   **ApexList:** Core logic stable. `rrb_node.dart` split.
-   **ApexMap:** Fixed structural errors in `champ_node.dart`. Updated Dartdocs. `champ_array_node.dart` split. `ApexMapImpl` splitting reverted.
-   **Testing:** Test files split. All tests pass.
-   **Benchmarking:** CHAMP iterator optimizations failed. CHAMP abandoned for Map.
-   **Documentation:** Updated Dartdocs for `ApexList` and `ApexMap`.
-   **Code Structure:** Addressed LoC limit for node files and test files. Deferred for `apex_map.dart` and `apex_list.dart`.

## Next Immediate Steps

1.  ... (Previous steps DONE) ...
18. **(DONE)** Split large test files (`apex_map_test.dart`, `apex_list_test.dart`).
19. **(DONE)** Commit test file splitting changes.
20. **(DONE)** Split `rrb_node.dart`.
21. **(DONE)** Split `champ_array_node.dart`.
22. **(DONE)** Revert `ApexMapImpl` splitting.
23. **Update Memory Bank:** Record node file splitting. (This step)
24. **Commit Changes:** Commit node file splitting changes.
25. **Phase 4.5:** Reconfirm pivot and begin HAMT research/design, focusing on efficient iterator.

## Open Questions / Decisions

-   Need for transient/mutable builders? (Decision remains: Low priority for Map, explore for List later)
-   Further `ApexMap` CHAMP optimization? **(Decision: Re-abandoned)**
-   How to best approach HAMT research and implementation for `ApexMap`? (Focus on iterator design avoiding temporary objects)
-   Revisit splitting `apex_map.dart` (613 LoC) and `apex_list.dart` (1008 LoC) later? (Decision: Deferred)