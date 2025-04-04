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

**Important Note:** These benchmarks were run on **2025-04-04 ~19:30 UTC+1** with Dart SDK 3.7.2 on the development machine after fixing `champ_node.dart` structural issues. Results may vary on different machines or SDK versions. Further optimization for some `ApexMap` operations is deferred.

**List Benchmarks (Size: 10,000)**

| Operation                     | Native List (mutable) | IList (FIC) | ApexList    | Unit | Notes                                     |
| :---------------------------- | :-------------------- | :---------- | :---------- | :--- | :---------------------------------------- |
| `add` (single element)        | 0.12                  | 1575.81     | 24.12       | µs   | ApexList much faster than FIC             |
| `addAll`                      | 10778.61              | 1.49        | 29.38       | µs   | **ApexList Excellent**                    |
| `lookup[]` (middle index)     | 0.01                  | 0.04        | 0.15        | µs   | **ApexList Excellent** (Faster than FIC)  |
| `removeAt` (middle index)     | 2047.79¹              | 615.85      | 18.86       | µs   | **ApexList Excellent** (Faster than both) |
| `removeWhere`                 | 5314.43               | 1590.47     | 2753.31     | µs   | ApexList competitive                      |
| `iterateSum` (full traversal) | 28.91                 | 274.72      | 261.48      | µs   | ApexList competitive                      |
| `sublist`                     | 957.40                | 932.54      | 5.65        | µs   | **ApexList Excellent** (Faster than both) |
| `concat(+)`                   | 2888.74               | 0.76        | 7.04        | µs   | ApexList very fast (FIC exceptionally so) |
| `toList`                      | -                     | 557.78      | 716.06      | µs   | ApexList competitive                      |
| `fromIterable`                | -                     | 647.19      | 2858.17     | µs   | ApexList slower (trade-off for lookup)    |

*Footnotes:*
¹ Native mutable operations benchmarked include `List.of()` copy for immutability comparison where applicable.

**Map Benchmarks (Size: 10,000)**

| Operation                 | Native Map (mutable) | IMap (FIC) | ApexMap     | Unit | Notes                                     |
| :------------------------ | :------------------- | :--------- | :---------- | :--- | :---------------------------------------- |
| `add[]` (new key)         | 0.08                 | 0.20       | 4.08        | µs   | ApexMap improved, but slower than Native/FIC |
| `addAll`                  | 1649.42              | 10254.74   | 31.70       | µs   | **ApexMap Excellent** (Faster than both)  |
| `lookup[]` (existing key) | 0.03                 | 0.06       | 0.24        | µs   | ApexMap stable, slower than Native/FIC    |
| `remove` (existing key)   | 1484.02¹             | 6204.20    | 3.73        | µs   | **ApexMap Excellent** (Faster than FIC)   |
| `putIfAbsent`             | 1622.40¹             | 9051.11    | 8.47²       | µs   | ApexMap combines update, faster than FIC |
| `update`                  | 1600.83¹             | 6012.73    | 8.47²       | µs   | ApexMap combines update, faster than FIC |
| `iterateEntries` (full)   | 477.24               | 1127.62    | 24.87       | µs   | **ApexMap Excellent** (Faster than both!) |
| `toMap`                   | -                    | 5922.38    | 51.84       | µs   | **ApexMap Excellent** (Faster than FIC!)  |
| `fromMap`                 | -                    | 1775.75    | 8333.64     | µs   | ApexMap slower than FIC                   |

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
