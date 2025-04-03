# Baseline Benchmark Results (Phase 1)

Timestamp: 2025-04-03 ~02:50 UTC+1
Dart SDK: (Assumed based on pubspec.yaml, needs confirmation if specific version matters)
Machine: (User's machine, details not captured)

## List Benchmarks (Size: 10,000)

| Operation                     | Native List (mutable) | IList (FIC)           | Unit | Notes                       |
| :---------------------------- | :-------------------- | :-------------------- | :--- | :-------------------------- |
| `add` (single element)        | ~0.13                 | ~1601.61              | us   | FIC involves tree updates   |
| `lookup[]` (middle index)     | ~0.01                 | ~0.04                 | us   | Both very fast              |
| `removeAt` (middle index)     | ~2342.86              | ~692.53               | us   | Native involves O(N) copy   |
| `iterateSum` (full traversal) | ~27.56                | ~276.40               | us   | Native iteration is faster  |

*Note: Native `removeAt` benchmark measures `List.of()` copy + `removeAt`.*

## Map Benchmarks (Size: 10,000)

| Operation                     | Native Map (mutable) | IMap (FIC)            | Unit | Notes                       |
| :---------------------------- | :------------------- | :-------------------- | :--- | :-------------------------- |
| `add[]` (new key)             | ~0.08                | ~0.16                 | us   | Both fast, FIC slightly more|
| `lookup[]` (existing key)     | ~0.03                | ~0.06                 | us   | Both very fast              |
| `remove` (existing key)       | ~1646.24             | ~6587.02              | us   | Native involves copy        |
| `iterateEntries` (full)       | ~518.19              | ~1252.54              | us   | Native iteration is faster  |

*Note: Native `remove` benchmark measures `Map.of()` copy + `remove`.*

## Initial Observations

-   **Lookups:** Both native and FIC are extremely fast for lookups (List `[]`, Map `[]`).
-   **Native Adds:** Native mutable adds are very fast (amortized O(1) for List, O(1) for Map).
-   **FIC Adds:** FIC `add` operations are significantly slower than native mutable adds due to the overhead of creating new persistent structures. `IMap.add` is much faster than `IList.add` for this size.
-   **Removals:** FIC `IList.removeAt` is faster than the benchmarked native `List.removeAt` (which includes a full copy). FIC `IMap.remove` is significantly slower than the benchmarked native `Map.remove` (which includes a full copy). *Further investigation needed for fair comparison.*
-   **Iteration:** Native collection iteration is significantly faster than FIC iteration for this size.

These results provide a quantitative baseline for evaluating `ApexCollections` performance goals.