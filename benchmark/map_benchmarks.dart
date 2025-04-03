import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

// Placeholder for benchmark setup
const int mapSize = 10000; // Example size, will need various sizes
Map<int, String> createTestData(int size) {
  return {for (var i = 0; i < size; i++) i: 'value_$i'};
}

// --- Native Map Benchmarks ---

class NativeMapAddBenchmark extends BenchmarkBase {
  NativeMapAddBenchmark() : super('Map(mutable).add[]');
  late Map<int, String> map;
  late int newKey;

  @override
  void setup() {
    map = createTestData(mapSize);
    newKey = mapSize; // Key that doesn't exist yet
  }

  @override
  void run() {
    map[newKey] = 'new_value'; // Add a new entry
  }
}

class NativeMapLookupBenchmark extends BenchmarkBase {
  NativeMapLookupBenchmark() : super('Map(mutable).lookup[]');
  late Map<int, String> map;
  late int lookupKey;

  @override
  void setup() {
    map = createTestData(mapSize);
    lookupKey = mapSize ~/ 2; // Lookup middle key
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final value = map[lookupKey];
  }
}

class NativeMapRemoveBenchmark extends BenchmarkBase {
  NativeMapRemoveBenchmark() : super('Map(mutable).remove');
  late int removeKey;
  late Map<int, String> baseMap; // Base map created once

  @override
  void setup() {
    // Create the base map once
    baseMap = createTestData(mapSize);
    removeKey = mapSize ~/ 2;
  }

  @override
  void run() {
    // Copy the map then remove, to isolate remove cost per run
    final mapCopy = Map.of(baseMap);
    mapCopy.remove(removeKey);
  }
}

class NativeMapIterateBenchmark extends BenchmarkBase {
  NativeMapIterateBenchmark() : super('Map(mutable).iterateEntries');
  late Map<int, String> map;

  @override
  void setup() {
    map = createTestData(mapSize);
  }

  @override
  void run() {
    var count = 0;
    for (final entry in map.entries) {
      // Access key and value to prevent optimization
      if (entry.key == -1) count++;
      if (entry.value == '') count++;
    }
    if (count == -1) print('Should not happen');
  }
}

// TODO: Add benchmarks for other Map operations (lookup, remove, iteration, etc.)

// --- fast_immutable_collections IMap Benchmarks ---

class FIC_IMapAddBenchmark extends BenchmarkBase {
  FIC_IMapAddBenchmark() : super('IMap(FIC).add[]');
  late IMap<int, String> iMap;
  late int newKey;

  @override
  void setup() {
    iMap = IMap(createTestData(mapSize));
    newKey = mapSize;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newIMap = iMap.add(newKey, 'new_value'); // Create new map
  }
}

class FIC_IMapLookupBenchmark extends BenchmarkBase {
  FIC_IMapLookupBenchmark() : super('IMap(FIC).lookup[]');
  late IMap<int, String> iMap;
  late int lookupKey;

  @override
  void setup() {
    iMap = IMap(createTestData(mapSize));
    lookupKey = mapSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final value = iMap[lookupKey];
  }
}

class FIC_IMapRemoveBenchmark extends BenchmarkBase {
  FIC_IMapRemoveBenchmark() : super('IMap(FIC).remove');
  late IMap<int, String> iMap;
  late int removeKey;

  @override
  void setup() {
    iMap = IMap(createTestData(mapSize));
    removeKey = mapSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newIMap = iMap.remove(removeKey); // Create new map
  }
}

class FIC_IMapIterateBenchmark extends BenchmarkBase {
  FIC_IMapIterateBenchmark() : super('IMap(FIC).iterateEntries');
  late IMap<int, String> iMap;

  @override
  void setup() {
    iMap = IMap(createTestData(mapSize));
  }

  @override
  void run() {
    var count = 0;
    for (final entry in iMap.entries) {
      // Access key and value to prevent optimization
      if (entry.key == -1) count++;
      if (entry.value == '') count++;
    }
    if (count == -1) print('Should not happen');
  }
}

// TODO: Add benchmarks for other IMap operations

// --- Main Runner ---

void main() {
  print('Running Map Benchmarks (Size: $mapSize)...');
  // Add benchmarks to run here
  NativeMapAddBenchmark().report();
  FIC_IMapAddBenchmark().report();
  NativeMapLookupBenchmark().report();
  FIC_IMapLookupBenchmark().report();
  NativeMapRemoveBenchmark().report();
  FIC_IMapRemoveBenchmark().report();
  NativeMapIterateBenchmark().report();
  FIC_IMapIterateBenchmark().report();

  // Add more benchmark reports here...
  print('--------------------');
}
