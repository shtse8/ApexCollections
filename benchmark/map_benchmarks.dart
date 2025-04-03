import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:apex_collections/apex_collections.dart'; // Import ApexMap

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

class NativeMapAddAllBenchmark extends BenchmarkBase {
  NativeMapAddAllBenchmark() : super('Map(mutable).addAll');
  late Map<int, String> map;
  late Map<int, String> toAdd;

  @override
  void setup() {
    map = createTestData(mapSize);
    toAdd = {for (var i = 0; i < 10; i++) mapSize + i: 'new_value_$i'};
  }

  @override
  void run() {
    // Create copy to measure addAll without modifying base map across runs
    final mapCopy = Map.of(map);
    mapCopy.addAll(toAdd);
  }
}

class NativeMapPutIfAbsentBenchmark extends BenchmarkBase {
  NativeMapPutIfAbsentBenchmark() : super('Map(mutable).putIfAbsent');
  late Map<int, String> baseMap;
  late int existingKey;
  late int newKey;

  @override
  void setup() {
    baseMap = createTestData(mapSize);
    existingKey = mapSize ~/ 2;
    newKey = mapSize;
  }

  @override
  void run() {
    final mapCopy = Map.of(baseMap);
    // Case 1: Key exists
    mapCopy.putIfAbsent(existingKey, () => 'should_not_be_added');
    // Case 2: Key doesn't exist
    mapCopy.putIfAbsent(newKey, () => 'added_value');
  }
}

class NativeMapUpdateBenchmark extends BenchmarkBase {
  NativeMapUpdateBenchmark() : super('Map(mutable).update');
  late Map<int, String> baseMap;
  late int updateKey;

  @override
  void setup() {
    baseMap = createTestData(mapSize);
    updateKey = mapSize ~/ 2; // Key that exists
  }

  @override
  void run() {
    final mapCopy = Map.of(baseMap);
    mapCopy.update(updateKey, (value) => '${value}_updated');
  }
}

// --- fast_immutable_collections IMap Benchmarks ---

class FIC_IMapAddBenchmark extends BenchmarkBase {
  FIC_IMapAddBenchmark() : super('IMap(FIC).add'); // Changed name from add[]
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

class FIC_IMapAddAllBenchmark extends BenchmarkBase {
  FIC_IMapAddAllBenchmark() : super('IMap(FIC).addAll');
  late IMap<int, String> iMap;
  late Map<int, String> toAdd; // Can add a native map

  @override
  void setup() {
    iMap = IMap(createTestData(mapSize));
    toAdd = {for (var i = 0; i < 10; i++) mapSize + i: 'new_value_$i'};
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newMap = iMap.addAll(IMap(toAdd)); // Convert to IMap before adding
  }
}

class FIC_IMapPutIfAbsentBenchmark extends BenchmarkBase {
  FIC_IMapPutIfAbsentBenchmark() : super('IMap(FIC).putIfAbsent');
  late IMap<int, String> iMap;
  late int existingKey;
  late int newKey;

  @override
  void setup() {
    iMap = IMap(createTestData(mapSize));
    existingKey = mapSize ~/ 2;
    newKey = mapSize;
  }

  @override
  void run() {
    // Case 1: Key exists
    // ignore: unused_local_variable
    final map1 = iMap.putIfAbsent(existingKey, () => 'should_not_be_added');
    // Case 2: Key doesn't exist
    // ignore: unused_local_variable
    final map2 = iMap.putIfAbsent(newKey, () => 'added_value');
  }
}

class FIC_IMapUpdateBenchmark extends BenchmarkBase {
  FIC_IMapUpdateBenchmark() : super('IMap(FIC).update');
  late IMap<int, String> iMap;
  late int updateKey;

  @override
  void setup() {
    iMap = IMap(createTestData(mapSize));
    updateKey = mapSize ~/ 2; // Key that exists
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newMap = iMap.update(updateKey, (value) => '${value}_updated');
  }
}

// --- ApexCollections ApexMap Benchmarks ---

class ApexMapAddBenchmark extends BenchmarkBase {
  ApexMapAddBenchmark() : super('ApexMap.add');
  late ApexMap<int, String> apexMap;
  late int newKey;

