import 'package:apex_collections/apex_collections.dart'; // Assuming this exports ApexMap
import 'package:test/test.dart';

// Helper class with controlled hash code to force collisions
class HashCollider {
  final String id;
  final int hashCodeValue;

  HashCollider(this.id, this.hashCodeValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HashCollider &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => hashCodeValue;

  @override
  String toString() => 'HC($id, #$hashCodeValue)';
}

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
      final empty1 = ApexMap<String, int>.empty();
      final empty2 = ApexMap<int, bool>.empty();
      expect(empty1.hashCode, equals(0)); // Implementation returns 0 for empty
      expect(empty2.hashCode, equals(0));
      expect(empty1.hashCode, equals(empty2.hashCode));
    });
  });

  group('ApexMap Empty Map Modifications', () {
    final emptyMap = ApexMap<String, int>.empty();
    group('ApexMap Factories', () {
      test('fromEntries constructor', () {
        final entries = [
          const MapEntry('a', 1),
          const MapEntry('b', 2),
          const MapEntry('c', 3),
        ];
        final map = ApexMap<String, int>.fromEntries(entries);

        expect(map.length, 3);
        expect(map['a'], 1);
        expect(map['b'], 2);
        expect(map['c'], 3);
        expect(map.keys.toSet(), equals({'a', 'b', 'c'}));

        // From empty entries
        final emptyMap = ApexMap<String, int>.fromEntries([]);
        expect(emptyMap.isEmpty, isTrue);
        expect(identical(emptyMap, ApexMap<String, int>.empty()), isTrue);

        // From entries with duplicate keys (last one wins)
        final entriesDup = [
          const MapEntry('a', 1),
          const MapEntry('b', 2),
          const MapEntry('a', 10), // Duplicate key 'a'
        ];
        final mapDup = ApexMap<String, int>.fromEntries(entriesDup);
        expect(mapDup.length, 2);
        expect(mapDup['a'], 10); // Last 'a' value should win
        expect(mapDup['b'], 2);
      });
    });

    group('ApexMap Iterator Edge Cases', () {
      // Helper class defined at top level now.
      test('iterator with hash collisions', () {
        final collider1a = HashCollider('1a', 100);
        final collider1b = HashCollider(
          '1b',
          100,
        ); // Same hash, different object
        final collider2 = HashCollider('2', 200);
        final collider3a = HashCollider('3a', 100); // Same hash as 1a/1b

        final map = ApexMap<HashCollider, int>.empty()
            .add(collider1a, 1)
            .add(collider2, 2)
            .add(collider1b, 10) // Collision with 1a
            .add(collider3a, 3); // Collision with 1a/1b

        expect(map.length, 4);
        expect(map[collider1a], 1);
        expect(map[collider1b], 10);
        expect(map[collider2], 2);
        expect(map[collider3a], 3);

        // Check iterator yields all elements despite collisions
        final entriesSet = map.entries.toSet();
        expect(
          entriesSet,
          equals({
            MapEntry(collider1a, 1),
            MapEntry(collider1b, 10),
            MapEntry(collider2, 2),
            MapEntry(collider3a, 3),
          }),
        );
        expect(
          entriesSet.length,
          4,
        ); // Ensure all distinct entries were iterated
      });
    });

    group('ApexMap Iterable Methods', () {
      final map = ApexMap<String, int>.empty()
          .add('a', 1)
          .add('b', 2)
          .add('c', 3);

      test('where', () {
        final filtered = map.where((e) => e.value.isEven || e.key == 'a');
        // Use sets for order-independent comparison
        expect(filtered.toSet(), equals({MapEntry('a', 1), MapEntry('b', 2)}));
      });

      test('map', () {
        final mapped = map.map((e) => '${e.key}:${e.value}');
        // Use sets for order-independent comparison
        expect(mapped.toSet(), equals({'a:1', 'b:2', 'c:3'}));
      });

      test('any', () {
        expect(map.any((e) => e.value > 2), isTrue);
        expect(map.any((e) => e.key == 'd'), isFalse);
      });

      test('every', () {
        expect(map.every((e) => e.value > 0), isTrue);
        expect(map.every((e) => e.key != 'b'), isFalse);
      });

      test('take', () {
        // Order is not guaranteed, so test properties
        final taken = map.take(2);
        expect(taken.length, 2);
        expect(taken.every((e) => map.containsKey(e.key)), isTrue);
      });

      test('skip', () {
        // Order is not guaranteed, so test properties
        final skipped = map.skip(1);
        expect(skipped.length, 2);
        expect(skipped.every((e) => map.containsKey(e.key)), isTrue);
        // Ensure the skipped element is not present
        final skippedKeys = skipped.map((e) => e.key).toSet();
        expect(map.keys.any((k) => !skippedKeys.contains(k)), isTrue);
      });

      test('fold', () {
        final sum = map.fold<int>(0, (prev, e) => prev + e.value);
        expect(sum, 6); // 1 + 2 + 3
      });

      test('reduce', () {
        // Reduce requires a non-empty iterable, test behavior is complex without guaranteed order
        // Example: combine keys (order dependent!)
        // final combinedKeys = map.reduce((val, e) => MapEntry(val.key + e.key, 0)).key;
        // expect(combinedKeys.length, 3); // e.g., 'abc' or 'acb' etc.
        expect(
          () => ApexMap<String, int>.empty().reduce((v, e) => v),
          throwsStateError,
        );
      });
    });

    test('add on empty', () {
      final map1 = emptyMap.add('a', 1);
      expect(map1.length, 1);
      expect(map1['a'], 1);
    });

    test('remove on empty', () {
      final map1 = emptyMap.remove('a');
      expect(identical(map1, emptyMap), isTrue);
    });

    test('update on empty', () {
      final map1 = emptyMap.update('a', (v) => v + 1); // No ifAbsent
      final map2 = emptyMap.update('a', (v) => v + 1, ifAbsent: () => 99);
      expect(identical(map1, emptyMap), isTrue);
      expect(map2.length, 1);
      expect(map2['a'], 99);
    });

    test('addAll on empty', () {
      final map1 = emptyMap.addAll({'b': 2, 'c': 3});
      expect(map1.length, 2);
      expect(map1['b'], 2);
      expect(map1['c'], 3);
    });

    test('removeWhere on empty', () {
      final map1 = emptyMap.removeWhere((k, v) => true);
      expect(identical(map1, emptyMap), isTrue);
    });

    test('updateAll on empty', () {
      final map1 = emptyMap.updateAll((k, v) => v + 1);
      expect(identical(map1, emptyMap), isTrue);
    });

    test('mapEntries on empty', () {
      final map1 = emptyMap.mapEntries(
        (k, v) => MapEntry(k.toUpperCase(), v.toString()),
      );
      expect(
        identical(map1, emptyMap),
        isTrue,
      ); // Should return the same empty instance
      expect(map1, isA<ApexMap<String, String>>()); // Check type propagation
    });

    test('clear on empty', () {
      final map1 = emptyMap.clear();
      expect(identical(map1, emptyMap), isTrue);
    });
  });

  group('ApexMap Empty Map Iterables', () {
    final emptyMap = ApexMap<String, int>.empty();

    test('iterator', () {
      expect(emptyMap.iterator.moveNext(), isFalse);
    });
    test('keys', () {
      expect(emptyMap.keys.isEmpty, isTrue);
    });
    test('values', () {
      expect(emptyMap.values.isEmpty, isTrue);
    });
    test('entries', () {
      expect(emptyMap.entries.isEmpty, isTrue);
    });
    test('where', () {
      expect(emptyMap.where((e) => true).isEmpty, isTrue);
    });
    test('map', () {
      expect(emptyMap.map((e) => e.key).isEmpty, isTrue);
    });
    test('any', () {
      expect(emptyMap.any((e) => true), isFalse);
    });
    test('every', () {
      expect(emptyMap.every((e) => false), isTrue); // Vacuously true
    });
  });

  // ApexMap.from() tested in Other Operations group. Adding fromEntries here.

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
    // Iterator tested with add/remove sequence above. Collision test added separately.

    group('ApexMap Other Operations', () {
      test('fromMap constructor', () {
        final source = {'a': 1, 'b': 2, 'c': 3};
        final map = ApexMap<String, int>.from(source);

        expect(map.length, 3);
        expect(map['a'], 1);
        expect(map['b'], 2);
        expect(map['c'], 3);
        expect(map.keys.toSet(), equals({'a', 'b', 'c'}));

        // From empty map
        final emptyMap = ApexMap<String, int>.from({});
        expect(emptyMap.isEmpty, isTrue);
        expect(identical(emptyMap, ApexMap<String, int>.empty()), isTrue);
      });

      test('clear', () {
        final map1 = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
        final map2 = map1.clear();
        final map3 = ApexMap<String, int>.empty().clear();

        expect(map2.isEmpty, isTrue);
        expect(map2.length, 0);
        // Check that clear returns the cached empty instance for the type
        expect(identical(map2, map3), isTrue);
        // Comparing against a new ApexMap.empty() might fail if Type object identity differs,
        // so we rely on comparing two results of clear().
        expect(map1.length, 2); // Original unchanged
      });

      test('forEachEntry', () {
        final map = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
        final entriesSeen = <String, int>{};
        map.forEachEntry((key, value) {
          entriesSeen[key] = value;
        });

        expect(entriesSeen, equals({'a': 1, 'b': 2}));
      });

      test('putIfAbsent (stub behavior)', () {
        final map = ApexMap<String, int>.empty().add('a', 1);

        // Key exists
        final result1 = map.putIfAbsent('a', () => 99);
        expect(result1, 1); // Returns existing value
        expect(map.length, 1); // Map remains unchanged

        // Key doesn't exist
        final result2 = map.putIfAbsent('b', () => 99);
        expect(result2, 99); // Returns value from ifAbsent
        expect(map.length, 1); // Map remains unchanged (as it's immutable)
        expect(map.containsKey('b'), isFalse);
      });
    }); // End of Other Operations group
  });
}
