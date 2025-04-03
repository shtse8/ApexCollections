import 'dart:math'; // For Random
import 'package:collection/collection.dart'; // For IterableExtension methods if needed later
import 'package:meta/meta.dart';
import 'apex_list.dart'; // Contains ApexListImpl and its _emptyInstance

/// An immutable, persistent list implementation based on Relaxed Radix Balanced Trees (RRB-Trees).
///
/// `ApexList` provides efficient operations for immutable lists, aiming for
/// performance characteristics suitable for functional programming patterns and
/// state management in UI frameworks like Flutter.
///
/// Key performance characteristics (asymptotic complexity):
/// - Access (index lookup `[]`): O(log N)
/// - Update (`update`): O(log N)
/// - Insertion/Removal (`insert`, `removeAt`): O(log N)
/// - Append (`add`): Amortized O(1)
/// - Concatenation (`+`): O(log N) - *Currently implemented via iteration/rebuild O(N+M)*
/// - Slicing (`sublist`): O(log N) - *Currently implemented via iteration/rebuild O(M)*
/// - Iteration: O(N)
///
/// It implements the standard Dart [Iterable] interface.
@immutable
abstract class ApexList<E> implements Iterable<E> {
  /// Creates an empty `ApexList`.
  ///
  /// Returns the canonical empty list instance, ensuring efficiency.
  ///
  /// ```dart
  /// final emptyList = ApexList<int>.empty();
  /// print(emptyList.isEmpty); // true
  /// ```
  factory ApexList.empty() =>
      ApexListImpl.emptyInstance<E>(); // Points to the impl's empty instance

  /// Const generative constructor for subclasses.
  ///
  /// **Note:** This constructor is typically not used directly. Use factories like
  /// [ApexList.empty], [ApexList.from], or [ApexList.of].
  const ApexList();

  /// Creates an `ApexList` from an existing [Iterable].
  ///
  /// The elements from the iterable are copied into the new list.
  /// The iteration order of the iterable determines the order in the list.
  ///
  /// ```dart
  /// final numbers = [1, 2, 3];
  /// final apexList = ApexList.from(numbers);
  /// print(apexList); // ApexList(1, 2, 3)
  ///
  /// final set = {4, 5, 6};
  /// final apexListFromSet = ApexList.from(set);
  /// print(apexListFromSet); // ApexList(4, 5, 6) - order depends on Set iteration
  /// ```
  factory ApexList.from(Iterable<E> elements) {
    // TODO: Implementation using a transient builder for efficiency
    if (elements.isEmpty) return ApexList.empty();
    // Placeholder for the actual implementation class constructor
    return ApexListImpl<E>.fromIterable(elements);
    // For now, let's assume ApexListImpl exists in apex_list.dart
    // This requires apex_list.dart to define ApexListImpl<E> eventually.
    // We'll use a temporary placeholder return for API definition purposes.
    // throw UnimplementedError('ApexListImpl.fromIterable needs implementation'); // Removed throw
  }

  /// Creates an `ApexList` with the given elements.
  ///
  /// Equivalent to calling `ApexList.from(elements)`.
  ///
  /// ```dart
  /// final apexList = ApexList.of([10, 20, 30]);
  /// print(apexList); // ApexList(10, 20, 30)
  /// ```
  factory ApexList.of(List<E> elements) => ApexList.from(elements);

  // --- Core Properties ---

  /// Returns the number of elements in the list.
  ///
  /// Accessing length is an O(1) operation.
  @override
  int get length; // Required by Iterable

  /// Returns `true` if the list contains no elements.
  ///
  /// Accessing isEmpty is an O(1) operation.
  @override
  bool get isEmpty; // Required by Iterable

  /// Returns `true` if the list contains at least one element.
  ///
  /// Accessing isNotEmpty is an O(1) operation.
  @override
  bool get isNotEmpty; // Required by Iterable

  // --- Element Access ---

  /// Returns the element at the given [index].
  ///
  /// The [index] must be non-negative and less than [length].
  /// Accessing an element by index has O(log N) complexity due to the tree structure.
  ///
  /// ```dart
  /// final list = ApexList.of(['a', 'b', 'c']);
  /// print(list[1]); // 'b'
  /// ```
  E operator [](int index);

