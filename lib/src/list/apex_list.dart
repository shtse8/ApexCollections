import 'package:collection/collection.dart'; // For IterableMixin if needed later
import 'apex_list_api.dart';
import 'rrb_node.dart';

/// Concrete implementation of [ApexList] using an RRB-Tree.
class ApexListImpl<E> extends ApexList<E> {
  final RrbNode<E> _root;
  // TODO: Add tail/focus buffer for optimization
  final int _length;

  /// Internal constructor. Use factories like ApexList.empty() or ApexList.from().
  const ApexListImpl._(this._root, this._length);

  /// Factory constructor to create from an Iterable.
  factory ApexListImpl.fromIterable(Iterable<E> elements) {
    if (elements.isEmpty) {
      // How to return the const empty instance? Need access to ApexList.empty() or a static const field.
      // This requires linking the API and Impl properly, maybe via a shared const instance.
      // For now, assume ApexList.empty() works (it points to _EmptyApexList).
      // A better approach might be needed later.
      return ApexList.empty()
          as ApexListImpl<
            E
          >; // Cast needed, potentially unsafe if empty isn't this type
      // throw UnimplementedError('Cannot return empty list from impl factory yet');
    }
    // TODO: Actual implementation using builder/nodes
    throw UnimplementedError('ApexListImpl.fromIterable');
  }

  // --- Core Properties ---

  @override
  int get length => _length;

  @override
  bool get isEmpty => _length == 0;

  @override
  bool get isNotEmpty => _length > 0;

  // --- Element Access ---

  @override
  E operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError.index(index, this, 'index', null, _length);
    }
    // TODO: Incorporate tail/focus check before accessing root
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
    // TODO: Handle tail/focus optimization
    // TODO: Call _root.add or create new root if needed
    throw UnimplementedError('add');
  }

  @override
  ApexList<E> addAll(Iterable<E> iterable) {
    // TODO: Efficient bulk add, possibly using transient builder
    throw UnimplementedError('addAll');
  }

  @override
  ApexList<E> insert(int index, E value) {
    RangeError.checkValidIndex(
      index,
      this,
      'index',
      _length + 1,
    ); // Allow insertion at end
    // TODO: Implement using node operations (split/concat or specialized insert)
    throw UnimplementedError('insert');
  }

  @override
  ApexList<E> insertAll(int index, Iterable<E> iterable) {
    RangeError.checkValidIndex(index, this, 'index', _length + 1);
    // TODO: Implement efficient bulk insert
    throw UnimplementedError('insertAll');
  }

  @override
  ApexList<E> removeAt(int index) {
    RangeError.checkValidIndex(index, this);
    // TODO: Implement using node operations
    throw UnimplementedError('removeAt');
  }

  @override
  ApexList<E> remove(E value) {
    // TODO: Find index first (O(N)), then call removeAt (O(log N))
    throw UnimplementedError('remove');
  }

  @override
  ApexList<E> removeWhere(bool Function(E element) test) {
    // TODO: Iterate and build a new list, potentially using transients
    throw UnimplementedError('removeWhere');
  }

  @override
  ApexList<E> sublist(int start, [int? end]) {
    final actualEnd = RangeError.checkValidRange(start, end, _length);
    // TODO: Implement efficient slicing using node operations
    throw UnimplementedError('sublist');
  }

  @override
  ApexList<E> update(int index, E value) {
    RangeError.checkValidIndex(index, this);
    // TODO: Incorporate tail/focus check
    final newRoot = _root.update(index, value);
    if (identical(newRoot, _root)) return this;
    return ApexListImpl._(newRoot, _length);
  }

  @override
  ApexList<E> operator +(ApexList<E> other) {
    if (other is ApexListImpl<E>) {
      // TODO: Implement efficient concatenation using node operations
      throw UnimplementedError('concat');
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

  // TODO: Implement == and hashCode based on structural equality.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApexList<E> &&
          length == other.length &&
          ListEquality<E>().equals(
            toList(growable: false),
            other.toList(growable: false),
          )); // Inefficient default

  @override
  int get hashCode => ListEquality<E>().hash(toList(growable: false)); // Inefficient default
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
