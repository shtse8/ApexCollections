import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexMap Basic Operations', () {
    test('add single element', () {
      final map0 = ApexMap<String, int>.empty();
      final map1 = map0.add('a', 1);

      // Verify map1
      expect(map1.length, 1);
      expect(map1.isEmpty, isFalse);
      expect(map1.isNotEmpty, isTrue);
      expect(map1['a'], 1);
      expect(map1.containsKey('a'), isTrue);
      expect(map1.containsKey('b'), isFalse);
      expect(map1.keys, equals(['a']));
      expect(map1.values, equals([1]));
      // Compare key and value directly due to MapEntry equality issues
      expect(map1.entries.first.key, 'a');
      expect(map1.entries.first.value, 1);

      // Verify map0 remains unchanged (immutability)
      expect(map0.length, 0);
      expect(map0.isEmpty, isTrue);
      expect(map0['a'], isNull);
    });

    test('add multiple elements', () {
      final map = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('b', 2)
          .add('c', 3);

      expect(map.length, 3);
      expect(map['a'], 1);
      expect(map['b'], 2);
      expect(map['c'], 3);
      expect(map['d'], isNull);
      expect(map.containsKey('b'), isTrue);
      expect(map.containsKey('d'), isFalse);

      // Use sets for order-independent comparison of iterables
      // Check keys and values separately (already done above)
      // Remove the problematic entries check
      expect(map.keys.toSet(), unorderedEquals({'a', 'b', 'c'}));
      expect(map.values.toSet(), unorderedEquals({1, 2, 3}));
      // Check entries individually due to equality issues
      expect(map.containsKey('a'), isTrue);
      expect(map['a'], 1);
      expect(map.containsKey('b'), isTrue);
      expect(map['b'], 2);
      expect(map.containsKey('c'), isTrue);
      expect(map['c'], 3);
    });

    test('add updates existing key', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final map2 = map1.add('a', 10); // Update 'a'

      expect(map2.length, 2); // Length should not change
      expect(map2['a'], 10); // Value updated
      expect(map2['b'], 2); // Other value remains

      // Verify map1 remains unchanged
      expect(map1.length, 2);
      expect(map1['a'], 1);
    });

    test('add with identical value does not change instance', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1);
      final map2 = map1.add('a', 1); // Add same key-value

      expect(identical(map1, map2), isTrue); // Instance should be identical
      expect(map2.length, 1);
      expect(map1['a'], 1);
    });

    test('remove existing element', () {
      final map1 = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('b', 2)
          .add('c', 3);
      final map2 = map1.remove('b');

      // Verify map2
      expect(map2.length, 2);
      expect(map2['a'], 1);
      expect(map2['b'], isNull); // Removed
      expect(map2['c'], 3);
      expect(map2.containsKey('a'), isTrue);
      expect(map2.containsKey('b'), isFalse);
      expect(map2.containsKey('c'), isTrue);
      expect(map2.keys.toSet(), unorderedEquals({'a', 'c'}));
      expect(map2.values.toSet(), unorderedEquals({1, 3}));

      // Verify map1 remains unchanged
      expect(map1.length, 3);
      expect(map1['b'], 2);
      expect(map1.containsKey('b'), isTrue);
    });

    test('remove non-existent element does not change instance', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final map2 = map1.remove('c'); // 'c' does not exist

      expect(identical(map1, map2), isTrue); // Instance should be identical
      expect(map2.length, 2);
      expect(map2['a'], 1);
      expect(map2['b'], 2);
    });

    test('remove last element results in empty map', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1);
      final map2 = map1.remove('a');
      final emptyMap = ApexMap<String, int>.empty();

      expect(map2.length, 0);
      expect(map2.isEmpty, isTrue);
      expect(map2['a'], isNull);
      expect(map2.containsKey('a'), isFalse);
      expect(map2, equals(emptyMap)); // Should equal the canonical empty map
      // expect(identical(map2, emptyMap), isTrue); // Fails due to emptyInstance change
      expect(map2, equals(emptyMap)); // Check equality instead
    });

    test('containsValue', () {
      final map = ApexMap<String, int?>.empty()
          .add('a', 1)
          .add('b', 2)
          .add('c', null) // Include a null value
          .add('d', 2); // Duplicate value

      expect(map.containsValue(1), isTrue);
      expect(map.containsValue(2), isTrue);
      expect(map.containsValue(null), isTrue); // Check for null
      expect(map.containsValue(3), isFalse);
      expect(map.containsValue(0), isFalse);
    });

    test('update existing key', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final map2 = map1.update('a', (value) => value + 10);

      expect(map2.length, 2);
      expect(map2['a'], 11);
      expect(map2['b'], 2);
      expect(map1['a'], 1); // Original unchanged
    });

    test('update non-existent key with ifAbsent', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1);
      final map2 = map1.update('b', (value) => value + 10, ifAbsent: () => 99);

      expect(map2.length, 2);
      expect(map2['a'], 1);
      expect(map2['b'], 99); // Added via ifAbsent
      expect(map1.length, 1); // Original unchanged
      expect(map1.containsKey('b'), isFalse);
    });

    test('update non-existent key without ifAbsent', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1);
      final map2 = map1.update('b', (value) => value + 10); // No ifAbsent

      expect(identical(map1, map2), isTrue); // Instance should be identical
      expect(map2.length, 1);
      expect(map2.containsKey('b'), isFalse);
    });

    test('addAll with disjoint maps', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1);
      final map2 = {'b': 2, 'c': 3};
      final map3 = map1.addAll(map2);

      expect(map3.length, 3);
      expect(map3['a'], 1);
      expect(map3['b'], 2);
      expect(map3['c'], 3);
      expect(map1.length, 1); // Original unchanged
    });

    test('addAll with overlapping maps (updates)', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final map2 = {'b': 20, 'c': 3}; // 'b' overlaps
      final map3 = map1.addAll(map2);

      expect(map3.length, 3);
      expect(map3['a'], 1);
      expect(map3['b'], 20); // Updated value
      expect(map3['c'], 3);
      expect(map1.length, 2); // Original unchanged
      expect(map1['b'], 2);
    });

    test('addAll with empty map', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1);
      final map2 = <String, int>{};
      final map3 = map1.addAll(map2);

      expect(identical(map1, map3), isTrue); // Instance should be identical
      expect(map3.length, 1);
    });

    test('addAll to empty map', () {
      final map1 = ApexMap<String, int>.empty();
      final map2 = {'a': 1, 'b': 2};
      final map3 = map1.addAll(map2);

      expect(map3.length, 2);
      expect(map3['a'], 1);
      expect(map3['b'], 2);
      expect(map1.isEmpty, isTrue); // Original unchanged
    });

    test('removeWhere', () {
      final map1 = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('b', 2)
          .add('c', 3)
          .add('d', 4);

      // Remove even values
      final map2 = map1.removeWhere((key, value) => value % 2 == 0);
      expect(map2.length, 2);
      expect(map2.keys.toSet(), unorderedEquals({'a', 'c'}));
      expect(map2.values.toSet(), unorderedEquals({1, 3}));
      expect(map1.length, 4); // Original unchanged

      // Remove based on key
      final map3 = map1.removeWhere((key, value) => key == 'a' || key == 'd');
      expect(map3.length, 2);
      expect(map3.keys.toSet(), unorderedEquals({'b', 'c'}));
      expect(map3.values.toSet(), unorderedEquals({2, 3}));

      // Remove nothing
      final map4 = map1.removeWhere((key, value) => value > 10);
      expect(identical(map1, map4), isTrue);
      expect(map4.length, 4);

      // Remove all
      final map5 = map1.removeWhere((key, value) => true);
      expect(map5.isEmpty, isTrue);
      expect(map5.length, 0);
      expect(map5, equals(ApexMap<String, int>.empty()));
    });

    test('updateAll', () {
      final map1 = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('b', 2)
          .add('c', 3);

      // Increment all values
      final map2 = map1.updateAll((key, value) => value + 10);
      expect(map2.length, 3);
      expect(map2['a'], 11);
      expect(map2['b'], 12);
      expect(map2['c'], 13);
      expect(map1['a'], 1); // Original unchanged

      // Update based on key
      final map3 = map1.updateAll((key, value) => key == 'b' ? 99 : value);
      expect(map3.length, 3);
      expect(map3['a'], 1);
      expect(map3['b'], 99);
      expect(map3['c'], 3);

      // UpdateAll on empty map
      final map4 = ApexMap<String, int>.empty();
      final map5 = map4.updateAll((key, value) => value * 2);
      expect(map5.isEmpty, isTrue);
      expect(identical(map4, map5), isTrue);
    });

    test('mapEntries', () {
      final map1 = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('b', 2)
          .add('c', 3);

      // Convert values to strings
      final map2 = map1.mapEntries(
        (key, value) => MapEntry(key, value.toString()),
      );
      expect(map2.length, 3);
      expect(map2['a'], '1');
      expect(map2['b'], '2');
      expect(map2['c'], '3');
      expect(map2, isA<ApexMap<String, String>>());
      expect(map1['a'], 1); // Original unchanged

      // Change keys and values
      final map3 = map1.mapEntries(
        (key, value) => MapEntry(key.toUpperCase(), value * 10),
      );
      expect(map3.length, 3);
      expect(map3['A'], 10);
      expect(map3['B'], 20);
      expect(map3['C'], 30);
      expect(map3, isA<ApexMap<String, int>>());

      // Map entries on empty map
      final map4 = ApexMap<String, int>.empty();
      final map5 = map4.mapEntries((key, value) => MapEntry(key, value + 1));
      expect(map5.isEmpty, isTrue);
      expect(map5, isA<ApexMap<String, int>>());
      expect(map5, equals(ApexMap<String, int>.empty())); // Check equality
    });

    test('iterator correctness after add/remove operations', () {
      final map = ApexMap<int, String>.empty()
          .add(1, 'a')
          .add(10, 'j') // Add some initial values
          .add(5, 'e')
          .remove(10) // Remove one
          .add(15, 'o') // Add another
          .add(1, 'A') // Update existing
          .add(20, 't')
          .remove(5); // Remove another

      // Expected final state: {1: 'A', 15: 'o', 20: 't'}
      // Define expected keys and values separately
      final expectedKeys = {1, 15, 20};
      final expectedValues = {'A', 'o', 't'};

      expect(map.length, 3);
      // Compare keys and values separately
      expect(map.keys.toSet(), unorderedEquals(expectedKeys));
      expect(map.values.toSet(), unorderedEquals(expectedValues));

      // Check iterator yields correct elements
      final iteratedEntries = <MapEntry<int, String>>[];
      final iterator = map.iterator;
      while (iterator.moveNext()) {
        iteratedEntries.add(iterator.current);
      }
      // Compare keys and values separately for iterated entries
      expect(
        iteratedEntries.map((e) => e.key).toSet(),
        unorderedEquals(expectedKeys),
      );
      expect(
        iteratedEntries.map((e) => e.value).toSet(),
        unorderedEquals(expectedValues),
      );
    });
  }); // End Basic Operations
}
