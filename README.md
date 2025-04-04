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

## Performance (Preliminary Comparison)

**Important Note:** The `ApexCollections` results below are **preliminary**, based on benchmarks run during development (Phase 1 baseline for Native/FIC, later development runs for Apex). Some `ApexCollections` optimizations have occurred since, and the `ApexList` implementation has known issues affecting `removeAt`. Numbers require re-benchmarking once the library stabilizes. Qualitative terms (Good, Excellent, Acceptable) indicate observed performance levels where precise numbers are not yet finalized or available for comparison.

**List Benchmarks (Size: 10,000)**

| Operation                     | Native List (mutable) | IList (FIC) | ApexList (Preliminary) | Unit | Notes                                     |
| :---------------------------- | :-------------------- | :---------- | :--------------------- | :--- | :---------------------------------------- |
| `add` (single element)        | ~0.13                 | ~1601.61    | Good\*                 | µs   | Apex: Qualitative, needs benchmark        |
| `addAll`                      | -                     | -           | Good\*                 | -    | Apex: Qualitative, needs benchmark        |
| `lookup[]` (middle index)     | ~0.01                 | ~0.04       | Acceptable\*           | µs   | Apex: Qualitative, needs benchmark        |
| `removeAt` (middle index)     | ~2342.86¹             | ~692.53     | Good\*²                | µs   | Apex: Qualitative, known issues         |
| `iterateSum` (full traversal) | ~27.56                | ~276.40     | ~260-300\*             | µs   | Apex: Preliminary number                  |
| `concat(+)`                   | -                     | -           | ~6\*                   | µs   | Apex: Preliminary number                  |
| `sublist`                     | -                     | -           | ~32\*                  | µs   | Apex: Preliminary number                  |
| `removeWhere`                 | -                     | -           | ~2500\*                | µs   | Apex: Preliminary number                  |
| `toList`                      | -                     | -           | ~960\*³                | µs   | Apex: Before iterator change              |
| `fromIterable`                | -                     | -           | ~1760\*⁴               | µs   | Apex: Before optimization attempt         |

*Footnotes:*
\* `ApexCollections` results are preliminary and subject to change. Qualitative terms indicate observed performance.
¹ Native `removeAt` benchmark includes `List.of()` copy.
² `ApexList.removeAt` has known implementation issues affecting stability/performance.
³ `ApexList.toList` performance likely improved after refactoring (needs re-benchmarking).
⁴ `ApexList.fromIterable` performance likely improved after optimization attempt (needs re-benchmarking).

**Map Benchmarks (Size: 10,000)**

| Operation                 | Native Map (mutable) | IMap (FIC) | ApexMap (Preliminary) | Unit | Notes                                     |
| :------------------------ | :------------------- | :--------- | :-------------------- | :--- | :---------------------------------------- |
| `add[]` (new key)         | ~0.08                | ~0.16      | Acceptable\*          | µs   | Apex: Qualitative, needs benchmark        |
| `addAll`                  | -                    | -          | Excellent\*           | -    | Apex: Qualitative, needs benchmark        |
| `lookup[]` (existing key) | ~0.03                | ~0.06      | Acceptable\*          | µs   | Apex: Qualitative, needs benchmark        |
| `remove` (existing key)   | ~1646.24¹            | ~6587.02   | Excellent\*           | µs   | Apex: Qualitative, needs benchmark        |
| `update`                  | -                    | -          | Excellent\*           | -    | Apex: Qualitative, needs benchmark        |
| `iterateEntries` (full)   | ~518.19              | ~1252.54   | Excellent\*           | µs   | Apex: Qualitative, needs benchmark        |
| `toMap`                   | -                    | -          | Excellent\*           | -    | Apex: Qualitative, needs benchmark        |
| `fromMap`                 | -                    | -          | Improved (O(N))\*     | -    | Apex: Needs re-benchmarking               |

*Footnotes:*
\* `ApexCollections` results are preliminary and subject to change. Qualitative terms indicate observed performance.
¹ Native `remove` benchmark includes `Map.of()` copy.

*(See the `benchmark/` directory for testing code. Full, updated benchmark tables will replace this preliminary data once the library stabilizes.)*
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
