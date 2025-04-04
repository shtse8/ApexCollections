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

## Performance (Latest Benchmark Results)

**Important Note:** These benchmarks were run on [Date/Time, e.g., 2025-04-04 ~10:00 UTC+1] with Dart SDK [Version, if known] on the development machine. The `ApexList.removeAt` operation still has known implementation issues that might affect its stability or performance under certain conditions, even though the benchmark completed. Results may vary on different machines or SDK versions.

**List Benchmarks (Size: 10,000)**

| Operation                     | Native List (mutable) | IList (FIC) | ApexList    | Unit | Notes                     |
| :---------------------------- | :-------------------- | :---------- | :---------- | :--- | :------------------------ |
| `add` (single element)        | 0.10                  | 1628.15     | 27.42       | µs   |                           |
| `addAll`                      | 12269.07              | 1.69        | 190.63      | µs   | FIC `addAll` is optimized |
| `lookup[]` (middle index)     | 0.01                  | 0.04        | 0.34        | µs   |                           |
| `removeAt` (middle index)     | 2350.53¹              | 697.99      | 17.23²      | µs   | ApexList has known issues |
| `removeWhere`                 | 6142.49               | 1796.30     | 2540.24     | µs   |                           |
| `iterateSum` (full traversal) | 30.77                 | 272.01      | 237.11      | µs   |                           |
| `sublist`                     | 1114.76               | 1079.53     | 32.38       | µs   |                           |
| `concat(+)`                   | 3625.41               | 0.87        | 6.32        | µs   | FIC `+` is optimized      |
| `toList`                      | -                     | 619.13      | 2357.91     | µs   |                           |
| `fromIterable`                | -                     | 745.16      | 1963.70     | µs   |                           |

*Footnotes:*
¹ Native `removeAt` benchmark includes `List.of()` copy for immutability comparison.
² `ApexList.removeAt` has known implementation issues affecting stability/performance under certain conditions.

**Map Benchmarks (Size: 10,000)**

| Operation                 | Native Map (mutable) | IMap (FIC) | ApexMap     | Unit | Notes                     |
| :------------------------ | :------------------- | :--------- | :---------- | :--- | :------------------------ |
| `add[]` (new key)         | 0.08                 | 0.20       | 4.27        | µs   |                           |
| `addAll`                  | 1528.25              | 11605.74   | 33.77       | µs   |                           |
| `lookup[]` (existing key) | 0.03                 | 0.07       | 0.23        | µs   |                           |
| `remove` (existing key)   | 1553.06¹             | 6578.06    | 3.85        | µs   |                           |
| `putIfAbsent`             | 1569.43¹             | 9775.31    | 8.62²       | µs   | ApexMap combines update   |
| `update`                  | 1540.27¹             | 6328.08    | 8.62²       | µs   | ApexMap combines update   |
| `iterateEntries` (full)   | 479.52               | 1174.07    | 2837.96     | µs   |                           |
| `toMap`                   | -                    | 6540.05    | 8369.21     | µs   |                           |
| `fromMap`                 | -                    | 1991.09    | 8529.24     | µs   |                           |

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
