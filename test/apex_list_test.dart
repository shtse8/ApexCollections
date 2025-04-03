import 'package:apex_collections/apex_collections.dart'; // Assuming this exports ApexList
import 'package:test/test.dart';

void main() {
  group('ApexList Empty', () {
    test('empty() constructor creates an empty list', () {
      final list = ApexList<int>.empty();
      expect(list.isEmpty, isTrue);
      expect(list.isNotEmpty, isFalse);
      expect(list.length, 0);
    });

    test('empty list throws on accessing first/last', () {
      final list = ApexList<int>.empty();
      expect(() => list.first, throwsStateError);
      expect(() => list.last, throwsStateError);
    });

    test('empty list throws on accessing index', () {
      final list = ApexList<int>.empty();
      expect(() => list[0], throwsRangeError);
      expect(() => list[-1], throwsRangeError);
    });

    test('empty list iterator has no elements', () {
      final list = ApexList<String>.empty();
      final iterator = list.iterator;
      expect(iterator.moveNext(), isFalse);
    });

    test('empty list equality', () {
      final list1 = ApexList<int>.empty();
      final list2 = ApexList<String>.empty(); // Different type arg
      final list3 = const ApexList<int>.empty(); // Const constructor

      expect(list1, equals(ApexList<int>.empty()));
      expect(list1, equals(list2)); // Should be equal despite type arg
      expect(list1, equals(list3));
      expect(list1 == list3, isTrue); // Const instances should be identical
    });

    test('empty list hashCode', () {
      expect(ApexList.empty().hashCode, equals(ApexList.empty().hashCode));
      // TODO: Define expected hash code for empty list (e.g., 0 or based on ListEquality)
    });

    // TODO: Add tests for modification methods on empty list (add, insert, etc.)
    // TODO: Add tests for Iterable methods on empty list (map, where, etc.)
  });

  // TODO: Add groups for ApexList.from(), ApexList.of()
  // TODO: Add groups for non-empty list operations (get, update, add, remove, etc.)
}
