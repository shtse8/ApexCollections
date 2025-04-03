# Phase 1 Plan: Research & Benchmarking

## Objective

To research candidate persistent data structures for `ApexList` and `ApexMap`, establish baseline performance metrics for native Dart collections and `fast_immutable_collections`, and define the scope for initial implementation based on research findings.

## 1. Data Structure Research

Based on the goal of using advanced, high-performance structures:

-   **`ApexList` Candidate:** **RRB-Trees (Relaxed Radix Balanced Trees)**
    -   *Rationale:* Widely regarded as a highly efficient persistent vector implementation, offering good performance across various operations (append, update, lookup, slicing). Aligns with "advanced technology".
    -   *Research Tasks:* Study existing implementations (Scala, Clojure variations), understand performance characteristics, memory layout, and implementation complexity in Dart. Investigate suitability for `const` empty instances.
-   **`ApexMap` Candidate:** **CHAMP (Compressed Hash-Array Mapped Prefix) Tries**
    -   *Rationale:* An evolution of HAMT (used by `fast_immutable_collections`), potentially offering improved performance, especially for iteration and memory usage. Aligns with "advanced technology".
    -   *Research Tasks:* Study CHAMP papers and implementations, compare theoretical performance with HAMT, understand node structures, collision handling, and implementation complexity in Dart. Investigate suitability for `const` empty instances.

## 2. Benchmark Definition

Expand upon the existing benchmark files (`list_benchmarks.dart`, `map_benchmarks.dart`).

-   **Comparison Targets:**
    -   Native Dart `List` (mutable)
    -   Native Dart `Map` (mutable)
    -   `fast_immutable_collections`: `IList`, `IMap`
    -   *(Future)* `ApexList`, `ApexMap` (once implemented)
-   **Benchmark Operations:**
    -   **List:**
        -   `add` (single element append)
        -   `addAll` (appending multiple elements)
        -   `removeAt` (removal by index - typically middle)
        -   `removeWhere` (removal by predicate)
        -   `[]` (lookup by index - typically middle)
        -   Iteration (full traversal, e.g., summing elements)
        -   `sublist` (slicing - creating a sub-list)
        -   Concatenation (`+` operator or equivalent)
    -   **Map:**
        -   `add`/`[]=` (insert new key / update existing key)
        -   `addAll` (merging maps)
        -   `remove` (by key)
        -   `[]` (lookup by key)
        -   Iteration (entries, keys, values)
        -   `putIfAbsent`
        -   `update` (update value for existing key)
-   **Collection Sizes:**
    -   `10` (Small)
    -   `100` (Small-Medium)
    -   `1,000` (Medium)
    -   `10,000` (Medium-Large)
    -   `100,000` (Large)
    -   *(Optional)* `1,000,000` (Very Large - if performance scaling is a key focus)
-   **Data Patterns:**
    -   Integers: Sequential (0 to N-1), Random (within `0` to `N*2` range).
    -   Strings: Sequential unique (`'value_0'`, `'value_1'`, ...), Random unique strings.
    -   *(Map Specific)* Consider keys with potential hash collisions later.

## 3. Baseline Benchmark Execution

-   Run the existing `list_benchmarks.dart` and `map_benchmarks.dart` to establish baseline performance numbers for native Dart and `fast_immutable_collections` across the defined sizes.
-   Document these baseline results for future comparison.

## 4. Dart Compatibility Considerations (Inform Research)

-   **`const` Empty Collections:** Research must determine if RRB-Trees and CHAMP Tries can be implemented in Dart such that `const ApexList()` and `const ApexMap()` are feasible and efficient.
-   **Seamless Integration:** Investigate how easily iterators (`Iterable`) can be exposed efficiently from the chosen structures to allow passing `ApexList`/`ApexMap` instances to APIs expecting standard `Iterable`s without explicit, costly conversions like `toList()`/`toMap()`.

## Timeline & Deliverables

-   **Timeline:** Phase 1 duration TBD (depends on research depth).
-   **Deliverables:**
    -   This document (`phase1-plan.md`).
    -   Research summaries for RRB-Trees and CHAMP Tries (feasibility, complexity, performance estimates in Dart context).
    -   Documented baseline benchmark results.
    -   Go/No-Go decision on pursuing RRB-Trees and CHAMP Tries for initial implementation.