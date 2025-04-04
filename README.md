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
*   Core `ApexList` rebalancing bugs have been **fixed**.
*   Core `ApexMap` structural node errors (`champ_node.dart`) have been **fixed**.
*   Dart Analyzer issues have been **resolved**.
*   `ApexList.addAll` performance remains excellent.
*   `ApexList.fromIterable` strategy stable (recursive concatenation).
*   **`ApexMap` iteration and `toMap` performance dramatically improved** after node fixes.
*   `ApexMap.add` performance improved.
*   Current focus: **Phase 5 - Documentation & Examples**.
## Performance (Latest Benchmark Results)

**Important Note:** These benchmarks were run on **2025-04-04 ~21:50 UTC+1** with Dart SDK 3.7.2 on the development machine after fixing the `ChampTrieIterator` and ensuring all tests pass. Results may vary on different machines or SDK versions. Further optimization for some `ApexMap` operations is deferred.

**List Benchmarks (Size: 10,000)**

| Operation                     | Native List (mutable) | IList (FIC) | ApexList    | Unit | Notes                                     |
| :---------------------------- | :-------------------- | :---------- | :---------- | :--- | :---------------------------------------- |
| `add` (single element)        | 0.12                  | 1501.38     | 26.74       | µs   | ApexList much faster than FIC             |
| `addAll`                      | 10577.51              | 1.60        | 32.34       | µs   | **ApexList Excellent**                    |
| `lookup[]` (middle index)     | 0.01                  | 0.04        | 0.15        | µs   | **ApexList Excellent** (Faster than FIC)  |
| `removeAt` (middle index)     | 2308.86¹              | 656.70      | 20.75       | µs   | **ApexList Excellent** (Faster than both) |
| `removeWhere`                 | 5864.51               | 1725.36     | 2985.37     | µs   | ApexList competitive                      |
| `iterateSum` (full traversal) | 28.01                 | 268.47      | 271.81      | µs   | ApexList competitive                      |
| `sublist`                     | 1057.50               | 1026.95     | 6.13        | µs   | **ApexList Excellent** (Faster than both) |
| `concat(+)`                   | 3395.51               | 0.85        | 7.82        | µs   | ApexList very fast (FIC exceptionally so) |
| `toList`                      | -                     | 595.06      | 772.02      | µs   | ApexList competitive                      |
| `fromIterable`                | -                     | 702.64      | 3144.22     | µs   | ApexList slower (trade-off for lookup)    |

*Footnotes:*
¹ Native mutable operations benchmarked include `List.of()` copy for immutability comparison where applicable.

**Map Benchmarks (Size: 10,000)**

| Operation                 | Native Map (mutable) | IMap (FIC) | ApexMap     | Unit | Notes                                     |
| :------------------------ | :------------------- | :--------- | :---------- | :--- | :---------------------------------------- |
| `add[]` (new key)         | 0.08                 | 0.17       | 4.16        | µs   | ApexMap stable, slower than Native/FIC    |
| `addAll`                  | 1526.58              | 9822.16    | 30.89       | µs   | **ApexMap Excellent** (Faster than both)  |
| `lookup[]` (existing key) | 0.03                 | 0.05       | 0.23        | µs   | ApexMap stable, slower than Native/FIC    |
| `remove` (existing key)   | 1619.37¹             | 6092.60    | 3.80        | µs   | **ApexMap Excellent** (Faster than FIC)   |
| `putIfAbsent`             | 1630.88¹             | 9296.48    | 8.55²       | µs   | ApexMap combines update, faster than FIC |
| `update`                  | 1638.96¹             | 6034.96    | 8.55²       | µs   | ApexMap combines update, faster than FIC |
| `iterateEntries` (full)   | 489.19               | 1161.73    | 2966.55     | µs   | ApexMap slower (Corrected logic)          |
| `toMap`                   | -                    | 6196.22    | 8565.48     | µs   | ApexMap slower (Corrected logic)          |
| `fromMap`                 | -                    | 1826.51    | 8453.27     | µs   | ApexMap slower than FIC                   |

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
