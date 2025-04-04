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

*   Core implementations for `ApexList` and `ApexMap` are functionally complete.
*   Extensive unit tests are in place. **All `ApexList` and `ApexMap` tests are passing.**
*   Core `ApexList` rebalancing bugs (immutable and transient paths) have been **fixed**.
*   `ApexList.addAll` performance significantly improved via concatenation strategy.
*   `ApexList.fromIterable` strategy changed to recursive concatenation (slower build, faster lookup/sublist).
*   `ApexMap` benchmarked; transient optimization attempt in `mergeDataEntries` showed no significant gain.
*   Ongoing work includes:
    *   Investigating performance bottlenecks, particularly for `ApexList.lookup[]` (though improved) and `ApexMap` single-element operations, iteration, `toMap`, and `fromMap`.
    *   Improving documentation.

## Performance (Latest Benchmark Results)

**Important Note:** These benchmarks were run on **2025-04-04 ~11:47 UTC+1** with Dart SDK [Version, if known] on the development machine after the latest `ApexList` optimizations/strategy changes. Results may vary on different machines or SDK versions. Further optimizations are planned.

**List Benchmarks (Size: 10,000)**

| Operation                     | Native List (mutable) | IList (FIC) | ApexList    | Unit | Notes                                     |
| :---------------------------- | :-------------------- | :---------- | :---------- | :--- | :---------------------------------------- |
| `add` (single element)        | 0.11                  | 1596.07     | 27.15       | µs   | ApexList much faster than FIC             |
| `addAll`                      | 11529.48              | 1.65        | 31.03       | µs   | **ApexList significantly improved**       |
| `lookup[]` (middle index)     | 0.01                  | 0.04        | 0.15        | µs   | **ApexList faster than FIC!**             |
| `removeAt` (middle index)     | 2266.64¹              | 658.57      | 18.97       | µs   | **ApexList significantly faster**         |
| `removeWhere`                 | 6375.17               | 1828.71     | 2743.24     | µs   | ApexList competitive                      |
| `iterateSum` (full traversal) | 32.34                 | 322.17      | 263.36      | µs   | ApexList competitive                      |
| `sublist`                     | 1134.22               | 1060.76     | 5.86        | µs   | **ApexList significantly faster!**        |
| `concat(+)`                   | 3222.16               | 0.80        | 7.22        | µs   | ApexList very fast (FIC exceptionally so) |
| `toList`                      | -                     | 596.87      | 727.39      | µs   | ApexList competitive                      |
| `fromIterable`                | -                     | 761.88      | 2960.96     | µs   | ApexList slower (trade-off for lookup)    |

*Footnotes:*
¹ Native mutable operations benchmarked include `List.of()` copy for immutability comparison where applicable.

**Map Benchmarks (Size: 10,000)**

| Operation                 | Native Map (mutable) | IMap (FIC) | ApexMap     | Unit | Notes                                     |
| :------------------------ | :------------------- | :--------- | :---------- | :--- | :---------------------------------------- |
| `add[]` (new key)         | 0.08                 | 0.19       | 4.13        | µs   | ApexMap slower, needs opt.                |
| `addAll`                  | 1760.46              | 10058.57   | 31.64       | µs   | **ApexMap significantly faster**          |
| `lookup[]` (existing key) | 0.03                 | 0.06       | 0.25        | µs   | ApexMap slower, needs opt.                |
| `remove` (existing key)   | 1670.83¹             | 6503.44    | 3.83        | µs   | **ApexMap significantly faster**          |
| `putIfAbsent`             | 1699.35¹             | 9549.14    | 8.99²       | µs   | ApexMap combines update, faster than FIC |
| `update`                  | 1693.06¹             | 6170.69    | 8.99²       | µs   | ApexMap combines update, faster than FIC |
| `iterateEntries` (full)   | 502.43               | 1122.10    | 2783.61     | µs   | ApexMap slower, needs opt.                |
| `toMap`                   | -                    | 6002.34    | 8591.55     | µs   | ApexMap slower, needs opt.                |
| `fromMap`                 | -                    | 1780.96    | 7865.07     | µs   | ApexMap slower, needs opt.                |

*Footnotes:*
¹ Native mutable operations benchmarked include `Map.of()` copy for immutability comparison where applicable (`remove`, `putIfAbsent`, `update`).
² `ApexMap.update` benchmark covers both update and putIfAbsent logic.

*(These results reflect the current state. Further optimizations and fixes may change these numbers. See the `benchmark/` directory for the source code.)*
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
