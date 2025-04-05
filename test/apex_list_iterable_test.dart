import 'package:apex_collections/apex_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ApexList Iterable Methods', () {
    final list = ApexList<int>.empty().add(1).add(2).add(3).add(4).add(5);

    test('where', () {
      final evens = list.where((e) => e.isEven);
      expect(evens, equals([2, 4]));
    });

    test('map', () {
      final strings = list.map((e) => 'v$e');
      expect(strings, equals(['v1', 'v2', 'v3', 'v4', 'v5']));
    });

    test('any', () {
      expect(list.any((e) => e > 3), isTrue);
      expect(list.any((e) => e > 5), isFalse);
    });

    test('every', () {
      expect(list.every((e) => e > 0), isTrue);
      expect(list.every((e) => e.isEven), isFalse);
    });

    test('take', () {
      expect(list.take(3), equals([1, 2, 3]));
      expect(list.take(0).isEmpty, isTrue);
      expect(list.take(10), equals([1, 2, 3, 4, 5])); // Take more than length
    });

    test('skip', () {
      expect(list.skip(3), equals([4, 5]));
      expect(list.skip(0), equals([1, 2, 3, 4, 5]));
      expect(list.skip(10).isEmpty, isTrue); // Skip more than length
    });

    test('fold', () {
      final sum = list.fold<int>(0, (prev, e) => prev + e);
      expect(sum, 15);
    });

    test('reduce', () {
      final sum = list.reduce((val, e) => val + e);
      expect(sum, 15);
      expect(
        () => ApexList<int>.empty().reduce((v, e) => v + e),
        throwsStateError,
      );
    });
  });
}
