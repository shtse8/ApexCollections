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

## Performance (Preliminary Results)

**Important Note:** The following results for `ApexCollections` are preliminary, based on benchmarks run during development. Some optimizations have been made since, and the `ApexList` implementation has known issues affecting some operations. These numbers are subject to change and require re-benchmarking once the library stabilizes.

**Baseline Comparison (Native vs. FIC):**

Initial benchmarks (comparing native Dart collections and `fast_immutable_collections` (FIC) with 10,000 elements) provide context:
*   **Lookups (`[]`):** Native and FIC are very fast.
*   **Adds:** Native mutable adds are fastest. FIC adds involve overhead.
*   **Removals:** Performance varies (native often involves full copies in benchmarks).
*   **Iteration:** Native iteration is generally faster.

**ApexCollections Preliminary Findings (vs. Baseline):**

*   **ApexMap:**
    *   Bulk modifications (`addAll`, `remove`, `update`), iteration (`iterateEntries`), `toMap`: Excellent performance observed.
    *   `fromMap`: Significantly improved with O(N) bulk loading (needs re-benchmarking).
    *   Single `add`/`lookup`: Acceptable, but potentially slower than competitors (investigation needed).
*   **ApexList:**
    *   `add`, `addAll`: Good performance observed.
    *   `removeAt`: Good performance observed (but underlying logic has known issues).
    *   `concat(+)`: Excellent performance (~6 µs).
    *   `sublist`: Excellent performance (~32 µs).
    *   `removeWhere`: Acceptable performance (~2500 µs).
    *   Iteration (`iterateSum`): Acceptable performance (~260-300 µs).
    *   `toList`: Potentially improved via iterators (~960 µs before, needs re-benchmarking).
    *   `fromIterable`: Optimization attempted (~1760 µs before, needs re-benchmarking).

*(See the `benchmark/` directory for testing code. Full, updated benchmark results comparing ApexCollections against native and FIC will be added once the library stabilizes.)*
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
