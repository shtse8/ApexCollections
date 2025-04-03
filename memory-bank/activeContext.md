# Active Context: ApexCollections

## Current Status (Timestamp: 2025-04-03 ~02:47 UTC+1)

-   Project initialized, Memory Bank established, basic Dart package structure confirmed.
-   Initial benchmark files (`list_benchmarks.dart`, `map_benchmarks.dart`) cleaned up and committed/pushed.
-   Ready to define the detailed plan for Phase 1.

## Current Focus

-   **Planning Phase 1: Research & Benchmarking**

## Next Immediate Steps

1.  **Define Phase 1 Plan:** Detail the specific research tasks, data structures, benchmark operations, collection sizes, and data patterns for Phase 1. Document this plan (potentially in a new `phase1-plan.md` or directly within this file/progress.md).
2.  **Begin Research:** Start investigating the chosen candidate data structures (e.g., RRB-Trees, CHAMP Tries).
3.  **Implement Baseline Benchmarks:** Ensure the existing benchmark files can be run and produce baseline results for native Dart and `fast_immutable_collections`.

## Phase 1 Planning Points (To Be Detailed)

-   **Data Structures:**
    -   List: Confirm focus on RRB-Trees or alternatives?
    -   Map: Confirm focus on CHAMP Tries or alternatives (e.g., HAMT)?
-   **Benchmark Operations:**
    -   List: `add`, `addAll`, `removeAt`, `removeWhere`, `[]` (lookup), iteration, `sublist` (slicing), concatenation (`+`).
    -   Map: `add`/`[]=` (insert/update), `addAll`, `remove`, `[]` (lookup), iteration (entries, keys, values), `putIfAbsent`, `update`.
-   **Collection Sizes:** Define specific sizes (e.g., 10, 1,000, 100,000, 1,000,000 elements).
-   **Data Patterns:** Define patterns (e.g., sequential integers, random integers, strings, objects with varying hash distributions).
-   **Comparison Targets:** Native Dart collections, `fast_immutable_collections`.
-   **Documentation:** Decide where to document the detailed Phase 1 plan.