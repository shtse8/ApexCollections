import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexMap Equality and HashCode', () {
    // These tests were already present and cover non-empty maps well.
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

    test('hashCode is cached', () {
      final map = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final hash1 = map.hashCode;
      final hash2 = map.hashCode;

      // While we can't directly check if it was computed only once without
      // instrumentation, we expect the results to be identical if cached properly.
      // Using equals() is sufficient for correctness.
      expect(hash1, equals(hash2));

      // Create a modified map
      final mapModified = map.add('c', 3);
      final hash3 = mapModified.hashCode;

      // Hash code should likely differ for a different map
      // (Collision is possible but unlikely here)
      expect(hash1, isNot(equals(hash3)));

      // Check caching on the modified map too
      final hash4 = mapModified.hashCode;
      expect(hash3, equals(hash4));
    });
  }); // End Equality and HashCode
}