  /// Returns the first element.
  ///
  /// Throws a [StateError] if the list is empty.
  /// Accessing the first element has O(log N) complexity.
  @override
  E get first; // Required by Iterable

  /// Returns the last element.
  ///
  /// Throws a [StateError] if the list is empty.
  /// Accessing the last element has O(log N) complexity.
  @override
  E get last; // Required by Iterable

  // --- Modification Operations (Returning New Instances) ---

  /// Returns a new list with [value] added to the end.
  ///
  /// This operation has amortized O(1) complexity.
  ///
  /// ```dart
  /// final list1 = ApexList.of([1, 2]);
  /// final list2 = list1.add(3);
  /// print(list1); // ApexList(1, 2)
  /// print(list2); // ApexList(1, 2, 3)
  /// ```
  ApexList<E> add(E value);

  /// Returns a new list with all elements from [iterable] added to the end.
  ///
  /// The complexity depends on the number of elements added (M) and the
  /// structure of the tree, but is generally efficient due to transient operations.
  /// Roughly O(M * log N).
  ///
  /// ```dart
  /// final list1 = ApexList.of([1, 2]);
  /// final list2 = list1.addAll([3, 4, 5]);
  /// print(list2); // ApexList(1, 2, 3, 4, 5)
  /// ```
  ApexList<E> addAll(Iterable<E> iterable);

  /// Returns a new list with [value] inserted at the specified [index].
  ///
  /// The [index] must be non-negative and no greater than [length].
  /// This operation has O(log N) complexity.
  ///
  /// ```dart
  /// final list1 = ApexList.of(['a', 'c']);
  /// final list2 = list1.insert(1, 'b');
  /// print(list2); // ApexList(a, b, c)
  /// ```
  ApexList<E> insert(int index, E value);

  /// Returns a new list with all elements from [iterable] inserted at the
  /// specified [index].
  ///
  /// The [index] must be non-negative and no greater than [length].
  /// Complexity is roughly O(log N + M * log(N+M)) where M is the length of the iterable.
  /// *Currently implemented via iteration/rebuild O(N+M)*.
  ///
  /// ```dart
  /// final list1 = ApexList.of([10, 40]);
  /// final list2 = list1.insertAll(1, [20, 30]);
  /// print(list2); // ApexList(10, 20, 30, 40)
  /// ```
  ApexList<E> insertAll(int index, Iterable<E> iterable);

  /// Returns a new list with the element at the given [index] removed.
  ///
  /// The [index] must be non-negative and less than [length].
  /// This operation has O(log N) complexity.
  ///
  /// ```dart
  /// final list1 = ApexList.of(['a', 'b', 'c']);
  /// final list2 = list1.removeAt(1);
  /// print(list2); // ApexList(a, c)
  /// ```
  ApexList<E> removeAt(int index);

  /// Returns a new list with the first occurrence of [value] removed.
  ///
  /// Returns the original list if [value] is not found.
  /// Requires iteration to find the element, complexity depends on the position.
  /// O(N) in the worst case to find the element, plus O(log N) for removal.
  ///
  /// ```dart
  /// final list1 = ApexList.of([1, 2, 3, 2]);
  /// final list2 = list1.remove(2);
  /// print(list2); // ApexList(1, 3, 2)
  /// ```
  ApexList<E> remove(E value);

  /// Returns a new list with all elements that satisfy the [test] predicate removed.
  ///
  /// ```dart
  /// final list1 = ApexList.of([1, 2, 3, 4, 5]);
  /// final list2 = list1.removeWhere((e) => e.isOdd);
  /// print(list2); // ApexList(2, 4)
  /// ```
  ApexList<E> removeWhere(bool Function(E element) test);

  /// Returns a new list containing the elements from [start] inclusive to [end] exclusive.
  ///
  /// If [end] is omitted, it defaults to the [length] of the list.
  /// The [start] and [end] indices must satisfy `0 <= start <= end <= length`.
  /// Complexity is O(log N + M) where M is the length of the sublist.
  /// *Currently implemented via iteration/rebuild O(M)*.
  ///
  /// ```dart
  /// final list1 = ApexList.of([0, 1, 2, 3, 4]);
  /// final list2 = list1.sublist(1, 4);
  /// print(list2); // ApexList(1, 2, 3)
  /// ```
  ApexList<E> sublist(int start, [int? end]);

