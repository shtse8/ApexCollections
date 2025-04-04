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
*   The core `ApexList` rebalancing bug (`StateError: Cannot rebalance incompatible nodes...`) has been **fixed**.
*   Ongoing work includes:
    *   **High Priority:** Optimizing the transient path for plan-based rebalancing in `ApexList` to improve `addAll`/`fromIterable` performance.
    *   Investigating performance bottlenecks, particularly for `ApexList.lookup[]` and `ApexMap` single-element operations.
    *   Improving documentation.

## Performance (Latest Benchmark Results)

**Important Note:** These benchmarks were run on **2025-04-04 ~11:07 UTC+1** with Dart SDK [Version, if known] on the development machine after fixing the core `ApexList` rebalancing bug. Results may vary on different machines or SDK versions. Further optimizations are planned.

**List Benchmarks (Size: 10,000)**

| Operation                     | Native List (mutable) | IList (FIC) | ApexList    | Unit | Notes                                     |
| :---------------------------- | :-------------------- | :---------- | :---------- | :--- | :---------------------------------------- |
| `add` (single element)        | 0.13                  | 1936.09     | 28.79       | µs   | ApexList much faster than FIC             |
| `addAll`                      | 11484.12              | 1.75        | 191.95      | µs   | ApexList needs transient opt.           |
| `lookup[]` (middle index)     | 0.01                  | 0.04        | 0.37        | µs   | ApexList slower, needs opt.             |
| `removeAt` (middle index)     | 2421.90¹              | 728.66      | 15.78       | µs   | **ApexList significantly faster**         |
| `removeWhere`                 | 6237.24               | 1975.20     | 2348.55     | µs   | ApexList competitive                      |
| `iterateSum` (full traversal) | 30.69                 | 306.82      | 245.08      | µs   | ApexList competitive                      |
| `sublist`                     | 1159.88               | 1101.49     | 30.13       | µs   | **ApexList significantly faster**         |
| `concat(+)`                   | 3654.30               | 0.91        | 5.68        | µs   | ApexList very fast (FIC exceptionally so) |
| `toList`                      | -                     | 693.84      | 717.38      | µs   | ApexList competitive                      |
| `fromIterable`                | -                     | 741.32      | 1794.25     | µs   | ApexList needs transient opt.           |

*Footnotes:*
¹ Native mutable operations benchmarked include `List.of()` copy for immutability comparison where applicable.

**Map Benchmarks (Size: 10,000)**

| Operation                 | Native Map (mutable) | IMap (FIC) | ApexMap     | Unit | Notes                     |
| :------------------------ | :------------------- | :--------- | :---------- | :--- | :------------------------ |
| `add[]` (new key)         | 0.08                 | 0.21       | 4.02        | µs   |                           |
| `addAll`                  | 1726.96              | 10644.58   | 29.49       | µs   | **ApexMap significantly faster**          |
| `lookup[]` (existing key) | 0.03                 | 0.07       | 0.23        | µs   | ApexMap slower, needs opt.            |
| `remove` (existing key)   | 1736.55¹             | 6768.49    | 3.61        | µs   | **ApexMap significantly faster**          |
| `putIfAbsent`             | 1555.64¹             | 9362.17    | 8.16²       | µs   | ApexMap combines update, faster than FIC |
| `update`                  | 1704.38¹             | 5926.01    | 8.16²       | µs   | ApexMap combines update, faster than FIC |
| `iterateEntries` (full)   | 564.53               | 1134.99    | 2497.49     | µs   | ApexMap slower                            |
| `toMap`                   | -                    | 6186.24    | 8413.29     | µs   | ApexMap slower                            |
| `fromMap`                 | -                    | 1798.14    | 7427.65     | µs   | ApexMap slower                            |

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
