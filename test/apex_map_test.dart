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
  // TODO: Add groups for non-empty map operations (get, update, add, remove, etc.)
}
