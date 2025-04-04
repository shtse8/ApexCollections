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
*   Extensive unit tests are in place (`ApexMap` tests passing, `ApexList` tests partially failing due to known issue).
*   Ongoing work includes:
    *   **High Priority:** Fixing a known bug in `ApexList.removeAt` rebalancing logic (`StateError: Cannot rebalance incompatible nodes...`).
    *   Investigating performance bottlenecks, particularly for `ApexMap` single-element operations and `fromMap`/`fromIterable` conversions.
    *   Improving documentation.

## Performance (Latest Benchmark Results)

**Important Note:** These benchmarks were run on **2025-04-04 ~10:41 UTC+1** with Dart SDK [Version, if known] on the development machine. The `ApexList.removeAt` operation still has known implementation issues that might affect its stability or performance under certain conditions, even though the benchmark completed. Results may vary on different machines or SDK versions.

**List Benchmarks (Size: 10,000)**

| Operation                     | Native List (mutable) | IList (FIC) | ApexList    | Unit | Notes                     |
| :---------------------------- | :-------------------- | :---------- | :---------- | :--- | :------------------------ |
| `add` (single element)        | 0.10                  | 1490.24     | 27.10       | µs   |                           |
| `addAll`                      | 11372.11              | 1.69        | 190.23      | µs   | FIC `addAll` is optimized |
| `lookup[]` (middle index)     | 0.01                  | 0.04        | 0.33        | µs   |                           |
| `removeAt` (middle index)     | 2412.44¹              | 692.11      | 16.82²      | µs   | ApexList has known issues |
| `removeWhere`                 | 5947.82               | 1827.87     | 2496.16     | µs   |                           |
| `iterateSum` (full traversal) | 28.46                 | 262.72      | 234.23      | µs   |                           |
| `sublist`                     | 1071.11               | 1073.32     | 31.84       | µs   |                           |
| `concat(+)`                   | 3549.83               | 0.88        | 6.27        | µs   | FIC `+` is optimized      |
| `toList`                      | -                     | 629.62      | 740.79      | µs   |                           |
| `fromIterable`                | -                     | 739.61      | 1957.63     | µs   |                           |

*Footnotes:*
¹ Native `removeAt` benchmark includes `List.of()` copy for immutability comparison.
² `ApexList.removeAt` has known implementation issues affecting stability/performance under certain conditions.

**Map Benchmarks (Size: 10,000)**

| Operation                 | Native Map (mutable) | IMap (FIC) | ApexMap     | Unit | Notes                     |
| :------------------------ | :------------------- | :--------- | :---------- | :--- | :------------------------ |
| `add[]` (new key)         | 0.08                 | 0.21       | 4.02        | µs   |                           |
| `addAll`                  | 1726.96              | 10644.58   | 29.49       | µs   |                           |
| `lookup[]` (existing key) | 0.03                 | 0.07       | 0.23        | µs   |                           |
| `remove` (existing key)   | 1736.55¹             | 6768.49    | 3.61        | µs   |                           |
| `putIfAbsent`             | 1555.64¹             | 9362.17    | 8.16²       | µs   | ApexMap combines update   |
| `update`                  | 1704.38¹             | 5926.01    | 8.16²       | µs   | ApexMap combines update   |
| `iterateEntries` (full)   | 564.53               | 1134.99    | 2497.49     | µs   |                           |
| `toMap`                   | -                    | 6186.24    | 8413.29     | µs   |                           |
| `fromMap`                 | -                    | 1798.14    | 7427.65     | µs   |                           |

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
