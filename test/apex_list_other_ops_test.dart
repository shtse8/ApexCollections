import 'dart:math'; // For Random

import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
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
}
