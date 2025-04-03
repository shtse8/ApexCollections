import 'dart:math'; // For Random
import 'package:collection/collection.dart'; // For IterableExtension methods if needed later
import 'package:meta/meta.dart';
import 'apex_list.dart'; // Contains ApexListImpl and its _emptyInstance

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
  /// Creates an empty ApexList.
  /// Returns the canonical empty list instance.
  factory ApexList.empty() =>
      ApexListImpl.emptyInstance<E>(); // Points to the impl's empty instance

  /// Const generative constructor for subclasses.
  const ApexList();

  /// Creates an ApexList from an existing Iterable.
  factory ApexList.from(Iterable<E> elements) {
    // TODO: Implementation using a transient builder for efficiency
    if (elements.isEmpty) return ApexList.empty();
    // Placeholder for the actual implementation class constructor
    // return ApexListImpl<E>.fromIterable(elements);
    // For now, let's assume ApexListImpl exists in apex_list.dart
    // This requires apex_list.dart to define ApexListImpl<E> eventually.
    // We'll use a temporary placeholder return for API definition purposes.
    throw UnimplementedError('ApexListImpl.fromIterable needs implementation');
  }

  /// Creates an ApexList with the given elements.
  factory ApexList.of(List<E> elements) => ApexList.from(elements);

  // --- Core Properties ---

  int get length; // Required by Iterable

  bool get isEmpty; // Required by Iterable

  bool get isNotEmpty; // Required by Iterable

  // --- Element Access ---

  /// Returns the element at the given [index]. O(log N) complexity.
  E operator [](int index);

  E get first; // Required by Iterable

  E get last; // Required by Iterable

  // --- Modification Operations (Returning New Instances) ---

  /// Returns a new list with [value] added to the end. O(1) amortized complexity.
  ApexList<E> add(E value);

  /// Returns a new list with all elements from [iterable] added to the end.
  /// Efficiency depends on the iterable length, but appends are generally efficient.
  ApexList<E> addAll(Iterable<E> iterable);

  /// Returns a new list with [value] inserted at [index]. O(log N) complexity.
  ApexList<E> insert(int index, E value);

  /// Returns a new list with all elements from [iterable] inserted at [index].
  /// Complexity is roughly O(log N + M) where M is the length of the iterable.
  ApexList<E> insertAll(int index, Iterable<E> iterable);

  /// Returns a new list with the element at [index] removed. O(log N) complexity.
  ApexList<E> removeAt(int index);

  /// Returns a new list with the first occurrence of [value] removed.
  /// Requires iteration, complexity depends on the position of the element.
  ApexList<E> remove(E value);
  ApexList<E> removeWhere(bool Function(E element) test);

  /// Returns a new list containing the elements from [start] inclusive to [end] exclusive.
  /// O(log N) complexity.
  ApexList<E> sublist(int start, [int? end]);

  /// Returns a new list with the element at [index] replaced by [value].
  /// O(log N) complexity.
  ApexList<E> update(int index, E value);

  /// Returns a new list representing the concatenation of this list and [other].
  /// Efficient concatenation is a key feature of RRB-Trees. O(log N) complexity.
  ApexList<E> operator +(ApexList<E> other);

  // --- Iterable Overrides & Common Methods ---
  // Concrete classes must implement all required methods from Iterable.

  Iterator<E> get iterator; // Required by Iterable

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

  /// Returns the first index of [element] in this list.
  /// Returns -1 if [element] is not found. Search starts from [start].
  int indexOf(E element, [int start = 0]);

  /// Returns the last index of [element] in this list.
  /// Returns -1 if [element] is not found. Search starts from [end] (if provided).
  int lastIndexOf(E element, [int? end]);

  /// Returns an empty ApexList.
  ApexList<E> clear();

  /// Returns a new map associating indices to elements.
  Map<int, E> asMap();

  /// Returns a new list, sorted according to the provided [compare] function.
  ApexList<E> sort([int Function(E a, E b)? compare]);

  /// Returns a new list with the elements randomly shuffled.
  ApexList<E> shuffle([Random? random]);

  // --- Equality and HashCode ---

  /// Compares this list to [other] for equality.
  /// Two ApexLists are equal if they have the same length and contain equal elements
  /// in the same order.
  @override
  bool operator ==(Object other);

  /// Returns the hash code for this list.
  /// The hash code is based on the elements in the list.
  @override
  int get hashCode;

  // TODO: Consider other less common List/Iterable methods if requested.
}

// _EmptyApexList class removed as it's no longer needed.
// The ApexList.empty() factory now points to ApexListImpl._emptyInstance.
