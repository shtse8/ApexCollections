import 'package:collection/collection.dart'; // For IterableExtension methods if needed later
import 'package:meta/meta.dart';
import 'apex_list.dart'; // Import the concrete implementation
// import 'apex_list.dart'; // Assuming implementation is in apex_list.dart

/// Abstract definition for an immutable, persistent list based on RRB-Trees.
///
/// Provides efficient indexing, updates, concatenation, slicing, and insertion/removal
/// at arbitrary indices (O(log N)), while aiming for efficient iteration and
/// effectively constant time appends.
@immutable
abstract class ApexList<E> implements Iterable<E> {
  /// Creates an empty ApexList.
  ///
  /// This should be a const constructor pointing to a shared empty instance.
  const factory ApexList.empty() = _EmptyApexList<E>;

  /// Const generative constructor for subclasses.
  const ApexList();

  /// Creates an ApexList from an existing Iterable.
  factory ApexList.from(Iterable<E> elements) {
    // TODO: Implementation using a transient builder for efficiency
    if (elements.isEmpty) return ApexList.empty();
    return ApexListImpl<E>.fromIterable(elements); // Delegate to implementation
  }

  /// Creates an ApexList with the given elements.
  factory ApexList.of(List<E> elements) => ApexList.from(elements);

  // --- Core Properties ---

  @override
  int get length;

  @override
  bool get isEmpty;

  @override
  bool get isNotEmpty;

  // --- Element Access ---

  E operator [](int index);

  @override
  E get first;

  @override
  E get last;

  // --- Modification Operations (Returning New Instances) ---

  ApexList<E> add(E value);
  ApexList<E> addAll(Iterable<E> iterable);
  ApexList<E> insert(int index, E value);
  ApexList<E> insertAll(int index, Iterable<E> iterable);
  ApexList<E> removeAt(int index);
  ApexList<E> remove(E value);
  ApexList<E> removeWhere(bool Function(E element) test);
  ApexList<E> sublist(int start, [int? end]);
  ApexList<E> update(int index, E value);
  ApexList<E> operator +(ApexList<E> other);

  // --- Iterable Overrides & Common Methods ---
  // Concrete classes must implement all required methods from Iterable.

  @override
  Iterator<E> get iterator;

  @override
  bool contains(Object? element);

  @override
  E elementAt(int index);

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements);

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse});

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine);

  @override
  void forEach(void Function(E element) action);

  @override
  String join([String separator = '']);

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse});

  @override
  Iterable<T> map<T>(T Function(E e) convert);

  @override
  E reduce(E Function(E value, E element) combine);

  @override
  E get single;

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse});

  @override
  Iterable<E> skip(int count);

  @override
  Iterable<E> skipWhile(bool Function(E value) test);

  @override
  Iterable<E> take(int count);

  @override
  Iterable<E> takeWhile(bool Function(E value) test);

  @override
  List<E> toList({bool growable = true});

  @override
  Set<E> toSet();

  @override
  Iterable<E> where(bool Function(E element) test);

  @override
  Iterable<T> whereType<T>();

  @override
  bool any(bool Function(E element) test);

  @override
  bool every(bool Function(E element) test);

  @override
  Iterable<T> cast<T>();

  @override
  Iterable<E> followedBy(Iterable<E> other);

  // TODO: Consider other common List/Iterable methods
  // TODO: Consider equality (operator ==) and hashCode implementation details.
}

// Concrete implementation for the empty list singleton
class _EmptyApexList<E> extends ApexList<E> {
  const _EmptyApexList();

  @override
  int get length => 0;

  @override
  bool get isEmpty => true;

  @override
  bool get isNotEmpty => false;

  @override
  E operator [](int index) =>
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot index into an empty list',
        0,
      );

  @override
  E get first => throw StateError('No element');

  @override
  E get last => throw StateError('No element');

  @override
  ApexList<E> add(E value) {
    // TODO: Return a concrete ApexList implementation with one element
    // Example: return ApexListImpl<E>.fromIterable([value]);
    throw UnimplementedError('Add on empty list should create a new list');
  }

  @override
  ApexList<E> addAll(Iterable<E> iterable) => ApexList.from(iterable);

  @override
  ApexList<E> insert(int index, E value) {
    if (index == 0) return add(value);
    throw RangeError.index(
      index,
      this,
      'index',
      'Index out of range for insertion',
      0,
    );
  }

  @override
  ApexList<E> insertAll(int index, Iterable<E> iterable) {
    if (index == 0) return addAll(iterable);
    throw RangeError.index(
      index,
      this,
      'index',
      'Index out of range for insertion',
      0,
    );
  }

  @override
  ApexList<E> removeAt(int index) =>
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot remove from an empty list',
        0,
      );

  @override
  ApexList<E> remove(E value) => this;

  @override
  ApexList<E> removeWhere(bool Function(E element) test) => this;

  @override
  ApexList<E> sublist(int start, [int? end]) {
    RangeError.checkValidRange(start, end, 0);
    return this;
  }

  @override
  ApexList<E> update(int index, E value) =>
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot update an empty list',
        0,
      );

  @override
  ApexList<E> operator +(ApexList<E> other) => other;

  // --- Iterable implementations ---
  @override
  Iterator<E> get iterator => const <Never>[].iterator;

  @override
  bool contains(Object? element) => false;

  @override
  E elementAt(int index) =>
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot get element from empty list',
        0,
      );

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) =>
      const Iterable.empty();

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) {
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      initialValue;

  @override
  void forEach(void Function(E element) action) {}

  @override
  String join([String separator = '']) => '';

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) {
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<T> map<T>(T Function(E e) convert) => const Iterable.empty();

  @override
  E reduce(E Function(E value, E element) combine) =>
      throw StateError('No element');

  @override
  E get single => throw StateError('No element');

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) {
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<E> skip(int count) {
    RangeError.checkNotNegative(count, 'count');
    return const Iterable.empty();
  }

  @override
  Iterable<E> skipWhile(bool Function(E value) test) => const Iterable.empty();

  @override
  Iterable<E> take(int count) {
    RangeError.checkNotNegative(count, 'count');
    return const Iterable.empty();
  }

  @override
  Iterable<E> takeWhile(bool Function(E value) test) => const Iterable.empty();

  @override
  List<E> toList({bool growable = true}) => List<E>.empty(growable: growable);

  @override
  Set<E> toSet() => <E>{};

  @override
  Iterable<E> where(bool Function(E element) test) => const Iterable.empty();

  @override
  Iterable<T> whereType<T>() => const Iterable.empty();

  @override
  bool any(bool Function(E element) test) => false;

  @override
  bool every(bool Function(E element) test) => true;

  @override
  Iterable<T> cast<T>() => ApexList<T>.empty();

  @override
  Iterable<E> followedBy(Iterable<E> other) => other;

  // --- Equality and HashCode ---
  @override
  bool operator ==(Object other) => other is ApexList && other.isEmpty;

  @override
  int get hashCode => 0; // Consistent hash code for empty list
}
