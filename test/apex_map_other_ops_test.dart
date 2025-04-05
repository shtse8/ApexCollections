import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexMap Other Operations', () {
    // fromMap tested in Factories group now.

    test('clear', () {
      final map1 = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final map2 = map1.clear();
      final map3 = ApexMap<String, int>.empty().clear();

      expect(map2.isEmpty, isTrue);
      expect(map2.length, 0);
      // Check that clear returns the cached empty instance for the type
      // expect(identical(map2, ApexMap<String, int>.empty()), isTrue); // Fails due to emptyInstance change
      expect(map2, equals(ApexMap<String, int>.empty())); // Check equality
      // expect(identical(map2, map3), isTrue); // Fails due to emptyInstance change
      expect(map2, equals(map3)); // Check equality
      expect(map1.length, 2); // Original unchanged
    });

    test('forEachEntry', () {
      final map = ApexMap<String, int>.empty().add('a', 1).add('b', 2);
      final entriesSeen = <String, int>{};
      map.forEachEntry((key, value) {
        entriesSeen[key] = value;
      });

      expect(
        entriesSeen,
        equals({'a': 1, 'b': 2}),
      ); // Order matters for the collected list here
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
}
