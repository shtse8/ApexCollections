import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
// TODO: Import fast_immutable_collections when needed

// Placeholder for benchmark setup
const int listSize = 10000; // Example size, will need various sizes

// --- Native List Benchmarks ---

class NativeListAddBenchmark extends BenchmarkBase {
  NativeListAddBenchmark() : super('List(mutable).add');
  late List<int> list;

  @override
  void setup() {
    list = List.generate(listSize, (i) => i, growable: true);
  }

  @override
  void run() {
    list.add(listSize); // Simple add operation
  }

  @override
  void teardown() {
    // Optional cleanup
  }
}

class NativeListLookupBenchmark extends BenchmarkBase {
  NativeListLookupBenchmark() : super('List(mutable).lookup[]');
  late List<int> list;
  late int lookupIndex;

  @override
  void setup() {
    list = List.generate(listSize, (i) => i, growable: false);
    lookupIndex = listSize ~/ 2; // Lookup middle element
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final value = list[lookupIndex];
  }
}

class NativeListRemoveAtBenchmark extends BenchmarkBase {
  NativeListRemoveAtBenchmark() : super('List(mutable).removeAt');
  late int removeIndex;
  late List<int> baseList; // Base list created once

  @override
  void setup() {
    // Create the base list once
    baseList = List.generate(
      listSize,
      (i) => i,
      growable: false,
    ); // Can be fixed-size
    removeIndex = listSize ~/ 2;
  }

  @override
  void run() {
    // Copy the list then remove, to isolate remove cost per run
    // Note: This measures copy (O(N)) + removeAt (O(N))
    final listCopy = List.of(baseList, growable: true);
    listCopy.removeAt(removeIndex);
  }
}

class NativeListIterateBenchmark extends BenchmarkBase {
  NativeListIterateBenchmark() : super('List(mutable).iterateSum');
  late List<int> list;

  @override
  void setup() {
    list = List.generate(listSize, (i) => i, growable: false);
  }

  @override
  void run() {
    var sum = 0;
    for (final item in list) {
      sum += item;
    }
    // Prevent compiler optimizing out the loop
    if (sum == -1) print('Should not happen');
  }
}

// --- fast_immutable_collections IList Benchmarks ---

class FIC_IListAddBenchmark extends BenchmarkBase {
  FIC_IListAddBenchmark() : super('IList(FIC).add');
  late IList<int> iList;

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    iList = iList.add(listSize); // Must reassign due to immutability
  }

  @override
  void teardown() {
    // Optional cleanup
  }
}

class FIC_IListLookupBenchmark extends BenchmarkBase {
  FIC_IListLookupBenchmark() : super('IList(FIC).lookup[]');
  late IList<int> iList;
  late int lookupIndex;

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
    lookupIndex = listSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final value = iList[lookupIndex];
  }
}

class FIC_IListRemoveAtBenchmark extends BenchmarkBase {
  FIC_IListRemoveAtBenchmark() : super('IList(FIC).removeAt');
  late IList<int> iList;
  late int removeIndex;

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
    removeIndex = listSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newList = iList.removeAt(removeIndex); // Create new list
  }
}

class FIC_IListIterateBenchmark extends BenchmarkBase {
  FIC_IListIterateBenchmark() : super('IList(FIC).iterateSum');
  late IList<int> iList;

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    var sum = 0;
    for (final item in iList) {
      sum += item;
    }
    // Prevent compiler optimizing out the loop
    if (sum == -1) print('Should not happen');
  }
}

// TODO: Add benchmarks for other List operations (remove, lookup, iteration, etc.)
// TODO: Add benchmarks for fast_immutable_collections IList operations

// --- Main Runner ---

void main() {
  FIC_IListAddBenchmark().report();
  print('Running List Benchmarks (Size: $listSize)...');
  // Add benchmarks to run here
  NativeListAddBenchmark().report();
  NativeListLookupBenchmark().report();
  NativeListRemoveAtBenchmark().report();
  FIC_IListLookupBenchmark().report();
  FIC_IListRemoveAtBenchmark().report();
  NativeListIterateBenchmark().report();
  FIC_IListIterateBenchmark().report();

  // Add more benchmark reports here...
  print('--------------------');
}
