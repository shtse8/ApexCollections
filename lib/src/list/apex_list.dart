import 'dart:math'; // For Random
import 'package:collection/collection.dart'; // For ListEquality
import 'apex_list_api.dart';
import 'rrb_node.dart';

/// Concrete implementation of [ApexList] using an RRB-Tree.
class ApexListImpl<E> extends ApexList<E> {
  /// The root node of the RRB-Tree. Can be RrbEmptyNode.
  final RrbNode<E> _root;
  // TODO: Add tail/focus buffer for optimization

  /// The number of elements in the list.
  final int _length;

  /// The canonical empty instance.
  /// The canonical empty instance (internal).
  static final ApexListImpl _emptyInstance = ApexListImpl._(
    RrbEmptyNode.instance(),
    0,
  );

  /// Public accessor for the canonical empty instance.
  static ApexListImpl<E> emptyInstance<E>() =>
      _emptyInstance as ApexListImpl<E>;

  /// Internal constructor. Not const because RrbEmptyNode.instance() isn't const.
  ApexListImpl._(this._root, this._length);

  /// Factory constructor to create from an Iterable.
  factory ApexListImpl.fromIterable(Iterable<E> elements) {
    if (elements.isEmpty) {
      // Return the canonical empty instance of ApexListImpl.
      // Return the canonical empty instance of ApexListImpl.
      return _emptyInstance as ApexListImpl<E>;
    }
    // Basic implementation: start with empty and repeatedly add. Inefficient.
    // TODO: Actual implementation using builder/nodes for efficiency
    ApexList<E> list = emptyInstance<E>();
    for (final element in elements) {
      list = list.add(element);
    }
    // The final list will be an ApexListImpl instance because add returns ApexListImpl.
    return list as ApexListImpl<E>;
  }
  @override
  int get length => _length;

  @override
  bool get isEmpty => _length == 0;

  @override
  bool get isNotEmpty => _length > 0;

  // --- Element Access ---

  @override
  E operator [](int index) {
    // Check length first for a faster error in the empty case.
    if (isEmpty || index < 0 || index >= _length) {
      throw RangeError.index(index, this, 'index', null, _length);
    }
    // TODO: Incorporate tail/focus check before accessing root
    // _root.get will throw if _root is RrbEmptyNode, but the length check handles it first.
    return _root.get(index);
  }

  @override
  E get first {
    if (isEmpty) throw StateError('No element');
    return this[0]; // Reuse existing operator[]
  }

  @override
  E get last {
    if (isEmpty) throw StateError('No element');
    return this[_length - 1]; // Reuse existing operator[] and length
  }

  // --- Modification Operations ---

  @override
  ApexList<E> add(E value) {
    // TODO: Handle tail/focus optimization for amortized O(1) append.
    // Delegate directly to the root node's add method.
    // RrbEmptyNode.add returns a new RrbLeafNode.
    final newRoot = _root.add(value);
    // Note: add might return a node of increased height if the root splits.
    return ApexListImpl._(newRoot, _length + 1);
  }

  @override
  ApexList<E> addAll(Iterable<E> iterable) {
    // Basic implementation: repeatedly call add. Inefficient for large iterables.
    // TODO: Efficient bulk add, possibly using transient builder
    if (iterable.isEmpty) return this;

    ApexList<E> current = this;
    for (final element in iterable) {
      current = current.add(element); // Repeatedly calls the add method
    }
    return current;
  }