  @override
  void setup() {
    apexMap = ApexMap.from(createTestData(mapSize));
    newKey = mapSize;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newApexMap = apexMap.add(newKey, 'new_value'); // Create new map
  }
}

class ApexMapLookupBenchmark extends BenchmarkBase {
  ApexMapLookupBenchmark() : super('ApexMap.lookup[]');
  late ApexMap<int, String> apexMap;
  late int lookupKey;

  @override
  void setup() {
    apexMap = ApexMap.from(createTestData(mapSize));
    lookupKey = mapSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final value = apexMap[lookupKey];
  }
}

class ApexMapRemoveBenchmark extends BenchmarkBase {
  ApexMapRemoveBenchmark() : super('ApexMap.remove');
  late ApexMap<int, String> apexMap;
  late int removeKey;

  @override
  void setup() {
    apexMap = ApexMap.from(createTestData(mapSize));
    removeKey = mapSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newApexMap = apexMap.remove(removeKey); // Create new map
  }
}

class ApexMapIterateBenchmark extends BenchmarkBase {
  ApexMapIterateBenchmark() : super('ApexMap.iterateEntries');
  late ApexMap<int, String> apexMap;

  @override
  void setup() {
    apexMap = ApexMap.from(createTestData(mapSize));
  }

  @override
  void run() {
    var count = 0;
    for (final entry in apexMap.entries) {
      // Access key and value to prevent optimization
      if (entry.key == -1) count++;
      if (entry.value == '') count++;
    }
    if (count == -1) print('Should not happen');
  }
}

class ApexMapAddAllBenchmark extends BenchmarkBase {
  ApexMapAddAllBenchmark() : super('ApexMap.addAll');
  late ApexMap<int, String> apexMap;
  late Map<int, String> toAdd; // Can add a native map

  @override
  void setup() {
    apexMap = ApexMap.from(createTestData(mapSize));
    toAdd = {for (var i = 0; i < 10; i++) mapSize + i: 'new_value_$i'};
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newMap = apexMap.addAll(toAdd); // ApexMap.addAll takes Map
  }
}

class ApexMapUpdateBenchmark extends BenchmarkBase {
  // Combines update and putIfAbsent logic via the update method's ifAbsent
  ApexMapUpdateBenchmark() : super('ApexMap.update (incl. ifAbsent)');
  late ApexMap<int, String> apexMap;
  late int existingKey;
  late int newKey;

  @override
  void setup() {
    apexMap = ApexMap.from(createTestData(mapSize));
    existingKey = mapSize ~/ 2;
    newKey = mapSize;
  }

  @override
  void run() {
    // Case 1: Key exists (update)
    // ignore: unused_local_variable
    final map1 = apexMap.update(existingKey, (value) => '${value}_updated');
    // Case 2: Key doesn't exist (add via ifAbsent)
    // ignore: unused_local_variable
    final map2 = apexMap.update(
      newKey,
      (value) => 'should_not_happen',
      ifAbsent: () => 'added_value',
    );
  }
}

// --- Main Runner ---

void main() {
  print('--- Running Map Benchmarks (Size: $mapSize) ---');

  // Native Map Benchmarks
  print('\n-- Native Map --');
  NativeMapAddBenchmark().report();
  NativeMapAddAllBenchmark().report();
  NativeMapLookupBenchmark().report();
  NativeMapRemoveBenchmark().report();
  NativeMapPutIfAbsentBenchmark().report();
  NativeMapUpdateBenchmark().report();
  NativeMapIterateBenchmark().report();

  // fast_immutable_collections IMap Benchmarks
  print('\n-- IMap (FIC) --');
  FIC_IMapAddBenchmark().report();
  FIC_IMapAddAllBenchmark().report();
  FIC_IMapLookupBenchmark().report();
  FIC_IMapRemoveBenchmark().report();
  FIC_IMapPutIfAbsentBenchmark().report();
  FIC_IMapUpdateBenchmark().report();
  FIC_IMapIterateBenchmark().report();

  // ApexCollections ApexMap Benchmarks
  print('\n-- ApexMap --');
  ApexMapAddBenchmark().report();
  ApexMapAddAllBenchmark().report();
  ApexMapLookupBenchmark().report();
  ApexMapRemoveBenchmark().report();
  ApexMapUpdateBenchmark().report(); // Covers update & putIfAbsent logic
  ApexMapIterateBenchmark().report();

  print('----------------------------------------');
}
