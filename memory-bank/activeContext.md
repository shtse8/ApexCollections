<!-- Version: 1.16 | Last Updated: 2025-04-05 | Updated By: Cline -->
# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-05 ~07:38 UTC+1)

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
    -   **Performance Status (Updated 2025-04-05 ~07:38 UTC+1 - After latest benchmark run):**
        -   **ApexMap (CHAMP - Size: 10k):**
            -   `add`: ~4.18 us (FIC: ~0.19 us)
            -   `addAll`: ~32.89 us (FIC: ~11235 us)
            -   `lookup[]`: ~0.22 us (FIC: ~0.07 us)
            -   `remove`: ~3.79 us (FIC: ~6888 us)
            -   `update`: ~8.49 us (FIC: ~7193 us)
            -   `iterateEntries`: ~3475.83 us (**~2.93x slower** than FIC ~1186.95 us)
            -   `toMap`: ~9148.89 us (~1.21x slower than FIC ~7573.21 us)
            -   `fromMap`: ~8977.48 us (~4.36x slower than FIC ~2060.06 us)
        -   **ApexList (RRB - Size: 10k):**
            -   `add`: ~22.11 us (FIC: ~1608.56 us)
            -   `addAll`: ~28.72 us (FIC: ~1.41 us)
            -   `lookup[]`: ~0.17 us (FIC: ~0.04 us)
            -   `removeAt`: ~18.83 us (FIC: ~596.07 us)
            -   `removeWhere`: ~2830.72 us (FIC: ~1445.01 us)
            -   `iterateSum`: ~303.41 us (FIC: ~285.57 us)
            -   `sublist`: ~5.30 us (FIC: ~895.72 us)
            -   `concat(+)`: ~7.02 us (FIC: ~0.70 us)
            -   `toList`: ~709.56 us (FIC: ~517.51 us)
            -   `fromIterable`: ~2638.88 us (FIC: ~606.59 us)

## Current Focus

-   **ApexList:** Core logic stable. `rrb_node.dart` split. Performance generally strong in structural modifications, needs review for iteration/conversion.
-   **ApexMap:** CHAMP implementation abandoned due to performance issues (especially iteration). `champ_*.dart` files remain but are effectively deprecated. `ApexMapImpl` splitting reverted.
-   **Testing:** Test files split. All tests pass.
-   **Benchmarking:** Latest benchmarks run, confirming CHAMP issues and providing current `ApexList` numbers.
-   **Documentation:** Updated Dartdocs for `ApexList` and `ApexMap` (CHAMP version).
-   **Code Structure:** Addressed LoC limit for node files and test files. Deferred for `apex_map.dart` and `apex_list.dart`.

## Next Immediate Steps

1.  ... (Previous steps DONE) ...
23. **(DONE)** Update Memory Bank: Record node file splitting.
24. **(DONE)** Commit Changes: Commit node file splitting changes.
25. **(DONE)** Run Benchmarks.
26. **Update Memory Bank:** Record latest benchmark results. (This step)
27. **Commit Changes:** Commit Memory Bank updates.
28. **Phase 4.5:** Begin HAMT research/design, focusing on efficient iterator.

## Open Questions / Decisions

-   Need for transient/mutable builders? (Decision remains: Low priority for Map, explore for List later)
-   Further `ApexMap` CHAMP optimization? **(Decision: Re-abandoned)**
-   How to best approach HAMT research and implementation for `ApexMap`? (Focus on iterator design avoiding temporary objects)
-   Revisit splitting `apex_map.dart` (613 LoC) and `apex_list.dart` (1008 LoC) later? (Decision: Deferred)