import 'package:apex_collections/src/map_hamt/hamt_node.dart';
import 'package:test/test.dart';

void main() {
  group('HamtNode Tests', () {
    group('HamtEmptyNode', () {
      test('instance returns singleton', () {
        // Cannot use const with type parameters, so instances won't be identical
        // Also removed singleton, so check equality instead of identity
        expect(HamtEmptyNode<int, String>(), isA<HamtEmptyNode<int, String>>());
        expect(
          HamtEmptyNode<int, String>(),
          equals(HamtEmptyNode<int, String>()),
        );
      });

      test('isEmpty and size', () {
        final node = HamtEmptyNode<int, String>();
        expect(node.isEmpty, isTrue);
        expect(node.size, 0);
      });

      test('get returns null', () {
        final node = HamtEmptyNode<int, String>();
        expect(node.get(1, 1.hashCode, 0), isNull);
      });

      test('containsKey returns false', () {
        final node = HamtEmptyNode<int, String>();
        expect(node.containsKey(1, 1.hashCode, 0), isFalse);
      });

      test('remove returns self', () {
        final node = HamtEmptyNode<int, String>();
        final result = node.remove(1, 1.hashCode, 0, null);
        expect(result.node, same(node));
        expect(result.sizeChanged, isFalse);
        expect(result.nodeChanged, isFalse);
      });

      test('add returns DataNode', () {
        final node = HamtEmptyNode<int, String>();
        final result = node.add(1, 'a', 1.hashCode, 0, null);
        expect(result.node, isA<HamtDataNode<int, String>>());
        expect((result.node as HamtDataNode).dataKey, 1);
        expect((result.node as HamtDataNode).dataValue, 'a');
        expect(result.sizeChanged, isTrue);
        expect(result.nodeChanged, isTrue);
      });
    });

    group('HamtDataNode', () {
      final node = HamtDataNode(1.hashCode, 1, 'a');

      test('isEmpty and size', () {
        expect(node.isEmpty, isFalse);
        expect(node.size, 1);
      });

      test('get existing key', () {
        expect(node.get(1, 1.hashCode, 0), 'a');
      });

      test('get non-existing key', () {
        expect(node.get(2, 2.hashCode, 0), isNull);
      });

      test('containsKey existing key', () {
        expect(node.containsKey(1, 1.hashCode, 0), isTrue);
      });

      test('containsKey non-existing key', () {
        expect(node.containsKey(2, 2.hashCode, 0), isFalse);
      });

      test('remove existing key returns EmptyNode', () {
        final result = node.remove(1, 1.hashCode, 0, null);
        expect(result.node, isA<HamtEmptyNode<int, String>>());
        expect(result.sizeChanged, isTrue);
        expect(result.nodeChanged, isTrue);
      });

      test('remove non-existing key returns self', () {
        final result = node.remove(2, 2.hashCode, 0, null);
        expect(result.node, same(node));
        expect(result.sizeChanged, isFalse);
        expect(result.nodeChanged, isFalse);
      });

      test('add existing key with same value returns self', () {
        final result = node.add(1, 'a', 1.hashCode, 0, null);
        expect(result.node, same(node));
        expect(result.sizeChanged, isFalse);
        expect(result.nodeChanged, isFalse);
      });

      test('add existing key with different value returns new DataNode', () {
        final result = node.add(1, 'A', 1.hashCode, 0, null);
        expect(result.node, isA<HamtDataNode<int, String>>());
        expect(result.node, isNot(same(node)));
        expect((result.node as HamtDataNode).dataValue, 'A');
        expect(result.sizeChanged, isFalse); // Size didn't change, only value
        expect(result.nodeChanged, isTrue);
      });

      test('add new key with hash collision returns CollisionNode', () {
        // Force hash collision by using same hash but different key
        final result = node.add(
          10,
          'b',
          1.hashCode,
          0,
          null,
        ); // hash=1.hashCode, shift=0
        expect(result.node, isA<HamtCollisionNode<int, String>>());
        expect(result.sizeChanged, isTrue);
        expect(result.nodeChanged, isTrue);
        final collisionNode = result.node as HamtCollisionNode<int, String>;
        expect(collisionNode.size, 2);
        expect(
          collisionNode.children.any(
            (n) => n.dataKey == 1 && n.dataValue == 'a',
          ),
          isTrue,
        );
        expect(
          collisionNode.children.any(
            (n) => n.dataKey == 10 && n.dataValue == 'b',
          ),
          isTrue,
        );
      });

      test('add new key without collision returns SparseNode', () {
        final result = node.add(
          2,
          'b',
          2.hashCode,
          0,
          null,
        ); // hash=2.hashCode, shift=0
        expect(result.node, isA<HamtSparseNode<int, String>>());
        expect(result.sizeChanged, isTrue);
        expect(result.nodeChanged, isTrue);
        final sparseNode = result.node as HamtSparseNode<int, String>;
        expect(sparseNode.size, 2);
        // Further checks on sparse node structure could be added
      });
    });

    group('HamtCollisionNode', () {
      final node1 = HamtDataNode(1.hashCode, 1, 'a');
      final node2 = HamtDataNode(
        1.hashCode,
        10,
        'b',
      ); // Same hash fragment at shift 0
      final collisionNode = HamtCollisionNode(
        HamtBitmapNode.indexFragment(1.hashCode, 0),
        [node1, node2],
      );

      test('isEmpty and size', () {
        expect(collisionNode.isEmpty, isFalse);
        expect(collisionNode.size, 2);
      });

      test('get existing keys', () {
        expect(collisionNode.get(1, 1.hashCode, 0), 'a');
        expect(collisionNode.get(10, 1.hashCode, 0), 'b');
      });

      test('get non-existing key (same fragment)', () {
        expect(collisionNode.get(100, 1.hashCode, 0), isNull);
      });

      test('get non-existing key (different fragment)', () {
        expect(collisionNode.get(2, 2.hashCode, 0), isNull);
      });

      test('containsKey existing keys', () {
        expect(collisionNode.containsKey(1, 1.hashCode, 0), isTrue);
        expect(collisionNode.containsKey(10, 1.hashCode, 0), isTrue);
      });

      test('containsKey non-existing key', () {
        expect(collisionNode.containsKey(100, 1.hashCode, 0), isFalse);
        expect(collisionNode.containsKey(2, 2.hashCode, 0), isFalse);
      });

      test('add existing key with same value returns self', () {
        final result = collisionNode.add(1, 'a', 1.hashCode, 0, null);
        expect(result.node, same(collisionNode));
        expect(result.sizeChanged, isFalse);
        expect(result.nodeChanged, isFalse);
      });

      test(
        'add existing key with different value returns new CollisionNode',
        () {
          final result = collisionNode.add(1, 'A', 1.hashCode, 0, null);
          expect(result.node, isA<HamtCollisionNode<int, String>>());
          expect(result.node, isNot(same(collisionNode)));
          expect(result.sizeChanged, isFalse);
          expect(result.nodeChanged, isTrue);
          final newCollisionNode =
              result.node as HamtCollisionNode<int, String>;
          expect(newCollisionNode.size, 2);
          expect(
            newCollisionNode.children.any(
              (n) => n.dataKey == 1 && n.dataValue == 'A',
            ),
            isTrue,
          );
          expect(
            newCollisionNode.children.any(
              (n) => n.dataKey == 10 && n.dataValue == 'b',
            ),
            isTrue,
          );
        },
      );

      test('add new key with same fragment returns new CollisionNode', () {
        final result = collisionNode.add(100, 'c', 1.hashCode, 0, null);
        expect(result.node, isA<HamtCollisionNode<int, String>>());
        expect(result.sizeChanged, isTrue);
        expect(result.nodeChanged, isTrue);
        final newCollisionNode = result.node as HamtCollisionNode<int, String>;
        expect(newCollisionNode.size, 3);
        expect(
          newCollisionNode.children.any(
            (n) => n.dataKey == 100 && n.dataValue == 'c',
          ),
          isTrue,
        );
      });

      test('add new key with different fragment returns SparseNode', () {
        final result = collisionNode.add(2, 'c', 2.hashCode, 0, null);
        expect(result.node, isA<HamtSparseNode<int, String>>());
        expect(
          result.sizeChanged,
          isTrue,
        ); // Size increases by 1 (new node added)
        expect(result.nodeChanged, isTrue);
        final sparseNode = result.node as HamtSparseNode<int, String>;
        expect(
          sparseNode.size,
          3,
        ); // Collision node (size 2) + new data node (size 1)
      });

      test('remove existing key (leaves > 1) returns new CollisionNode', () {
        final node3 = HamtDataNode(1.hashCode, 100, 'c');
        final collisionNode3 = HamtCollisionNode(
          HamtBitmapNode.indexFragment(1.hashCode, 0),
          [node1, node2, node3],
        );
        final result = collisionNode3.remove(10, 1.hashCode, 0, null);
        expect(result.node, isA<HamtCollisionNode<int, String>>());
        expect(result.sizeChanged, isTrue);
        expect(result.nodeChanged, isTrue);
        final newCollisionNode = result.node as HamtCollisionNode<int, String>;
        expect(newCollisionNode.size, 2);
        expect(newCollisionNode.children.any((n) => n.dataKey == 10), isFalse);
      });

      test('remove existing key (leaves 1) returns DataNode', () {
        final result = collisionNode.remove(10, 1.hashCode, 0, null);
        expect(result.node, isA<HamtDataNode<int, String>>());
        expect(result.sizeChanged, isTrue);
        expect(result.nodeChanged, isTrue);
        final dataNode = result.node as HamtDataNode<int, String>;
        expect(dataNode.dataKey, 1);
        expect(dataNode.dataValue, 'a');
      });

      test('remove non-existing key returns self', () {
        final result = collisionNode.remove(100, 1.hashCode, 0, null);
        expect(result.node, same(collisionNode));
        expect(result.sizeChanged, isFalse);
        expect(result.nodeChanged, isFalse);
      });
    });

    // TODO: Add tests for HamtSparseNode (add, remove, containsKey, get, transient)
    // TODO: Add tests for node transitions (Sparse -> Array, Array -> Sparse) if ArrayNode is implemented
    // TODO: Add tests for deeper trees (multiple levels)
  });
}
