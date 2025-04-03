import 'package:apex_collections/apex_collections.dart';
import 'dart:math'; // For Random

import 'package:test/test.dart';

void main() {
  group('ApexList Empty', () {
    test('empty() constructor creates an empty list', () {
      final list = ApexList<int>.empty();
      expect(list.isEmpty, isTrue);
      expect(list.isNotEmpty, isFalse);
      expect(list.length, 0);
      expect(() => list.first, throwsStateError);
      expect(() => list.last, throwsStateError);
      expect(() => list[0], throwsRangeError);
      expect(list.iterator.moveNext(), isFalse);
    });

    test('empty list equality', () {
      final list1 = ApexList<int>.empty();
      final list2 = ApexList<String>.empty(); // Different type args
      final list3 = ApexList<int>.empty();

      expect(list1, equals(ApexList<int>.empty()));
      expect(list1, equals(list2)); // Should be equal despite type args
      expect(list1, equals(list3));
      // Check identicality using the public factory constructor.
      // This relies on the factory returning the cached instance via emptyInstance<E>().
      expect(identical(ApexList<int>.empty(), ApexList<int>.empty()), isTrue);
      expect(
        identical(ApexList<String>.empty(), ApexList<String>.empty()),
        isTrue,
      );
      // Empty lists of different types might or might not be identical depending on caching strategy.
    });

    test('empty list hashCode', () {
      expect(ApexList.empty().hashCode, equals(ApexList.empty().hashCode));
      // Check hash codes are consistent for the same type
      expect(
        ApexList<int>.empty().hashCode,
        equals(ApexList<int>.empty().hashCode),
      );
      expect(
        ApexList<String>.empty().hashCode,
        equals(ApexList<String>.empty().hashCode),
      );
      // Hash codes for empty lists of different types might differ, which is acceptable.
    });
  });

  group('ApexList Basic Operations', () {
    test('add single element', () {
      final list0 = ApexList<String>.empty();
      final list1 = list0.add('a');

      // Verify list1
      expect(list1.length, 1);
      expect(list1.isEmpty, isFalse);
      expect(list1.isNotEmpty, isTrue);
      expect(list1[0], 'a');
      expect(list1.first, 'a');
      expect(list1.last, 'a');
      expect(list1, equals(['a'])); // Uses ListEquality via Iterable comparison

      // Verify list0 remains unchanged (immutability)
      expect(list0.length, 0);
      expect(list0.isEmpty, isTrue);
    });

    test('add multiple elements', () {
      final list = ApexList<int>.empty().add(1).add(2).add(3);

      expect(list.length, 3);
      expect(list[0], 1);
      expect(list[1], 2);
      expect(list[2], 3);
      expect(list.first, 1);
      expect(list.last, 3);
      expect(list, equals([1, 2, 3]));
    });

    test('iterator correctness', () {
      final list = ApexList<int>.empty().add(10).add(20).add(30);
      final iterator = list.iterator;
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, 10);
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, 20);
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, 30);
      expect(iterator.moveNext(), isFalse);
    });

    test('removeAt basic', () {
      final list1 = ApexList<String>.empty()
          .add('a')
          .add('b')
          .add('c')
          .add('d');
      final list2 = list1.removeAt(1); // Remove 'b'

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'c');
      expect(list2[2], 'd');
      expect(list2, equals(['a', 'c', 'd']));
      expect(list1, equals(['a', 'b', 'c', 'd'])); // Original unchanged
    });

    test('removeAt first element', () {
      final list1 = ApexList<String>.empty().add('a').add('b').add('c');
      final list2 = list1.removeAt(0); // Remove 'a'

      expect(list2.length, 2);
      expect(list2[0], 'b');
      expect(list2[1], 'c');
      expect(list2, equals(['b', 'c']));
    });

    test('removeAt last element', () {
      final list1 = ApexList<String>.empty().add('a').add('b').add('c');
      final list2 = list1.removeAt(2); // Remove 'c'

      expect(list2.length, 2);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2, equals(['a', 'b']));
    });

    test('removeAt only element', () {
      final list1 = ApexList<String>.empty().add('a');
      final list2 = list1.removeAt(0);

      expect(list2.isEmpty, isTrue);
      expect(list2.length, 0);
      expect(list2, equals(ApexList<String>.empty()));
    });

    test('removeAt invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.removeAt(2), throwsRangeError);
      expect(() => list.removeAt(-1), throwsRangeError);
      expect(() => ApexList<int>.empty().removeAt(0), throwsRangeError);
    });

    test('update existing element', () {
      final list1 = ApexList<String>.empty().add('a').add('b').add('c');
      final list2 = list1.update(1, 'B'); // Update 'b' to 'B'

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'B');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'B', 'c']));
      expect(list1, equals(['a', 'b', 'c'])); // Original unchanged
    });

    test('update with identical value does not change instance', () {
      final list1 = ApexList<String>.empty().add('a').add('b');
      final list2 = list1.update(1, 'b'); // Update with same value

      expect(identical(list1, list2), isTrue);
      expect(list2, equals(['a', 'b']));
    });

    test('update invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.update(2, 99), throwsRangeError);
      expect(() => list.update(-1, 99), throwsRangeError);
      expect(() => ApexList<int>.empty().update(0, 99), throwsRangeError);
    });

    test('addAll', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = list1.addAll([3, 4, 5]);
      final list3 = list2.addAll([]); // Add empty iterable
      final list4 = ApexList<int>.empty().addAll([10, 20]);

      expect(list2, equals([1, 2, 3, 4, 5]));
      expect(list2.length, 5);
      expect(list1, equals([1, 2])); // Original unchanged

      expect(
        identical(list2, list3),
        isTrue,
      ); // Adding empty returns same instance

      expect(list4, equals([10, 20]));
      expect(list4.length, 2);
    });

    test('insert at beginning', () {
      final list1 = ApexList<String>.empty().add('b').add('c');
      final list2 = list1.insert(0, 'a');

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'b', 'c']));
      expect(list1, equals(['b', 'c'])); // Original unchanged
    });

    test('insert in middle', () {
      final list1 = ApexList<String>.empty().add('a').add('c');
      final list2 = list1.insert(1, 'b');

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'b', 'c']));
    });

    test('insert at end', () {
      final list1 = ApexList<String>.empty().add('a').add('b');
      final list2 = list1.insert(2, 'c'); // Equivalent to add

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'b', 'c']));
    });

    test('insert into empty list', () {
      final list1 = ApexList<String>.empty();
      final list2 = list1.insert(0, 'a');

      expect(list2.length, 1);
      expect(list2[0], 'a');
      expect(list2, equals(['a']));
    });

    test('insert invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.insert(3, 99), throwsRangeError); // Index > length
      expect(() => list.insert(-1, 99), throwsRangeError);
    });
  }); // End of Basic Operations group

  group('ApexList Advanced Operations', () {
    test('insertAll into empty list', () {
      final list1 = ApexList<int>.empty();
      final list2 = list1.insertAll(0, [1, 2, 3]);
      expect(list2, equals([1, 2, 3]));
      expect(list1.isEmpty, isTrue); // Original unchanged
    });

    test('insertAll at beginning', () {
      final list1 = ApexList<int>.empty().add(3).add(4);
      final list2 = list1.insertAll(0, [1, 2]);
      expect(list2, equals([1, 2, 3, 4]));
      expect(list1, equals([3, 4])); // Original unchanged
    });

    test('insertAll in middle', () {
      final list1 = ApexList<int>.empty().add(1).add(4);
      final list2 = list1.insertAll(1, [2, 3]);
      expect(list2, equals([1, 2, 3, 4]));
      expect(list1, equals([1, 4])); // Original unchanged
    });

    test('insertAll at end', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = list1.insertAll(2, [3, 4]);
      expect(list2, equals([1, 2, 3, 4]));
      expect(list1, equals([1, 2])); // Original unchanged
    });

    test('insertAll empty iterable', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = list1.insertAll(1, []);
      expect(identical(list1, list2), isTrue); // Should return same instance
      expect(list2, equals([1, 2]));
    });

    test('insertAll invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.insertAll(3, [99]), throwsRangeError);
      expect(() => list.insertAll(-1, [99]), throwsRangeError);
    });

    // --- sublist tests ---
    test('sublist full range', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(0, 3);
      expect(sub, equals([1, 2, 3]));
      expect(
        identical(list1, sub),
        isTrue,
      ); // Sublist of full range should be identical
    });

    test('sublist from start', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(0, 2);
      expect(sub, equals([1, 2]));
      expect(sub.length, 2);
    });

    test('sublist to end', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(1); // No end specified
      expect(sub, equals([2, 3]));
      expect(sub.length, 2);
    });

    test('sublist middle part', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3).add(4).add(5);
      final sub = list1.sublist(1, 4);
      expect(sub, equals([2, 3, 4]));
      expect(sub.length, 3);
    });

    test('sublist empty result (start == end)', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(1, 1);
      expect(sub.isEmpty, isTrue);
      expect(sub.length, 0);
      expect(identical(sub, ApexList<int>.empty()), isTrue);
    });

    test('sublist empty result (start > end) throws RangeError', () {
      // Standard List.sublist requires start <= end.
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      // Expect a RangeError because start (2) > end (1)
      expect(() => list1.sublist(2, 1), throwsRangeError);
    });

    // Split invalid range tests
    test('sublist invalid range: negative start', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      expect(() => list1.sublist(-1), throwsRangeError);
    });

    test('sublist invalid range: end out of bounds', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      expect(() => list1.sublist(0, 4), throwsRangeError);
    });

    test('sublist invalid range: start out of bounds', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      expect(() => list1.sublist(4), throwsRangeError);
    });

    // --- operator+ tests ---
    test('operator+ with empty', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final emptyList = ApexList<int>.empty();

      final res1 = list1 + emptyList;
      final res2 = emptyList + list1;

      expect(identical(res1, list1), isTrue);
      expect(identical(res2, list1), isTrue);
    });

    test('operator+ two non-empty lists', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = ApexList<int>.empty().add(3).add(4).add(5);
      final result = list1 + list2;

      expect(result, equals([1, 2, 3, 4, 5]));
      expect(result.length, 5);
      expect(list1, equals([1, 2])); // Original unchanged
      expect(list2, equals([3, 4, 5])); // Original unchanged
    });

    test('insert causes node splits', () {
      final int B = 32; // Branching factor (use constant if available)
      ApexList<int> list = ApexList.empty();

      // 1. Fill one leaf node exactly
      for (int i = 0; i < B; i++) {
        list = list.add(i);
      }
      expect(list.length, B);
      expect(list, equals(List.generate(B, (i) => i)));

      // 2. Add one more element to trigger leaf split -> height 1 root
      list = list.add(B);
      expect(list.length, B + 1);
      expect(list[B], B);
      // Internal check (optional): Verify root height is 1 if possible

      // 3. Add enough elements to potentially split internal nodes
      // Fill up to B*B elements (potentially creating a height 2 root)
      for (int i = B + 1; i < B * B; i++) {
        list = list.add(i);
      }
      expect(list.length, B * B);
      expect(list[0], 0);
      expect(list[B], B);
      expect(list[B * B - 1], B * B - 1);

      // 4. Add one more to trigger potential height 2 split
      list = list.add(B * B);
      expect(list.length, B * B + 1);
      expect(list[B * B], B * B);
    });

    test('removeAt causes node merges/rebalancing', () {
      final int B = 32; // Branching factor
      final int N =
          B * B + B ~/ 2; // Enough elements for height 2, partially filled
      ApexList<int> list = ApexList.empty();
      for (int i = 0; i < N; i++) {
        list = list.add(i);
      }
      expect(list.length, N);

      // Remove elements from the middle/beginning to trigger merges/borrows
      int currentLength = N;
      final List<int> expectedElements = List.generate(N, (i) => i);

      // Remove a significant number of elements
      final int removals =
          B * (B ~/ 2); // Remove roughly half the nodes at lowest level
      for (int i = 0; i < removals; i++) {
        // Remove from near the beginning to maximize rebalancing potential
        final removeIndex =
            i % (currentLength ~/ 4) + (B ~/ 4); // Vary index a bit

        if (removeIndex < currentLength) {
          final removedValue = expectedElements.removeAt(removeIndex);
          list = list.removeAt(removeIndex);
          currentLength--;
        }
      }

      expect(list.length, currentLength);
      // Verify the remaining elements match the expected list after removals
      expect(list, equals(expectedElements));

      // Remove almost all remaining elements
      while (currentLength > 1) {
        list = list.removeAt(0);
        expectedElements.removeAt(0);
        currentLength--;
        expect(list.length, currentLength);
      }
      expect(list[0], expectedElements[0]);

      // Remove the last element
      list = list.removeAt(0);
      expect(list.isEmpty, isTrue);
    }); // End of removeAt causes node merges/rebalancing test
  }); // End of Advanced Operations group

  group('ApexList Other Operations', () {
    test('remove element', () {
      final list1 = ApexList<String>.empty()
          .add('a')
          .add('b')
          .add('c')
          .add('b');
      final list2 = list1.remove('b'); // Removes first 'b'
      final list3 = list1.remove('d'); // Element not present

      expect(list2, equals(['a', 'c', 'b']));
      expect(list2.length, 3);
      expect(
        identical(list1, list3),
        isTrue,
      ); // Removing non-existent returns same instance
      expect(list1, equals(['a', 'b', 'c', 'b'])); // Original unchanged
    });

    test('removeWhere', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3).add(4).add(5);
      final list2 = list1.removeWhere((e) => e.isOdd);
      final list3 = list1.removeWhere((e) => e > 5); // No elements match
      final list4 = list1.removeWhere((e) => true); // Remove all

      expect(list2, equals([2, 4]));
      expect(list2.length, 2);
      expect(
        identical(list1, list3),
        isTrue,
      ); // Removing none returns same instance
      expect(list4.isEmpty, isTrue);
      expect(list1, equals([1, 2, 3, 4, 5])); // Original unchanged
    });

    test('indexOf', () {
      final list = ApexList<String>.empty()
          .add('a')
          .add('b')
          .add('c')
          .add('b')
          .add('a');
      expect(list.indexOf('a'), 0);
      expect(list.indexOf('b'), 1);
      expect(list.indexOf('c'), 2);
      expect(list.indexOf('d'), -1);
      expect(list.indexOf('a', 1), 4); // Start search from index 1
      expect(list.indexOf('b', 2), 3); // Start search from index 2
      expect(list.indexOf('a', 5), -1); // Start search past end
      expect(
        list.indexOf('a', -1),
        0,
      ); // Start search with negative index (treated as 0)
      expect(ApexList<int>.empty().indexOf(1), -1);
    });

    test('lastIndexOf', () {
      final list = ApexList<String>.empty()
          .add('a')
          .add('b')
          .add('c')
          .add('b')
          .add('a');
      expect(list.lastIndexOf('a'), 4);
      expect(list.lastIndexOf('b'), 3);
      expect(list.lastIndexOf('c'), 2);
      expect(list.lastIndexOf('d'), -1);
      expect(list.lastIndexOf('a', 3), 0); // Search up to index 3
      expect(list.lastIndexOf('b', 2), 1); // Search up to index 2
      expect(list.lastIndexOf('a', -1), -1); // Invalid start index
      expect(ApexList<int>.empty().lastIndexOf(1), -1);
    });

    test('clear', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = list1.clear();
      final list3 = ApexList<int>.empty().clear();

      expect(list2.isEmpty, isTrue);
      expect(list2.length, 0);
      expect(identical(list2, ApexList<int>.empty()), isTrue);
      expect(identical(list3, ApexList<int>.empty()), isTrue);
      expect(list1.length, 2); // Original unchanged
    });

    test('asMap', () {
      final list = ApexList<String>.empty().add('a').add('b');
      final map = list.asMap();

      expect(map, equals({0: 'a', 1: 'b'}));
      expect(map, isA<Map<int, String>>());
      // Modifying the returned map should not affect the list
      map[0] = 'Z';
      expect(list[0], 'a');
    });

    test('sort', () {
      final list1 = ApexList<int>.empty().add(3).add(1).add(4).add(2);
      final list2 = list1.sort();
      final list3 = list1.sort((a, b) => b.compareTo(a)); // Reverse sort

      expect(list2, equals([1, 2, 3, 4]));
      expect(list3, equals([4, 3, 2, 1]));
      expect(list1, equals([3, 1, 4, 2])); // Original unchanged
    });

    // Note: Shuffle tests require a fixed seed for predictability or
    // checking properties other than exact order.
    test('shuffle', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3).add(4).add(5);
      final list2 = list1.shuffle(Random(123)); // Use fixed seed
      final list3 = list1.shuffle(Random(123)); // Same seed -> same shuffle

      expect(list2.length, 5);
      expect(list2, isNot(equals([1, 2, 3, 4, 5]))); // Should be shuffled
      // Check elements by converting to sets
      expect(list2.toSet(), equals({1, 2, 3, 4, 5}));
      expect(list2, equals(list3)); // Same seed produces same result
      expect(list1, equals([1, 2, 3, 4, 5])); // Original unchanged
    });
  }); // End of Other Operations group

  group('ApexList Equality and HashCode', () {
    test('== operator', () {
      final list1a = ApexList<int>.empty().add(1).add(2).add(3);
      final list1b = ApexList<int>.empty().add(1).add(2).add(3);
      final list2 = ApexList<int>.empty().add(1).add(2).add(4); // Diff value
      final list3 = ApexList<int>.empty().add(1).add(2); // Diff length
      final list4 = ApexList<String>.empty()
          .add('1')
          .add('2')
          .add('3'); // Diff type
      final list5 = ApexList<int>.empty();

      expect(list1a == list1b, isTrue);
      expect(list1a == list2, isFalse);
      expect(list1a == list3, isFalse);
      expect(
        list1a == list4,
        isFalse,
      ); // Comparing ApexList<int> to ApexList<String>
      expect(list1a == [1, 2, 3], isFalse); // Comparing to standard List
      expect(list5 == ApexList<int>.empty(), isTrue);
      expect(list1a == list1a, isTrue); // Identity
    });

    test('hashCode consistency', () {
      final list1a = ApexList<int>.empty().add(1).add(2).add(3);
      final list1b = ApexList<int>.empty().add(1).add(2).add(3);
      final list2 = ApexList<int>.empty().add(1).add(2).add(4);
      final listEmpty = ApexList<int>.empty();

      expect(list1a.hashCode, equals(list1b.hashCode));
      expect(list1a.hashCode, isNot(equals(list2.hashCode)));
      expect(list1a.hashCode, isNot(equals(listEmpty.hashCode)));
      expect(listEmpty.hashCode, equals(ApexList<int>.empty().hashCode));
    });
  });

  group('ApexList Iterable Methods', () {
    final list = ApexList<int>.empty().add(1).add(2).add(3).add(4).add(5);

    test('where', () {
      final evens = list.where((e) => e.isEven);
      expect(evens, equals([2, 4]));
    });

    test('map', () {
      final strings = list.map((e) => 'v$e');
      expect(strings, equals(['v1', 'v2', 'v3', 'v4', 'v5']));
    });

    test('any', () {
      expect(list.any((e) => e > 3), isTrue);
      expect(list.any((e) => e > 5), isFalse);
    });

    test('every', () {
      expect(list.every((e) => e > 0), isTrue);
      expect(list.every((e) => e.isEven), isFalse);
    });

    test('take', () {
      expect(list.take(3), equals([1, 2, 3]));
      expect(list.take(0).isEmpty, isTrue);
      expect(list.take(10), equals([1, 2, 3, 4, 5])); // Take more than length
    });

    test('skip', () {
      expect(list.skip(3), equals([4, 5]));
      expect(list.skip(0), equals([1, 2, 3, 4, 5]));
      expect(list.skip(10).isEmpty, isTrue); // Skip more than length
    });

    test('fold', () {
      final sum = list.fold<int>(0, (prev, e) => prev + e);
      expect(sum, 15);
    });

    test('reduce', () {
      final sum = list.reduce((val, e) => val + e);
      expect(sum, 15);
      expect(
        () => ApexList<int>.empty().reduce((v, e) => v + e),
        throwsStateError,
      );
    });
  });
}
