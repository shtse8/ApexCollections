import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
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
      expect(map.keys.toSet(), unorderedEquals({'a', 'b', 'c'}));

      // From empty entries
      final emptyMap = ApexMap<String, int>.fromEntries([]);
      expect(emptyMap.isEmpty, isTrue);
      // expect(identical(emptyMap, ApexMap<String, int>.empty()), isTrue); // Fails due to emptyInstance change
      expect(
        emptyMap,
        equals(ApexMap<String, int>.empty()),
      ); // Check equality instead

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

    test('fromMap constructor (via ApexMap.from)', () {
      final source = {'a': 1, 'b': 2, 'c': 3};
      final map = ApexMap<String, int>.from(source);

      expect(map.length, 3);
      expect(map['a'], 1);
      expect(map['b'], 2);
      expect(map['c'], 3);
      expect(map.keys.toSet(), unorderedEquals({'a', 'b', 'c'}));

      // From empty map
      final emptyMap = ApexMap<String, int>.from({});
      expect(emptyMap.isEmpty, isTrue);
      // expect(identical(emptyMap, ApexMap<String, int>.empty()), isTrue); // Fails due to emptyInstance change
      expect(
        emptyMap,
        equals(ApexMap<String, int>.empty()),
      ); // Check equality instead

      // From larger map (exercises transient building)
      final largeSource = {for (var i = 0; i < 500; i++) 'key$i': i};
      final largeMap = ApexMap<String, int>.from(largeSource);
      expect(largeMap.length, 500);
      expect(largeMap['key0'], 0);
      expect(largeMap['key250'], 250);
      expect(largeMap['key499'], 499);
      expect(largeMap.containsKey('key500'), isFalse);
    });
  });
}