  @override
  ApexList<E> insert(int index, E value) {
    RangeError.checkValidIndex(
      index,
      this,
      'index',
      _length + 1,
    ); // Allow insertion at end
    // Basic implementation using sublist and concatenation. Inefficient.
    // TODO: Implement using efficient node operations (split/concat or specialized insert)
    if (index == _length) {
      // Optimization: Inserting at the end is just 'add'
      return add(value);
    }
    if (index == 0) {
      // Optimization: Inserting at the beginning
      // TODO: Implement efficient prepend
      return ApexList.from([value, ...this]); // Inefficient fallback
    }

    // General case: split, add, concat (relies on sublist and +)
    // These operations are currently unimplemented or inefficient.
    final firstPart = sublist(0, index);
    final secondPart = sublist(index); // sublist from index to end
    // This relies on operator+ being implemented, which currently throws.
    // Uses the basic (inefficient) sublist and operator+ implementations.
    return firstPart.add(value) + secondPart;
  }

  @override
  ApexList<E> insertAll(int index, Iterable<E> iterable) {
    RangeError.checkValidIndex(index, this, 'index', _length + 1);
    // Basic implementation: repeatedly call insert. Very inefficient.
    // TODO: Implement efficient bulk insert, possibly using transients or node concatenation.
    if (iterable.isEmpty) return this;

    ApexList<E> current = this;
    int offset = 0; // Keep track of insertion index shift
    for (final element in iterable) {
      current = current.insert(index + offset, element);
      offset++;
    }
    return current;
  }

  @override
  ApexList<E> removeAt(int index) {
    RangeError.checkValidIndex(index, this);
    if (isEmpty) {
      // Should be caught by checkValidIndex, but good practice
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot remove from empty list',
        0,
      );
    }

    // TODO: Handle tail/focus optimization

    final newRoot = _root.removeAt(index);

