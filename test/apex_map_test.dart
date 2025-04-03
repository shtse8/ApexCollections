import 'package:apex_collections/apex_collections.dart'; // Assuming this exports ApexMap
import 'package:test/test.dart';

void main() {
  group('ApexMap Empty', () {
    test('empty() constructor creates an empty map', () {
      final map = ApexMap<String, int>.empty();
      expect(map.isEmpty, isTrue);
      expect(map.isNotEmpty, isFalse);
      expect(map.length, 0);
      expect(map.keys, isEmpty);
      expect(map.values, isEmpty);
      expect(map.entries, isEmpty);
    });

    test('empty map returns null for lookups', () {
      final map = ApexMap<String, int>.empty();
      expect(map['a'], isNull);
      expect(map.containsKey('a'), isFalse);
      expect(map.containsValue(1), isFalse);
    });

    test('empty map iterator has no elements', () {
      final map = ApexMap<String, int>.empty();
      final iterator = map.iterator;
      expect(iterator.moveNext(), isFalse);
    });

    test('empty map equality', () {
      final map1 = ApexMap<int, String>.empty();
      final map2 = ApexMap<String, int>.empty(); // Different type args
      final map3 = ApexMap<int, String>.empty(); // No longer const

      expect(map1, equals(ApexMap<int, String>.empty()));
      expect(map1, equals(map2)); // Should be equal despite type args
      expect(map1, equals(map3));
      expect(map1 == map3, isTrue); // Const instances should be identical
    });

    test('empty map hashCode', () {
      expect(ApexMap.empty().hashCode, equals(ApexMap.empty().hashCode));
      // TODO: Define expected hash code for empty map (e.g., 0 or based on MapEquality)
    });

    // TODO: Add tests for modification methods on empty map (add, update, remove, etc.)
    // TODO: Add tests for Iterable methods on empty map (map, where, etc.)
  });

  // TODO: Add groups for ApexMap.from(), ApexMap.fromEntries()

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
      expect(map1.entries.first, equals(const MapEntry('a', 1)));

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
      expect(map.keys.toSet(), equals({'a', 'b', 'c'}));
      expect(map.values.toSet(), equals({1, 2, 3}));
      expect(
        map.entries.toSet(),
        equals({
          const MapEntry('a', 1),
          const MapEntry('b', 2),
          const MapEntry('c', 3),
        }),
      );
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
      expect(map2.keys.toSet(), equals({'a', 'c'}));
      expect(map2.values.toSet(), equals({1, 3}));

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
      // Note: Checking identical(map2, emptyMap) might fail if empty isn't canonical internally yet
    });

    test('equality and hashCode for non-empty maps', () {
      final map1a = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final map1b = ApexMap<String, int>.empty()
          .add('b', 2)
          .add('a', 1); // Same elements, different order
      final map2 = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('c', 3); // Different elements
      final map3 = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('b', 2); // Same as map1a

      // Equality
      expect(map1a == map1b, isTrue); // Order shouldn't matter for equality
      expect(map1a == map3, isTrue);
      expect(map1a == map2, isFalse);
      expect(map1a == ApexMap<String, int>.empty(), isFalse);
      expect(map1a == {'a': 1, 'b': 2}, isFalse); // Different type

      // HashCode
      expect(
        map1a.hashCode,
        equals(map1b.hashCode),
      ); // Hash codes must be equal for equal objects
      expect(map1a.hashCode, equals(map3.hashCode));
      // Hash codes *might* collide for non-equal objects, but shouldn't for these simple cases
      expect(map1a.hashCode, isNot(equals(map2.hashCode)));
      expect(map1a.hashCode, isNot(equals(ApexMap.empty().hashCode)));
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
      expect(map2.keys.toSet(), equals({'a', 'c'}));
      expect(map2.values.toSet(), equals({1, 3}));
      expect(map1.length, 4); // Original unchanged

      // Remove based on key
      final map3 = map1.removeWhere((key, value) => key == 'a' || key == 'd');
      expect(map3.length, 2);
      expect(map3.keys.toSet(), equals({'b', 'c'}));
      expect(map3.values.toSet(), equals({2, 3}));

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
      // Check if it returns the canonical empty instance (might depend on implementation)
      // expect(identical(map5, ApexMap<String, int>.empty()), isTrue);
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
      final expectedEntries = {
        const MapEntry(1, 'A'),
        const MapEntry(15, 'o'),
        const MapEntry(20, 't'),
      };

      expect(map.length, 3);
      expect(map.entries.toSet(), equals(expectedEntries));

      // Check iterator yields correct elements
      final iteratedEntries = <MapEntry<int, String>>[];
      final iterator = map.iterator;
      while (iterator.moveNext()) {
        iteratedEntries.add(iterator.current);
      }
      expect(iteratedEntries.toSet(), equals(expectedEntries));
    });
    // TODO: Add tests for more complex iterator scenarios (e.g., after removals)
  });
}