  /// Returns a new list with the element at [index] replaced by [value].
  ///
  /// The [index] must be non-negative and less than [length].
  /// This operation has O(log N) complexity.
  ///
  /// ```dart
  /// final list1 = ApexList.of(['a', 'b', 'c']);
  /// final list2 = list1.update(1, 'B');
  /// print(list2); // ApexList(a, B, c)
  /// ```
  ApexList<E> update(int index, E value);

  /// Returns a new list representing the concatenation of this list and [other].
  ///
  /// Efficient concatenation (O(log N)) is a potential feature of RRB-Trees,
  /// but the current implementation iterates and rebuilds (O(N+M)).
  ///
  /// ```dart
  /// final list1 = ApexList.of([1, 2]);
  /// final list2 = ApexList.of([3, 4]);
  /// final list3 = list1 + list2;
  /// print(list3); // ApexList(1, 2, 3, 4)
  /// ```
  ApexList<E> operator +(ApexList<E> other);

  // --- Iterable Overrides & Common Methods ---
  // Most standard Iterable methods are implemented by the concrete class,
  // often delegating to the efficient iterator.

  /// Returns a new lazy [Iterator] that allows iterating the elements of this list.
  @override
  Iterator<E> get iterator; // Required by Iterable

  /// Returns `true` if the list contains the given [element].
  ///
  /// This method iterates through the list and has O(N) complexity.
  @override
  bool contains(Object? element);

  /// Returns the element at the given [index].
  ///
  /// Equivalent to `operator [](index)`. O(log N) complexity.
  @override
  E elementAt(int index);

