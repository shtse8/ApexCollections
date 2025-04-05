import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexList Equality and HashCode', () {
    test('== operator', () {
      final list1a = ApexList<int>.empty().add(1).add(2).add(3);
      final list1b = ApexList<int>.empty().add(1).add(2).add(3);
      final list2 = ApexList<int>.empty().add(1).add(2).add(4); // Diff value
      final list3 = ApexList<int>.empty().add(1).add(2); // Diff length
      final list4 = ApexList<String>.empty()
          .add('1')
          .add('2')
          .add('3'); // Diff type
      final list5 = ApexList<int>.empty();

      expect(list1a == list1b, isTrue);
      expect(list1a == list2, isFalse);
      expect(list1a == list3, isFalse);
      expect(
        list1a == list4,
        isFalse,
      ); // Comparing ApexList<int> to ApexList<String>
      expect(list1a == [1, 2, 3], isFalse); // Comparing to standard List
      expect(list5 == ApexList<int>.empty(), isTrue);
      expect(list1a == list1a, isTrue); // Identity
    });

    test('hashCode consistency', () {
      final list1a = ApexList<int>.empty().add(1).add(2).add(3);
      final list1b = ApexList<int>.empty().add(1).add(2).add(3);
      final list2 = ApexList<int>.empty().add(1).add(2).add(4);
      final listEmpty = ApexList<int>.empty();

      expect(list1a.hashCode, equals(list1b.hashCode));
      expect(list1a.hashCode, isNot(equals(list2.hashCode)));
      expect(list1a.hashCode, isNot(equals(listEmpty.hashCode)));
      expect(listEmpty.hashCode, equals(ApexList<int>.empty().hashCode));
    });
  });
}
