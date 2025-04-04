import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:apex_collections/apex_collections.dart'; // Import ApexList

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

class NativeListAddAllBenchmark extends BenchmarkBase {
  NativeListAddAllBenchmark() : super('List(mutable).addAll');
  late List<int> list;
  late List<int> toAdd;

  @override
  void setup() {
    list = List.generate(listSize, (i) => i, growable: true);
    toAdd = List.generate(10, (i) => listSize + i); // Add 10 elements
  }

  @override
  void run() {
    // Create copy to measure addAll without modifying base list across runs
    final listCopy = List.of(list, growable: true);
    listCopy.addAll(toAdd);
  }
}

class NativeListRemoveWhereBenchmark extends BenchmarkBase {
  NativeListRemoveWhereBenchmark() : super('List(mutable).removeWhere');
  late List<int> baseList;

  @override
  void setup() {
    baseList = List.generate(listSize, (i) => i, growable: false);
  }

  @override
  void run() {
    // Copy list then removeWhere to isolate cost per run
    // Note: Measures copy + removeWhere
    final listCopy = List.of(baseList, growable: true);
    listCopy.removeWhere((element) => element.isEven); // Remove even numbers
  }
}

class NativeListSublistBenchmark extends BenchmarkBase {
  NativeListSublistBenchmark() : super('List(mutable).sublist');
  late List<int> list;
  late int start;
  late int end;

  @override
  void setup() {
    list = List.generate(listSize, (i) => i, growable: false);
    start = listSize ~/ 4;
    end = listSize * 3 ~/ 4;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final sub = list.sublist(start, end);
  }
}

class NativeListConcatBenchmark extends BenchmarkBase {
  NativeListConcatBenchmark() : super('List(mutable).concat(+)');
  late List<int> list1;
  late List<int> list2;

  @override
  void setup() {
    final halfSize = listSize ~/ 2;
    list1 = List.generate(halfSize, (i) => i, growable: false);
    list2 = List.generate(halfSize, (i) => i + halfSize, growable: false);
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final combined = list1 + list2; // Using + operator
    // Alternative: final combined = [...list1, ...list2];
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

class FIC_IListAddAllBenchmark extends BenchmarkBase {
  FIC_IListAddAllBenchmark() : super('IList(FIC).addAll');
  late IList<int> iList;
  late List<int> toAdd; // Can add a native list

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
    toAdd = List.generate(10, (i) => listSize + i);
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newList = iList.addAll(toAdd);
  }
}

class FIC_IListRemoveWhereBenchmark extends BenchmarkBase {
  FIC_IListRemoveWhereBenchmark() : super('IList(FIC).removeWhere');
  late IList<int> iList;

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newList = iList.removeWhere((element) => element.isEven);
  }
}

class FIC_IListSublistBenchmark extends BenchmarkBase {
  FIC_IListSublistBenchmark() : super('IList(FIC).sublist');
  late IList<int> iList;
  late int start;
  late int end;

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
    start = listSize ~/ 4;
    end = listSize * 3 ~/ 4;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final sub = iList.sublist(start, end);
  }
}

class FIC_IListConcatBenchmark extends BenchmarkBase {
  FIC_IListConcatBenchmark() : super('IList(FIC).concat(+)');
  late IList<int> iList1;
  late IList<int> iList2;

  @override
  void setup() {
    final halfSize = listSize ~/ 2;
    iList1 = IList(List.generate(halfSize, (i) => i));
    iList2 = IList(List.generate(halfSize, (i) => i + halfSize));
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final combined = iList1 + iList2; // Using + operator
  }
}

class FIC_IListToListBenchmark extends BenchmarkBase {
  FIC_IListToListBenchmark() : super('IList(FIC).toList');
  late IList<int> iList;

  @override
  void setup() {
    iList = IList(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final nativeList = iList.toList(); // Assuming FIC has toList()
  }
}

class FIC_IListFromIterableBenchmark extends BenchmarkBase {
  FIC_IListFromIterableBenchmark() : super('IList(FIC).fromIterable');
  late List<int> nativeList; // Source iterable

  @override
  void setup() {
    nativeList = List.generate(listSize, (i) => i, growable: false);
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final iList = IList(nativeList); // Constructor acts like fromIterable
  }
}

// --- ApexCollections ApexList Benchmarks ---

class ApexListAddBenchmark extends BenchmarkBase {
  ApexListAddBenchmark() : super('ApexList.add');
  late ApexList<int> apexList;

  @override
  void setup() {
    // Use fromIterable for efficient setup
    apexList = ApexList.from(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    apexList = apexList.add(listSize); // Must reassign due to immutability
  }
}

class ApexListLookupBenchmark extends BenchmarkBase {
  ApexListLookupBenchmark() : super('ApexList.lookup[]');
  late ApexList<int> apexList;
  late int lookupIndex;

