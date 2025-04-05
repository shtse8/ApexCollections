import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexMap Iterable Methods', () {
    final map = ApexMap<String, int>.empty()
        .add('a', 1)
        .add('b', 2)
        .add('c', 3);

    test('where', () {
      final filtered = map.where((e) => e.value.isEven || e.key == 'a');
      // Use sets for order-independent comparison
      // Compare keys and values separately
      expect(filtered.map((e) => e.key).toSet(), unorderedEquals({'a', 'b'}));
      expect(filtered.map((e) => e.value).toSet(), unorderedEquals({1, 2}));
    });

    test('map', () {
      final mapped = map.map((e) => '${e.key}:${e.value}');
      // Use sets for order-independent comparison
      expect(mapped.toSet(), unorderedEquals({'a:1', 'b:2', 'c:3'}));
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
      // Example: combine values (order independent)
      final sum =
          map.reduce((val, e) => MapEntry(val.key, val.value + e.value)).value;
      expect(sum, 6); // 1 + 2 + 3
      expect(
        () => ApexMap<String, int>.empty().reduce((v, e) => v),
        throwsStateError,
      );
    });

    test('toList', () {
      final list = map.toList();
      expect(list, isA<List<MapEntry<String, int>>>());
      expect(list.length, 3);
      // Use sets for order-independent comparison
      // Compare keys and values separately
      expect(list.map((e) => e.key).toSet(), unorderedEquals({'a', 'b', 'c'}));
      expect(list.map((e) => e.value).toSet(), unorderedEquals({1, 2, 3}));
    });

    test('toSet', () {
      final set = map.toSet();
      expect(set, isA<Set<MapEntry<String, int>>>());
      expect(set.length, 3);
      // Compare keys and values separately
      expect(set.map((e) => e.key).toSet(), unorderedEquals({'a', 'b', 'c'}));
      expect(set.map((e) => e.value).toSet(), unorderedEquals({1, 2, 3}));
    });

    test('contains (MapEntry)', () {
      expect(map.contains(const MapEntry('a', 1)), isTrue);
      expect(map.contains(const MapEntry('b', 2)), isTrue);
      expect(map.contains(const MapEntry('c', 3)), isTrue);
      expect(map.contains(const MapEntry('a', 10)), isFalse); // Wrong value
      expect(map.contains(const MapEntry('d', 1)), isFalse); // Wrong key
      expect(map.contains('a'), isFalse); // Wrong type
    });
  }); // End Iterable Methods
}
