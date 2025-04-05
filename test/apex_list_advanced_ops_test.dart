import 'package:apex_collections/apex_collections.dart';
import 'package:apex_collections/src/list/apex_list.dart'; // For ApexListImpl
import 'package:apex_collections/src/list/rrb_node.dart'
    as rrb; // For RrbInternalNode
import 'package:test/test.dart';

void main() {
  group('ApexList Advanced Operations', () {
    test('insertAll into empty list', () {
      final list1 = ApexList<int>.empty();
      final list2 = list1.insertAll(0, [1, 2, 3]);
      expect(list2, equals([1, 2, 3]));
      expect(list1.isEmpty, isTrue); // Original unchanged
    });

    test('insertAll at beginning', () {
      final list1 = ApexList<int>.empty().add(3).add(4);
      final list2 = list1.insertAll(0, [1, 2]);
      expect(list2, equals([1, 2, 3, 4]));
      expect(list1, equals([3, 4])); // Original unchanged
    });

    test('insertAll in middle', () {
      final list1 = ApexList<int>.empty().add(1).add(4);
      final list2 = list1.insertAll(1, [2, 3]);
      expect(list2, equals([1, 2, 3, 4]));
      expect(list1, equals([1, 4])); // Original unchanged
    });

    test('insertAll at end', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = list1.insertAll(2, [3, 4]);
      expect(list2, equals([1, 2, 3, 4]));
      expect(list1, equals([1, 2])); // Original unchanged
    });

    test('insertAll empty iterable', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = list1.insertAll(1, []);
      expect(identical(list1, list2), isTrue); // Should return same instance
      expect(list2, equals([1, 2]));
    });

    test('insertAll invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.insertAll(3, [99]), throwsRangeError);
      expect(() => list.insertAll(-1, [99]), throwsRangeError);
    });

    // --- sublist tests ---
    test('sublist full range', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(0, 3);
      expect(sub, equals([1, 2, 3]));
      expect(
        identical(list1, sub),
        isTrue,
      ); // Sublist of full range should be identical
    });

    test('sublist from start', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(0, 2);
      expect(sub, equals([1, 2]));
      expect(sub.length, 2);
    });

    test('sublist to end', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(1); // No end specified
      expect(sub, equals([2, 3]));
      expect(sub.length, 2);
    });

    test('sublist middle part', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3).add(4).add(5);
      final sub = list1.sublist(1, 4);
      expect(sub, equals([2, 3, 4]));
      expect(sub.length, 3);
    });

    test('sublist empty result (start == end)', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      final sub = list1.sublist(1, 1);
      expect(sub.isEmpty, isTrue);
      expect(sub.length, 0);
      expect(identical(sub, ApexList<int>.empty()), isTrue);
    });

    test('sublist empty result (start > end) throws RangeError', () {
      // Standard List.sublist requires start <= end.
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      // Expect a RangeError because start (2) > end (1)
      expect(() => list1.sublist(2, 1), throwsRangeError);
    });

    // Split invalid range tests
    test('sublist invalid range: negative start', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      expect(() => list1.sublist(-1), throwsRangeError);
    });

    test('sublist invalid range: end out of bounds', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      expect(() => list1.sublist(0, 4), throwsRangeError);
    });

    test('sublist invalid range: start out of bounds', () {
      final list1 = ApexList<int>.empty().add(1).add(2).add(3);
      expect(() => list1.sublist(4), throwsRangeError);
    });

    // --- operator+ tests ---
    test('operator+ with empty', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final emptyList = ApexList<int>.empty();

      final res1 = list1 + emptyList;
      final res2 = emptyList + list1;

      expect(identical(res1, list1), isTrue);
      expect(identical(res2, list1), isTrue);
    });

    test('operator+ two non-empty lists', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = ApexList<int>.empty().add(3).add(4).add(5);
      final result = list1 + list2;

      expect(result, equals([1, 2, 3, 4, 5]));
      expect(result.length, 5);
      expect(list1, equals([1, 2])); // Original unchanged
      expect(list2, equals([3, 4, 5])); // Original unchanged
    });

    test('insert causes node splits', () {
      final int B = 32; // Branching factor (use constant if available)
      ApexList<int> list = ApexList.empty();

      // 1. Fill one leaf node exactly
      for (int i = 0; i < B; i++) {
        list = list.add(i);
      }
      expect(list.length, B);
      expect(list, equals(List.generate(B, (i) => i)));

      // 2. Add one more element to trigger leaf split -> height 1 root
      list = list.add(B);
      expect(list.length, B + 1);
      expect(list[B], B);
      // Internal check (optional): Verify root height is 1 if possible

      // 3. Add enough elements to potentially split internal nodes
      // Fill up to B*B elements (potentially creating a height 2 root)
      for (int i = B + 1; i < B * B; i++) {
        list = list.add(i);
      }
      expect(list.length, B * B);
      expect(list[0], 0);
      expect(list[B], B);
      expect(list[B * B - 1], B * B - 1);

      // 4. Add one more to trigger potential height 2 split
      list = list.add(B * B);
      expect(list.length, B * B + 1);
      expect(list[B * B], B * B);
    });

    test('removeAt causes node merges/rebalancing', () {
      final int B = 32; // Branching factor
      final int N =
          B * B + B ~/ 2; // Enough elements for height 2, partially filled
      ApexList<int> list = ApexList.empty();
      for (int i = 0; i < N; i++) {
        list = list.add(i);
      }
      expect(list.length, N);

      // Remove elements from the middle/beginning to trigger merges/borrows
      int currentLength = N;
      final List<int> expectedElements = List.generate(N, (i) => i);

      // Remove a significant number of elements
      final int removals =
          B * (B ~/ 2); // Remove roughly half the nodes at lowest level
      for (int i = 0; i < removals; i++) {
        // Remove from near the beginning to maximize rebalancing potential
        final removeIndex =
            i % (currentLength ~/ 4) + (B ~/ 4); // Vary index a bit

        if (removeIndex < currentLength) {
          final removedValue = expectedElements.removeAt(removeIndex);
          // Debug print before removeAt
          if (removeIndex == 200) {
            // Specific index causing the issue
            print(
              'DEBUG: Before removeAt($removeIndex), currentLength: $currentLength',
            );
            print('DEBUG: Root node: ${(list as ApexListImpl<int>).debugRoot}');
            // Optionally print more details about the root node if needed
            if ((list as ApexListImpl<int>).debugRoot
                is rrb.RrbInternalNode<int>) {
              final internalRoot =
                  (list as ApexListImpl<int>).debugRoot
                      as rrb.RrbInternalNode<int>;
              print(
                'DEBUG: Root children count: ${internalRoot.children.length}',
              );
              print(
                'DEBUG: Root child 0 count: ${internalRoot.children[0].count}',
              );
              print('DEBUG: Root sizeTable: ${internalRoot.sizeTable}');
            }
          }

          list = list.removeAt(removeIndex);
          currentLength--;
        }
      }

      expect(list.length, currentLength);
      // Verify the remaining elements match the expected list after removals
      expect(list, equals(expectedElements));

      // Remove almost all remaining elements
      while (currentLength > 1) {
        list = list.removeAt(0);
        expectedElements.removeAt(0);
        currentLength--;
        expect(list.length, currentLength);
      }
      expect(list[0], expectedElements[0]);

      // Remove the last element
      list = list.removeAt(0);
      expect(list.isEmpty, isTrue);
    }); // End of removeAt causes node merges/rebalancing test
  }); // End of Advanced Operations group
}