    if (newRoot == null || newRoot.isEmptyNode) {
      // The root node became empty
      return _emptyInstance
          as ApexListImpl<E>; // Return canonical impl empty list
    } else if (identical(newRoot, _root)) {
      // No change occurred (shouldn't happen if index is valid and list not empty)
      return this;
    } else {
      // Root changed (or potentially collapsed)
      return ApexListImpl._(newRoot, _length - 1);
    }
  }

  @override
  ApexList<E> remove(E value) {
    final index = indexOf(value); // Uses the basic O(N) indexOf for now
    if (index == -1) {
      return this; // Element not found, return original list
    }
    // Element found, remove it using the existing removeAt
    return removeAt(index);
  }

  @override
  ApexList<E> removeWhere(bool Function(E element) test) {
    // Basic implementation: build a new list excluding matching elements. Inefficient.
    // TODO: Iterate and build a new list more efficiently, potentially using transients
    final List<E> keptElements = [];
    bool changed = false;
    for (final element in this) {
      if (test(element)) {
        changed = true; // Mark that at least one element was removed
      } else {
        keptElements.add(element);
      }
    }

    if (!changed) {
      return this; // No elements matched the test, return original list
    }
    if (keptElements.isEmpty) {
      return emptyInstance<E>(); // All elements removed
    }
    // Create a new list from the elements that were kept using the now implemented factory.
    return ApexList.from(keptElements);
  }

  @override
  ApexList<E> sublist(int start, [int? end]) {
    final actualEnd = RangeError.checkValidRange(start, end, _length);
    final subLength = actualEnd - start;
    if (subLength <= 0) return emptyInstance<E>();
    if (start == 0 && actualEnd == _length)
      return this; // Sublist is the whole list

    // Basic implementation: iterate and add. Inefficient.
    // TODO: Implement efficient slicing using node operations
    ApexList<E> result = emptyInstance<E>();
    for (int i = start; i < actualEnd; i++) {
      result = result.add(this[i]); // Uses inefficient add and lookup
    }
    return result;
  }

  @override
  ApexList<E> update(int index, E value) {
    RangeError.checkValidIndex(index, this);
    // Length check handles empty case before calling _root.update
    if (isEmpty) {
      throw RangeError.index(index, this, 'index', null, 0);
    }
    // TODO: Incorporate tail/focus check
    final newRoot = _root.update(index, value);
    if (identical(newRoot, _root)) return this;
    return ApexListImpl._(newRoot, _length);
  }

  @override
  ApexList<E> operator +(ApexList<E> other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;

    if (other is ApexListImpl<E>) {
      // Basic implementation using addAll. Inefficient.
      // TODO: Implement efficient concatenation using node operations
      return addAll(other);
    } else {
      // Fallback for other Iterable types
      return ApexList.from([...this, ...other]);
    }
  }

  // --- Iterable Methods ---

  @override
  Iterator<E> get iterator => _RrbTreeIterator<E>(this);

  // --- Stubs for remaining Iterable methods ---
  // These should ideally delegate to the iterator or be optimized

  @override
  bool any(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return true;
    }
    return false;
  }

  @override
  Iterable<T> cast<T>() => map((e) => e as T); // Default cast via map

  @override
  bool contains(Object? element) {
    for (final e in this) {
      if (e == element) return true;
    }
    return false;
  }

  @override
  E elementAt(int index) {
    RangeError.checkValidIndex(index, this);
    return this[index]; // Reuse existing efficient lookup
  }

  @override
  bool every(bool Function(E element) test) {
    for (final element in this) {
      if (!test(element)) return false;
    }
    return true;
  }

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) sync* {
    for (final element in this) {
      yield* toElements(element);
    }
  }

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) {
    for (final element in this) {
      if (test(element)) return element;
    }
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) {
    var value = initialValue;
    for (final element in this) {
      value = combine(value, element);
    }
    return value;
  }

  @override
  Iterable<E> followedBy(Iterable<E> other) sync* {
    yield* this;
    yield* other;
  }

  @override
  void forEach(void Function(E element) action) {
    for (final element in this) {
      action(element);
    }
  }

  @override
  String join([String separator = '']) {
    final buffer = StringBuffer();
    var first = true;
    for (final element in this) {
      if (!first) buffer.write(separator);
      buffer.write(element);
      first = false;
    }
    return buffer.toString();
  }

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) {
    E? result;
    bool found = false;
    for (final element in this) {
      if (test(element)) {
        result = element;
        found = true;
      }
    }
    if (found) return result!;
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<T> map<T>(T Function(E e) convert) sync* {
    for (final element in this) {
      yield convert(element);
    }
  }

  @override
  E reduce(E Function(E value, E element) combine) {
    Iterator<E> iterator = this.iterator;
    if (!iterator.moveNext()) {
      throw StateError('No element');
    }
    E value = iterator.current;
    while (iterator.moveNext()) {
      value = combine(value, iterator.current);
    }
    return value;
  }

  @override
  E get single {
    Iterator<E> iterator = this.iterator;
    if (!iterator.moveNext()) throw StateError('No element');
    E result = iterator.current;
    if (iterator.moveNext()) throw StateError('Too many elements');
    return result;
  }

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) {
    E? result;
    bool found = false;
    for (final element in this) {
      if (test(element)) {
        if (found) throw StateError('Too many elements');
        result = element;
        found = true;
      }
    }
    if (found) return result!;
    if (orElse != null) return orElse();
    throw StateError('No element');
  }

  @override
  Iterable<E> skip(int count) sync* {
    RangeError.checkNotNegative(count, 'count');
    int skipped = 0;
    for (final element in this) {
      if (skipped >= count) {
        yield element;
      } else {
        skipped++;
      }
    }
  }

  @override
  Iterable<E> skipWhile(bool Function(E value) test) sync* {
    bool skipping = true;
    for (final element in this) {
      if (skipping && test(element)) continue;
      skipping = false;
      yield element;
    }
  }

  @override
  Iterable<E> take(int count) sync* {
    RangeError.checkNotNegative(count, 'count');
    if (count == 0) return;
    int taken = 0;
    for (final element in this) {
      yield element;
      taken++;
      if (taken == count) return;
    }
  }

  @override
  Iterable<E> takeWhile(bool Function(E value) test) sync* {
    for (final element in this) {
      if (!test(element)) return;
      yield element;
    }
  }

  @override
  List<E> toList({bool growable = true}) =>
      List<E>.of(this, growable: growable);

  @override
  Set<E> toSet() => Set<E>.of(this);

  @override
  Iterable<E> where(bool Function(E element) test) sync* {
    for (final element in this) {
      if (test(element)) yield element;
    }
  }

  @override
  Iterable<T> whereType<T>() sync* {
    for (final element in this) {
      if (element is T) yield element;
    }
  }

  // --- Added API Methods ---

  @override
  int indexOf(E element, [int start = 0]) {
    if (start < 0) start = 0;
    if (start >= _length) return -1;
    // TODO: Optimize search (e.g., using iterator or specialized node search)
    for (int i = start; i < _length; i++) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  @override
  int lastIndexOf(E element, [int? end]) {
    int start = end ?? _length - 1;
    if (start < 0) return -1;
    if (start >= _length) start = _length - 1;
    // TODO: Optimize search
    for (int i = start; i >= 0; i--) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  @override
  ApexList<E> clear() {
    return _emptyInstance
        as ApexListImpl<E>; // Return canonical impl empty list
  }

  @override
  Map<int, E> asMap() {
    // TODO: Optimize map creation
    final map = <int, E>{};
    for (int i = 0; i < _length; i++) {
      map[i] = this[i];
    }
    return map; // Return standard mutable map for now
  }

  @override
  ApexList<E> sort([int Function(E a, E b)? compare]) {
    final mutableList = toList();
    mutableList.sort(compare);
    // TODO: More efficient sort that builds the tree directly?
    return ApexList.from(mutableList);
  }

  @override
  ApexList<E> shuffle([Random? random]) {
    final mutableList = toList();
    mutableList.shuffle(random);
    return ApexList.from(mutableList);
  }

  // TODO: Implement efficient == and hashCode based on structural equality.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ApexList<E>) return false;
    if (length != other.length) return false;
    if (isEmpty && other.isEmpty) return true; // Both empty are equal
    // TODO: Optimize equality check using iterators or tree comparison
    return ListEquality<E>().equals(
      toList(growable: false),
      other.toList(growable: false),
    ); // Inefficient default
  }

  @override
  int get hashCode {
    if (isEmpty) return 0; // Consistent hash for empty
    // TODO: Optimize hash calculation using tree structure
    return ListEquality<E>().hash(
      toList(growable: false),
    ); // Inefficient default
  }
}

