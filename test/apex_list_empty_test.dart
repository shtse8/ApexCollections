import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexList Empty', () {
    test('empty() constructor creates an empty list', () {
      final list = ApexList<int>.empty();
      expect(list.isEmpty, isTrue);
      expect(list.isNotEmpty, isFalse);
      expect(list.length, 0);
      expect(() => list.first, throwsStateError);
      expect(() => list.last, throwsStateError);
      expect(() => list[0], throwsRangeError);
      expect(list.iterator.moveNext(), isFalse);
    });

    test('empty list equality', () {
      final list1 = ApexList<int>.empty();
      final list2 = ApexList<String>.empty(); // Different type args
      final list3 = ApexList<int>.empty();

      expect(list1, equals(ApexList<int>.empty()));
      expect(list1, equals(list2)); // Should be equal despite type args
      expect(list1, equals(list3));
      // Check identicality using the public factory constructor.
      // This relies on the factory returning the cached instance via emptyInstance<E>().
      expect(identical(ApexList<int>.empty(), ApexList<int>.empty()), isTrue);
      expect(
        identical(ApexList<String>.empty(), ApexList<String>.empty()),
        isTrue,
      );
      // Empty lists of different types might or might not be identical depending on caching strategy.
    });

    test('empty list hashCode', () {
      expect(ApexList.empty().hashCode, equals(ApexList.empty().hashCode));
      // Check hash codes are consistent for the same type
      expect(
        ApexList<int>.empty().hashCode,
        equals(ApexList<int>.empty().hashCode),
      );
      expect(
        ApexList<String>.empty().hashCode,
        equals(ApexList<String>.empty().hashCode),
      );
      // Hash codes for empty lists of different types might differ, which is acceptable.
    });
  });
}
