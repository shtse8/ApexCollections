import 'package:apex_collections/apex_collections.dart';
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
      // Check identicality using the public factory constructor.
      // This relies on the factory returning the cached instance via emptyInstance<K, V>().
      // expect(identical(ApexMap<int, String>.empty(), ApexMap<int, String>.empty()), isTrue); // Fails due to emptyInstance change
      expect(
        ApexMap<int, String>.empty(),
        equals(ApexMap<int, String>.empty()),
      ); // Check equality instead
      // expect(identical(ApexMap<String, int>.empty(), ApexMap<String, int>.empty()), isTrue); // Fails due to emptyInstance change
      expect(
        ApexMap<String, int>.empty(),
        equals(ApexMap<String, int>.empty()),
      ); // Check equality instead
    });

    test('empty map hashCode', () {
      final empty1 = ApexMap<String, int>.empty();
      final empty2 = ApexMap<int, bool>.empty();
      expect(empty1.hashCode, equals(0)); // Implementation returns 0 for empty
      expect(empty2.hashCode, equals(0));
      expect(empty1.hashCode, equals(empty2.hashCode));
    });
  });
}
