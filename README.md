# ApexCollections

[![Pub Version](https://img.shields.io/badge/pub-coming_soon-blue)](https://pub.dev/) <!-- Placeholder -->
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/<your_username>/apex_collections/actions) <!-- Placeholder -->
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) <!-- Placeholder -->

High-performance, immutable collections for Dart, designed to be intuitive and integrate seamlessly with the Dart ecosystem.

## Core Goal

ApexCollections aims to be the premier immutable collection library for Dart, surpassing existing solutions like `fast_immutable_collections` in both performance and developer experience. It provides the safety of immutability with performance that meets or exceeds alternatives, feeling like a natural extension of the Dart language.

## Key Features

*   **Performance-Optimized:** Built using efficient persistent data structures (CHAMP Tries for Maps, RRB-Trees for Lists) for optimal speed across common operations.
*   **Immutable Guarantees:** All operations return new collection instances, ensuring predictable state management.
*   **Dart-Idiomatic API:** Designed to feel familiar and integrate smoothly with native Dart collections (`List`, `Map`, `Iterable`).
*   **Type Safe:** Leverages Dart's strong type system.
*   **Current Collections:**
    *   `ApexList<E>`: An immutable list implementation.
    *   `ApexMap<K, V>`: An immutable map implementation.

## Status

This library is currently under **active development**.

*   Core implementations for `ApexList` and `ApexMap` are complete.
*   Extensive unit tests are in place (`ApexMap` tests passing).
*   Ongoing work includes:
    *   Debugging and refining the `ApexList` implementation (specifically rebalancing logic).
    *   Performance benchmarking and optimization.
    *   Improving documentation.

## Performance

**Important Note:** Comprehensive benchmarks comparing `ApexCollections` against native Dart collections and `fast_immutable_collections` (FIC) are planned once the library stabilizes. The `ApexList` implementation currently has known issues affecting some operations.

### Baseline Comparison (Native vs. FIC)

These initial benchmarks (Phase 1, Size: 10,000) provide context for performance goals:

**List Benchmarks (Native vs. FIC)**

| Operation                     | Native List (mutable) | IList (FIC) | Unit | Notes                     |
| :---------------------------- | :-------------------- | :---------- | :--- | :------------------------ |
| `add` (single element)        | ~0.13                 | ~1601.61    | µs   | FIC involves tree updates |
| `lookup[]` (middle index)     | ~0.01                 | ~0.04       | µs   | Both very fast            |
| `removeAt` (middle index)     | ~2342.86              | ~692.53     | µs   | Native involves O(N) copy |
| `iterateSum` (full traversal) | ~27.56                | ~276.40     | µs   | Native iteration faster   |
*Note: Native `removeAt` benchmark measures `List.of()` copy + `removeAt`.*

**Map Benchmarks (Native vs. FIC)**

| Operation                 | Native Map (mutable) | IMap (FIC) | Unit | Notes                     |
| :------------------------ | :------------------- | :--------- | :--- | :------------------------ |
| `add[]` (new key)         | ~0.08                | ~0.16      | µs   | Both fast, FIC slightly more |
| `lookup[]` (existing key) | ~0.03                | ~0.06      | µs   | Both very fast            |
| `remove` (existing key)   | ~1646.24             | ~6587.02   | µs   | Native involves copy      |
| `iterateEntries` (full)   | ~518.19              | ~1252.54   | µs   | Native iteration faster   |
*Note: Native `remove` benchmark measures `Map.of()` copy + `remove`.*

### ApexCollections Preliminary Findings

These observations are based on development benchmarks and are subject to change:

*   **ApexMap:**
    *   Bulk modifications (`addAll`, `remove`, `update`), iteration (`iterateEntries`), `toMap`: Observed to be **excellent**.
    *   `fromMap`: Significantly improved via O(N) bulk loading (needs re-benchmarking).
    *   Single `add`/`lookup`: Performance is **acceptable**, but potentially slower than competitors (investigation needed).
*   **ApexList:**
    *   `add`, `addAll`: Observed to be **good**.
    *   `removeAt`: Observed to be **good** (but underlying logic has known issues).
    *   `concat(+)`: Observed to be **excellent** (~6 µs).
    *   `sublist`: Observed to be **excellent** (~32 µs).
    *   `removeWhere`: Observed to be **acceptable** (~2500 µs).
    *   Iteration (`iterateSum`): Observed to be **acceptable** (~260-300 µs).
    *   `toList`: Potentially improved via iterators (~960 µs before, needs re-benchmarking).
    *   `fromIterable`: Optimization attempted (~1760 µs before, needs re-benchmarking).

*(See the `benchmark/` directory for testing code. Full, updated benchmark tables including ApexCollections will be added once the library stabilizes.)*
## Installation

This package is not yet published on `pub.dev`. Once published, add it to your `pubspec.yaml`:

```yaml
dependencies:
  apex_collections: ^latest # Replace with actual version
```

Then run `dart pub get` or `flutter pub get`.

## Basic Usage

```dart
import 'package:apex_collections/apex_collections.dart';

void main() {
  // ApexList
  var list1 = ApexList<int>.empty();
  var list2 = list1.add(1).addAll([2, 3]);
  print(list2); // Output: ApexList<int>[1, 2, 3]
  print(list2[1]); // Output: 2

  // ApexMap
  var map1 = ApexMap<String, int>.empty();
  var map2 = map1.add('a', 1).addAll({'b': 2, 'c': 3});
  print(map2); // Output: ApexMap<String, int>{a: 1, b: 2, c: 3}
  print(map2['b']); // Output: 2
}
```

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request. (Further contribution guidelines will be added later).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details (Note: LICENSE file needs to be created).
