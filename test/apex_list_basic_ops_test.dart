import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexList Basic Operations', () {
    test('add single element', () {
      final list0 = ApexList<String>.empty();
      final list1 = list0.add('a');

      // Verify list1
      expect(list1.length, 1);
      expect(list1.isEmpty, isFalse);
      expect(list1.isNotEmpty, isTrue);
      expect(list1[0], 'a');
      expect(list1.first, 'a');
      expect(list1.last, 'a');
      expect(list1, equals(['a'])); // Uses ListEquality via Iterable comparison

      // Verify list0 remains unchanged (immutability)
      expect(list0.length, 0);
      expect(list0.isEmpty, isTrue);
    });

    test('add multiple elements', () {
      final list = ApexList<int>.empty().add(1).add(2).add(3);

      expect(list.length, 3);
      expect(list[0], 1);
      expect(list[1], 2);
      expect(list[2], 3);
      expect(list.first, 1);
      expect(list.last, 3);
      expect(list, equals([1, 2, 3]));
    });

    test('iterator correctness', () {
      final list = ApexList<int>.empty().add(10).add(20).add(30);
      final iterator = list.iterator;
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, 10);
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, 20);
      expect(iterator.moveNext(), isTrue);
      expect(iterator.current, 30);
      expect(iterator.moveNext(), isFalse);
    });

    test('removeAt basic', () {
      final list1 = ApexList<String>.empty()
          .add('a')
          .add('b')
          .add('c')
          .add('d');
      final list2 = list1.removeAt(1); // Remove 'b'

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'c');
      expect(list2[2], 'd');
      expect(list2, equals(['a', 'c', 'd']));
      expect(list1, equals(['a', 'b', 'c', 'd'])); // Original unchanged
    });

    test('removeAt first element', () {
      final list1 = ApexList<String>.empty().add('a').add('b').add('c');
      final list2 = list1.removeAt(0); // Remove 'a'

      expect(list2.length, 2);
      expect(list2[0], 'b');
      expect(list2[1], 'c');
      expect(list2, equals(['b', 'c']));
    });

    test('removeAt last element', () {
      final list1 = ApexList<String>.empty().add('a').add('b').add('c');
      final list2 = list1.removeAt(2); // Remove 'c'

      expect(list2.length, 2);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2, equals(['a', 'b']));
    });

    test('removeAt only element', () {
      final list1 = ApexList<String>.empty().add('a');
      final list2 = list1.removeAt(0);

      expect(list2.isEmpty, isTrue);
      expect(list2.length, 0);
      expect(list2, equals(ApexList<String>.empty()));
    });

    test('removeAt invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.removeAt(2), throwsRangeError);
      expect(() => list.removeAt(-1), throwsRangeError);
      expect(() => ApexList<int>.empty().removeAt(0), throwsRangeError);
    });

    test('update existing element', () {
      final list1 = ApexList<String>.empty().add('a').add('b').add('c');
      final list2 = list1.update(1, 'B'); // Update 'b' to 'B'

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'B');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'B', 'c']));
      expect(list1, equals(['a', 'b', 'c'])); // Original unchanged
    });

    test('update with identical value does not change instance', () {
      final list1 = ApexList<String>.empty().add('a').add('b');
      final list2 = list1.update(1, 'b'); // Update with same value

      expect(identical(list1, list2), isTrue);
      expect(list2, equals(['a', 'b']));
    });

    test('update invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.update(2, 99), throwsRangeError);
      expect(() => list.update(-1, 99), throwsRangeError);
      expect(() => ApexList<int>.empty().update(0, 99), throwsRangeError);
    });

    test('addAll', () {
      final list1 = ApexList<int>.empty().add(1).add(2);
      final list2 = list1.addAll([3, 4, 5]);
      final list3 = list2.addAll([]); // Add empty iterable
      final list4 = ApexList<int>.empty().addAll([10, 20]);

      expect(list2, equals([1, 2, 3, 4, 5]));
      expect(list2.length, 5);
      expect(list1, equals([1, 2])); // Original unchanged

      expect(
        identical(list2, list3),
        isTrue,
      ); // Adding empty returns same instance

      expect(list4, equals([10, 20]));
      expect(list4.length, 2);
    });

    test('insert at beginning', () {
      final list1 = ApexList<String>.empty().add('b').add('c');
      final list2 = list1.insert(0, 'a');

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'b', 'c']));
      expect(list1, equals(['b', 'c'])); // Original unchanged
    });

    test('insert in middle', () {
      final list1 = ApexList<String>.empty().add('a').add('c');
      final list2 = list1.insert(1, 'b');

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'b', 'c']));
    });

    test('insert at end', () {
      final list1 = ApexList<String>.empty().add('a').add('b');
      final list2 = list1.insert(2, 'c'); // Equivalent to add

      expect(list2.length, 3);
      expect(list2[0], 'a');
      expect(list2[1], 'b');
      expect(list2[2], 'c');
      expect(list2, equals(['a', 'b', 'c']));
    });

    test('insert into empty list', () {
      final list1 = ApexList<String>.empty();
      final list2 = list1.insert(0, 'a');

      expect(list2.length, 1);
      expect(list2[0], 'a');
      expect(list2, equals(['a']));
    });

    test('insert invalid index', () {
      final list = ApexList<int>.empty().add(1).add(2);
      expect(() => list.insert(3, 99), throwsRangeError); // Index > length
      expect(() => list.insert(-1, 99), throwsRangeError);
    });
  }); // End of Basic Operations group
}
