import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

import 'apex_map_test_utils.dart'; // Import the helper class

void main() {
  group('ApexMap Hash Collision Operations', () {
    final collider1a = HashCollider('1a', 100);
    final collider1b = HashCollider('1b', 100); // Same hash, different object
    final collider2 = HashCollider('2', 200);
    final collider3a = HashCollider('3a', 100); // Same hash as 1a/1b

    test('add with collisions', () {
      final map0 = ApexMap<HashCollider, int>.empty();
      final map1 = map0.add(collider1a, 1);
      final map2 = map1.add(collider2, 2);
      final map3 = map2.add(collider1b, 10); // Collision with 1a
      final map4 = map3.add(collider3a, 3); // Collision with 1a/1b

      expect(map4.length, 4);
      expect(map4[collider1a], 1);
      expect(map4[collider1b], 10);
      expect(map4[collider2], 2);
      expect(map4[collider3a], 3);
      expect(map4.entries.length, 4); // Ensure iterator works
    });

    test('update with collisions', () {
      final map = ApexMap<HashCollider, int>.empty()
          .add(collider1a, 1)
          .add(collider1b, 10)
          .add(collider2, 2);

      // Update existing colliding key
      final mapUpdated1b = map.update(collider1b, (v) => v + 100);
      expect(mapUpdated1b.length, 3);
      expect(mapUpdated1b[collider1a], 1);
      expect(mapUpdated1b[collider1b], 110);
      expect(mapUpdated1b[collider2], 2);

      // Update non-existent colliding key with ifAbsent
      final mapUpdated3a = map.update(
        collider3a,
        (v) => v + 1,
        ifAbsent: () => 3,
      );
      expect(mapUpdated3a.length, 4);
      expect(mapUpdated3a[collider1a], 1);
      expect(mapUpdated3a[collider1b], 10);
      expect(mapUpdated3a[collider2], 2);
      expect(mapUpdated3a[collider3a], 3);

      // Update non-existent colliding key without ifAbsent (no change)
      final mapUpdated3aNoAdd = map.update(collider3a, (v) => v + 1);
      expect(identical(map, mapUpdated3aNoAdd), isTrue);
    });

    test('remove with collisions', () {
      final map = ApexMap<HashCollider, int>.empty()
          .add(collider1a, 1)
          .add(collider1b, 10)
          .add(collider2, 2)
          .add(collider3a, 3); // 1a, 1b, 3a collide

      // Remove one of the colliding keys
      final mapRemoved1b = map.remove(collider1b);
      expect(mapRemoved1b.length, 3);
      expect(mapRemoved1b[collider1a], 1);
      expect(mapRemoved1b.containsKey(collider1b), isFalse);
      expect(mapRemoved1b[collider2], 2);
      expect(mapRemoved1b[collider3a], 3);

      // Remove another colliding key
      final mapRemoved1a = mapRemoved1b.remove(collider1a);
      expect(mapRemoved1a.length, 2);
      expect(mapRemoved1a.containsKey(collider1a), isFalse);
      expect(mapRemoved1a.containsKey(collider1b), isFalse);
      expect(mapRemoved1a[collider2], 2);
      expect(mapRemoved1a[collider3a], 3);

      // Remove the last colliding key
      final mapRemoved3a = mapRemoved1a.remove(collider3a);
      expect(mapRemoved3a.length, 1);
      expect(mapRemoved3a.containsKey(collider1a), isFalse);
      expect(mapRemoved3a.containsKey(collider1b), isFalse);
      expect(mapRemoved3a[collider2], 2);
      expect(mapRemoved3a.containsKey(collider3a), isFalse);

      // Remove non-colliding key
      final mapRemoved2 = mapRemoved3a.remove(collider2);
      expect(mapRemoved2.isEmpty, isTrue);
      // Check equality instead of identity
      expect(mapRemoved2, equals(ApexMap<HashCollider, int>.empty()));

      // Remove non-existent colliding key (no change)
      final mapRemovedNonExistent = map.remove(HashCollider('4a', 100));
      expect(identical(map, mapRemovedNonExistent), isTrue);
    });

    test('iterator with hash collisions', () {
      // This test was already present and is good, keep it.
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
      // Compare keys and values separately
      expect(
        entriesSet.map((e) => e.key).toSet(),
        unorderedEquals({collider1a, collider1b, collider2, collider3a}),
      );
      expect(
        entriesSet.map((e) => e.value).toSet(),
        unorderedEquals({1, 10, 2, 3}),
      );
      expect(entriesSet.length, 4); // Ensure all distinct entries were iterated
    });
  }); // End Hash Collision Operations
}