/// An iterator that traverses the elements of an RRB-Tree based ApexList.
class _RrbTreeIterator<E> implements Iterator<E> {
  final ApexListImpl<E> _list;
  int _currentIndex = -1;
  E? _currentElement;

  // TODO: Add state for efficient tree traversal (stack of nodes/indices)
  // For now, uses simple index-based access (inefficient).

  _RrbTreeIterator(this._list);

  @override
  E get current {
    // Note: Dart's Iterator contract expects current to be valid *after* moveNext returns true.
    // It doesn't require a check here if used correctly.
    // Adding a check can help catch misuse but isn't strictly necessary by contract.
    if (_currentIndex < 0 || _currentIndex >= _list.length) {
      // Or return null / throw? Standard iterators might throw here after exhaustion.
      // Let's stick to the potential null value for _currentElement.
      if (_currentElement == null)
        throw StateError('Iterator current is invalid state');
    }
    if (_currentElement == null)
      throw StateError(
        'Iterator current is invalid state (null)',
      ); // Should not happen if moveNext true
    return _currentElement!;
  }

  @override
  bool moveNext() {
    if (_currentIndex + 1 >= _list.length) {
      _currentElement = null; // Clear current element when iteration ends
      return false;
    }
    _currentIndex++;
    // Inefficient: uses repeated O(log N) lookups.
    // A proper iterator would maintain a stack/path through the tree.
    _currentElement = _list[_currentIndex];
    return true;
  }
}