  /// Expands each element of this [Iterable] into zero or more elements.
  ///
  /// The resulting Iterable runs through the elements returned
  /// by [toElements] for each element of this, in order.
  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements);

  /// Returns the first element that satisfies the given predicate [test].
  ///
  /// Iterates through elements until one is found that satisfies [test].
  /// If no element satisfies [test], the result of invoking [orElse] is returned.
  /// If [orElse] is omitted, a [StateError] is thrown.
  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse});

  /// Reduces a collection to a single value by iteratively combining elements
  /// of the collection using the provided [combine] function.
  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine);

  /// Executes the provided [action] for each element of the list.
  @override
  void forEach(void Function(E element) action);

  /// Joins the string representation of elements with the provided [separator].
  @override
  String join([String separator = '']);

  /// Returns the last element that satisfies the given predicate [test].
  ///
  /// Similar to [firstWhere], but iterates from the end.
  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse});

  /// Returns a new lazy [Iterable] with elements that are the result of
  /// calling the provided function [convert] on each element of this list.
  @override
  Iterable<T> map<T>(T Function(E e) convert);

  /// Reduces a collection to a single value by iteratively combining elements
  /// using the provided [combine] function. Throws [StateError] if the list is empty.
  @override
  E reduce(E Function(E value, E element) combine);

  /// Returns the single element in the list.
  ///
  /// Throws a [StateError] if the list is empty or has more than one element.
  @override
  E get single;

  /// Returns the single element that satisfies [test].
  ///
  /// Throws a [StateError] if no element or more than one element satisfies [test].
  /// If [orElse] is provided, it is called if no element satisfies [test],
  /// and its result is returned.
  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse});

  /// Returns an [Iterable] that skips the first [count] elements.
  @override
  Iterable<E> skip(int count);

  /// Returns an [Iterable] that skips elements while [test] is true.
  @override
  Iterable<E> skipWhile(bool Function(E value) test);

  /// Returns an [Iterable] containing the first [count] elements.
  @override
  Iterable<E> take(int count);

  /// Returns an [Iterable] containing elements while [test] is true.
  @override
  Iterable<E> takeWhile(bool Function(E value) test);

  /// Creates a [List] containing the elements of this [ApexList].
  @override
  List<E> toList({bool growable = true});

  /// Creates a [Set] containing the elements of this [ApexList].
  @override
  Set<E> toSet();

  /// Returns a new lazy [Iterable] with all elements that satisfy the predicate [test].
  @override
  Iterable<E> where(bool Function(E element) test);

  /// Returns a new lazy [Iterable] with all elements that have type [T].
  @override
  Iterable<T> whereType<T>();

  /// Checks whether any element of this iterable satisfies [test].
  @override
  bool any(bool Function(E element) test);

  /// Checks whether every element of this iterable satisfies [test].
  @override
  bool every(bool Function(E element) test);

  /// Returns a new lazy [Iterable] with elements of type [T].
  @override
  Iterable<T> cast<T>();

  /// Returns a new lazy [Iterable] consisting of the elements of this iterable
  /// followed by the elements of [other].
  @override
  Iterable<E> followedBy(Iterable<E> other);

  /// Returns the first index of [element] in this list.
  ///
  /// Searches the list from index [start] to the end.
  /// Returns -1 if [element] is not found.
  /// Complexity is O(N) in the worst case.
  ///
  /// ```dart
  /// final list = ApexList.of(['a', 'b', 'c', 'b']);
  /// print(list.indexOf('b'));      // 1
  /// print(list.indexOf('b', 2)); // 3
  /// print(list.indexOf('d'));      // -1
  /// ```
  int indexOf(E element, [int start = 0]);

  /// Returns the last index of [element] in this list.
  ///
  /// Searches the list backward from index [end] (or the end of the list if not provided)
  /// down to 0.
  /// Returns -1 if [element] is not found.
  /// Complexity is O(N) in the worst case.
  ///
  /// ```dart
  /// final list = ApexList.of(['a', 'b', 'c', 'b', 'a']);
  /// print(list.lastIndexOf('b'));      // 3
  /// print(list.lastIndexOf('b', 2)); // 1
  /// print(list.lastIndexOf('d'));      // -1
  /// ```
  int lastIndexOf(E element, [int? end]);

  /// Returns an empty `ApexList`.
  ///
  /// Equivalent to calling `ApexList.empty()`.
  ///
  /// ```dart
  /// final list = ApexList.of([1, 2, 3]);
  /// final emptyList = list.clear();
  /// print(emptyList.isEmpty); // true
  /// ```
  ApexList<E> clear();

  /// Returns a new [Map] associating indices to elements.
  ///
  /// The returned map is a standard mutable [Map].
  /// Complexity is O(N).
  ///
  /// ```dart
  /// final list = ApexList.of(['a', 'b']);
  /// final map = list.asMap();
  /// print(map); // {0: a, 1: b}
  /// ```
  Map<int, E> asMap();

  /// Returns a new list, sorted according to the order specified by the
  /// [compare] function.
  ///
  /// If [compare] is omitted, it uses the natural ordering of the elements.
  /// The sort is stable.
  /// Complexity is roughly O(N log N) due to the underlying list sort.
  ///
  /// ```dart
  /// final list1 = ApexList.of([3, 1, 4, 2]);
  /// final list2 = list1.sort();
  /// print(list2); // ApexList(1, 2, 3, 4)
  /// ```
  ApexList<E> sort([int Function(E a, E b)? compare]);

  /// Returns a new list with the elements randomly shuffled.
  ///
  /// If [random] is provided, it is used as the random number generator.
  /// Complexity is O(N).
  ///
  /// ```dart
  /// final list1 = ApexList.of([1, 2, 3, 4]);
  /// final list2 = list1.shuffle(); // Order will be random
  /// print(list2.length); // 4
  /// ```
  ApexList<E> shuffle([Random? random]);

  // --- Equality and HashCode ---

  /// Compares this list to [other] for equality.
  ///
  /// Two `ApexList` instances are considered equal if they have the same length
  /// and contain equal elements in the same order.
  ///
  /// The comparison is efficient, typically O(N) in the worst case.
  @override
  bool operator ==(Object other);

  /// Returns the hash code for this list.
  ///
  /// The hash code is calculated based on the elements in the list and their order.
  /// Equal lists will have the same hash code.
  @override
  int get hashCode;

  // TODO: Consider other less common List/Iterable methods if requested.
}

// _EmptyApexList class removed as it's no longer needed.
// The ApexList.empty() factory now points to ApexListImpl._emptyInstance.
