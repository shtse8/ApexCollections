import 'apex_list_api.dart';
import 'rrb_node.dart';

/// Concrete implementation of [ApexList] using an RRB-Tree.
class ApexListImpl<E> extends ApexList<E> {
  final RrbNode<E> _root;
  // TODO: Add tail/focus buffer for optimization
  final int _length;

  /// Internal constructor. Use factories like ApexList.empty() or ApexList.from().
  const ApexListImpl._(this._root, this._length);

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
    return this[0];
  }

  @override
  E get last {
    if (isEmpty) throw StateError('No element');
    return this[_length - 1];
  }

  // --- Modification Operations ---
  // These will delegate to the RrbNode methods, handle tail/focus,
  // and potentially create new ApexListImpl instances.

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
  // Most can rely on default implementations if using IterableMixin,
  // but overriding for efficiency using tree structure is often beneficial.

  @override
  Iterator<E> get iterator {
    // TODO: Implement efficient iterator traversing the RRB-Tree
    throw UnimplementedError('iterator');
  }

  // --- Other Iterable method implementations ---
  // Stubs for now, many could delegate to iterator logic later

  @override
  bool contains(Object? element) => throw UnimplementedError('contains');

  @override
  E elementAt(int index) => this[index]; // Can reuse operator[]

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) =>
      throw UnimplementedError('expand');

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) =>
      throw UnimplementedError('firstWhere');

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) =>
      throw UnimplementedError('fold');

  @override
  void forEach(void Function(E element) action) =>
      throw UnimplementedError('forEach');

  @override
  String join([String separator = '']) => throw UnimplementedError('join');

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) =>
      throw UnimplementedError('lastWhere');

  @override
  Iterable<T> map<T>(T Function(E e) convert) =>
      throw UnimplementedError('map');

  @override
  E reduce(E Function(E value, E element) combine) =>
      throw UnimplementedError('reduce');

  @override
  E get single => throw UnimplementedError('single');

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) =>
      throw UnimplementedError('singleWhere');

  @override
  Iterable<E> skip(int count) => throw UnimplementedError('skip');

  @override
  Iterable<E> skipWhile(bool Function(E value) test) =>
      throw UnimplementedError('skipWhile');

  @override
  Iterable<E> take(int count) => throw UnimplementedError('take');

  @override
  Iterable<E> takeWhile(bool Function(E value) test) =>
      throw UnimplementedError('takeWhile');

  @override
  List<E> toList({bool growable = true}) => throw UnimplementedError('toList');

  @override
  Set<E> toSet() => throw UnimplementedError('toSet');

  @override
  Iterable<E> where(bool Function(E element) test) =>
      throw UnimplementedError('where');

  @override
  Iterable<T> whereType<T>() => throw UnimplementedError('whereType');

  @override
  bool any(bool Function(E element) test) => throw UnimplementedError('any');

  @override
  bool every(bool Function(E element) test) =>
      throw UnimplementedError('every');

  @override
  Iterable<T> cast<T>() => throw UnimplementedError('cast');

  @override
  Iterable<E> followedBy(Iterable<E> other) =>
      throw UnimplementedError('followedBy');

  // TODO: Implement == and hashCode.
  @override
  bool operator ==(Object other) => throw UnimplementedError('operator ==');

  @override
  int get hashCode => throw UnimplementedError('hashCode');
}

// Need to link the factory constructor in the API file to this implementation
// This requires modifying apex_list_api.dart slightly.