  @override
  void setup() {
    apexList = ApexList.from(List.generate(listSize, (i) => i));
    lookupIndex = listSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final value = apexList[lookupIndex];
  }
}

class ApexListRemoveAtBenchmark extends BenchmarkBase {
  ApexListRemoveAtBenchmark() : super('ApexList.removeAt');
  late ApexList<int> apexList;
  late int removeIndex;

  @override
  void setup() {
    apexList = ApexList.from(List.generate(listSize, (i) => i));
    removeIndex = listSize ~/ 2;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newList = apexList.removeAt(removeIndex); // Create new list
  }
}

class ApexListIterateBenchmark extends BenchmarkBase {
  ApexListIterateBenchmark() : super('ApexList.iterateSum');
  late ApexList<int> apexList;

  @override
  void setup() {
    apexList = ApexList.from(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    var sum = 0;
    for (final item in apexList) {
      sum += item;
    }
    // Prevent compiler optimizing out the loop
    if (sum == -1) print('Should not happen');
  }
}

class ApexListAddAllBenchmark extends BenchmarkBase {
  ApexListAddAllBenchmark() : super('ApexList.addAll');
  late ApexList<int> apexList;
  late List<int> toAdd; // Can add a native list

  @override
  void setup() {
    apexList = ApexList.from(List.generate(listSize, (i) => i));
    toAdd = List.generate(10, (i) => listSize + i);
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newList = apexList.addAll(toAdd);
  }
}

class ApexListRemoveWhereBenchmark extends BenchmarkBase {
  ApexListRemoveWhereBenchmark() : super('ApexList.removeWhere');
  late ApexList<int> apexList;

  @override
  void setup() {
    apexList = ApexList.from(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final newList = apexList.removeWhere((element) => element.isEven);
  }
}

class ApexListSublistBenchmark extends BenchmarkBase {
  ApexListSublistBenchmark() : super('ApexList.sublist');
  late ApexList<int> apexList;
  late int start;
  late int end;

  @override
  void setup() {
    apexList = ApexList.from(List.generate(listSize, (i) => i));
    start = listSize ~/ 4;
    end = listSize * 3 ~/ 4;
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final sub = apexList.sublist(start, end);
  }
}

class ApexListConcatBenchmark extends BenchmarkBase {
  ApexListConcatBenchmark() : super('ApexList.concat(+)');
  late ApexList<int> apexList1;
  late ApexList<int> apexList2;

  @override
  void setup() {
    final halfSize = listSize ~/ 2;
    apexList1 = ApexList.from(List.generate(halfSize, (i) => i));
    apexList2 = ApexList.from(List.generate(halfSize, (i) => i + halfSize));
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final combined = apexList1 + apexList2; // Using + operator
  }
}

class ApexListToListBenchmark extends BenchmarkBase {
  ApexListToListBenchmark() : super('ApexList.toList');
  late ApexList<int> apexList;

  @override
  void setup() {
    apexList = ApexList.from(List.generate(listSize, (i) => i));
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final nativeList = apexList.toList();
  }
}

class ApexListFromIterableBenchmark extends BenchmarkBase {
  ApexListFromIterableBenchmark() : super('ApexList.fromIterable');
  late List<int> nativeList; // Source iterable

  @override
  void setup() {
    nativeList = List.generate(listSize, (i) => i, growable: false);
  }

  @override
  void run() {
    // ignore: unused_local_variable
    final apexList = ApexList.from(nativeList);
  }
}

// --- Main Runner ---

void main() {
  print('--- Running List Benchmarks (Size: $listSize) ---');

  // Native List Benchmarks
  print('\n-- Native List --');
  NativeListAddBenchmark().report();
  NativeListAddAllBenchmark().report();
  NativeListLookupBenchmark().report();
  NativeListRemoveAtBenchmark().report(); // Note: Measures copy + remove
  NativeListRemoveWhereBenchmark().report();
  NativeListIterateBenchmark().report();
  NativeListSublistBenchmark().report();
  NativeListConcatBenchmark().report();

  // fast_immutable_collections IList Benchmarks
  print('\n-- IList (FIC) --');
  FIC_IListAddBenchmark().report();
  FIC_IListAddAllBenchmark().report();
  FIC_IListLookupBenchmark().report();
  FIC_IListRemoveAtBenchmark().report();
  FIC_IListRemoveWhereBenchmark().report();
  FIC_IListIterateBenchmark().report();
  FIC_IListSublistBenchmark().report();
  FIC_IListConcatBenchmark().report();
  FIC_IListToListBenchmark().report();
  FIC_IListFromIterableBenchmark().report();

  // ApexCollections ApexList Benchmarks
  print('\n-- ApexList --');
  ApexListAddBenchmark().report();
  ApexListAddAllBenchmark().report();
  ApexListLookupBenchmark().report();
  ApexListRemoveAtBenchmark().report();
  ApexListRemoveWhereBenchmark().report();
  ApexListIterateBenchmark().report();
  ApexListSublistBenchmark().report();
  ApexListConcatBenchmark().report();
  ApexListToListBenchmark().report();
  ApexListFromIterableBenchmark().report();

  print('------------------------------------------');
}
