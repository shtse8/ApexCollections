import 'dart:math'; // For Random
import 'package:collection/collection.dart'; // For ListEquality
import 'apex_list_api.dart';
import 'rrb_node.dart' as rrb; // Use prefix for node types and constants

/// Concrete implementation of [ApexList] using an RRB-Tree.
class ApexListImpl<E> extends ApexList<E> {
  /// The root node of the RRB-Tree. Can be RrbEmptyNode.
  final rrb.RrbNode<E> _root;
  // TODO: Add tail/focus buffer for optimization

  /// The number of elements in the list.
  final int _length;

  /// The canonical empty instance.
  /// The canonical empty instance (internal).
  // Cache for empty instances per type E. Expando allows associating a value
  // with a type object without modifying the Type class itself.
  static final Expando<ApexListImpl> _emptyCache = Expando<ApexListImpl>();

  /// Public accessor for the canonical empty instance for a given type E.
  static ApexListImpl<E> emptyInstance<E>() {
    // Retrieve or create and cache the empty instance for type E.
    // The cast `as rrb.RrbNode<E>` is necessary because the static
    // instance is RrbEmptyNode<Never>. This cast is generally safe for the
    // empty node case, as operations will typically check isEmptyNode first
    // or create new nodes with the correct type E.
    // The final `as ApexListImpl<E>` is needed because the Expando stores ApexListImpl<dynamic>.
    return (_emptyCache[E] ??= ApexListImpl<E>._(
          rrb.RrbEmptyNode.instance
              as rrb.RrbNode<E>, // Cast the shared Never node
          0,
        ))
        as ApexListImpl<E>;
  }

  /// Internal constructor (cannot be const due to Expando cache).
  ApexListImpl._(this._root, this._length);

  /// Factory constructor to create from an Iterable.
  factory ApexListImpl.fromIterable(Iterable<E> elements) {
    final List<E> sourceList;
    if (elements is List<E>) {
      sourceList = elements;
    } else {
      sourceList = List<E>.of(elements, growable: false);
    }

    final int totalLength = sourceList.length;
    if (totalLength == 0) {
      return emptyInstance<E>();
    }

    // --- Build Leaf Nodes ---
    List<rrb.RrbNode<E>> currentLevelNodes = [];
    for (int i = 0; i < totalLength; i += rrb.kBranchingFactor) {
      // Use constant from rrb
      final end =
          (i + rrb.kBranchingFactor < totalLength)
              ? i + rrb.kBranchingFactor
              : totalLength;
      currentLevelNodes.add(rrb.RrbLeafNode<E>(sourceList.sublist(i, end)));
    }

    // --- Build Internal Nodes ---
    int currentHeight = 0;
    while (currentLevelNodes.length > 1) {
      currentHeight++;
      List<rrb.RrbNode<E>> parentLevelNodes = [];
      for (int i = 0; i < currentLevelNodes.length; i += rrb.kBranchingFactor) {
        // Use constant from rrb
        final end =
            (i + rrb.kBranchingFactor < currentLevelNodes.length)
                ? i + rrb.kBranchingFactor
                : currentLevelNodes.length;
        final childrenChunk = currentLevelNodes.sublist(i, end);

        // Calculate count and size table for the new parent node
        int parentCount = 0;
        List<int>? parentSizeTable = _computeSizeTableIfNeeded<E>(
          // Pass type argument
          childrenChunk,
          currentHeight,
        );
        if (parentSizeTable != null) {
          parentCount = parentSizeTable.last;
        } else {
          // If strict, calculate count based on expected full children
          int fullChildCount =
              1 <<
              (currentHeight *
                  rrb.kLog2BranchingFactor); // Use constant from rrb
          parentCount =
              (childrenChunk.length - 1) * fullChildCount +
              childrenChunk.last.count;
        }

        parentLevelNodes.add(
          rrb.RrbInternalNode<E>(
            // Use prefixed type
            currentHeight,
            parentCount,
            childrenChunk,
            parentSizeTable,
          ),
        );
      }
      currentLevelNodes = parentLevelNodes;
    }

    // The single remaining node is the root
    final rootNode = currentLevelNodes[0];
    return ApexListImpl._(rootNode, totalLength);
  }

  /// Computes a size table for a list of children nodes at a given height,
  /// returning null if the resulting parent node would be strict.
  /// (Helper for fromIterable constructor)
  static List<int>? _computeSizeTableIfNeeded<E>(
    List<rrb.RrbNode<E>> children, // Use prefixed type
    int parentHeight,
  ) {
    if (children.isEmpty) return null;

    bool needsTable = false;
    int expectedChildSize = -1;

    // Determine expected size based on child height
    final childHeight = parentHeight - 1;
    if (childHeight > 0) {
      // Internal node children
      expectedChildSize =
          1 <<
          (childHeight * rrb.kLog2BranchingFactor); // Use constant from rrb
    } else {
      // Leaf node children
      expectedChildSize = rrb.kBranchingFactor;
    }

    int cumulativeCount = 0;
    final sizeTable = List<int>.filled(children.length, 0);
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      cumulativeCount += child.count;
      sizeTable[i] = cumulativeCount;
      // Check if relaxation is needed (don't need to check the last child)
      if (i < children.length - 1 && child.count != expectedChildSize) {
        needsTable = true;
      }
    }
    return needsTable ? sizeTable : null;
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
    final rrb.RrbNode<E> newRoot;
    if (_root.isEmptyNode) {
      // Special case: Adding to empty creates the first leaf directly with type E.
      newRoot = rrb.RrbLeafNode<E>([value]);
    } else {
      // Delegate to the existing root node's add method.
      newRoot = _root.add(value);
    }
    // Note: add might return a node of increased height if the root splits.
    return ApexListImpl._(newRoot, _length + 1);
  }

  @override
  ApexList<E> addAll(Iterable<E> iterable) {
    // Optimize for empty iterable
    if (iterable is List && iterable.isEmpty) return this;
    if (iterable is Set && iterable.isEmpty) return this;
    // Note: Cannot reliably check general Iterable for emptiness without iterating

    // Special case: Adding to an empty list is just creating a new list from the iterable
    if (isEmpty) {
      // Avoid creating intermediate list if possible
      if (iterable is ApexList<E>) return iterable;
      // Use the efficient factory constructor directly
      return ApexListImpl<E>.fromIterable(iterable);
    }

    // TODO: Implement truly efficient bulk add using transients or node concatenation.
    // Intermediate approach: Build a combined List dynamically and create ApexList once.
    final combinedElements = List<E>.empty(growable: true);
    combinedElements.addAll(this); // Add existing elements
    combinedElements.addAll(iterable); // Add new elements

    // Build the new list from the combined elements using the efficient factory.
    return ApexListImpl<E>.fromIterable(combinedElements);
  }

  @override
  ApexList<E> insert(int index, E value) {
    // Allow insertion at index == _length (appending)
    RangeError.checkValidIndex(index, this, 'index', _length + 1);

    final rrb.RrbNode<E> newRoot;
    if (_root.isEmptyNode) {
      // Special case: Inserting into empty list (index must be 0)
      if (index != 0) {
        // This should be caught by checkValidIndex, but double-check.
        throw RangeError.index(
          index,
          this,
          'index',
          'Index must be 0 for empty list',
          1,
        );
      }
      newRoot = rrb.RrbLeafNode<E>([value]);
    } else {
      // Delegate to the existing root node's insertAt method.
      newRoot = _root.insertAt(index, value);
    }

    // If the root reference didn't change, return original.
    if (identical(newRoot, _root)) {
      return this;
    }

    return ApexListImpl._(newRoot, _length + 1);
  }

  @override
  ApexList<E> insertAll(int index, Iterable<E> iterable) {
    RangeError.checkValidIndex(index, this, 'index', _length + 1);

    // Optimize for empty iterable
    if (iterable is List && iterable.isEmpty) return this;
    if (iterable is Set && iterable.isEmpty) return this;

    // Special case: Inserting into empty list
    if (isEmpty) {
      if (index != 0) {
        // This should be caught by checkValidIndex, but double-check.
        throw RangeError.index(
          index,
          this,
          'index',
          'Index must be 0 for empty list',
          1,
        );
      }
      // Avoid creating intermediate list if possible
      if (iterable is ApexList<E>) return iterable;
      // Use the efficient factory constructor directly
      return ApexListImpl<E>.fromIterable(iterable);
    }

    // TODO: Implement truly efficient bulk insert using transients or node concatenation.
    // Intermediate approach: Build a combined List dynamically and create ApexList once.
    final List<E> elementsToInsert =
        (iterable is List<E>) ? iterable : List<E>.of(iterable);

    if (elementsToInsert.isEmpty)
      return this; // Handle empty iterable after potential conversion

    final combinedElements = List<E>.empty(growable: true);
    int currentIndex = 0;

    // Add elements before insertion point
    for (final element in this) {
      if (currentIndex == index) break;
      combinedElements.add(element);
      currentIndex++;
    }

    // Add new elements
    combinedElements.addAll(elementsToInsert);

    // Add elements after insertion point
    // Need to skip elements already added if using iterator
    currentIndex = 0; // Reset index for the second loop
    for (final element in this) {
      if (currentIndex >= index) {
        combinedElements.add(element);
      }
      currentIndex++;
    }

    // Build the new list from the combined elements using the efficient factory.
    return ApexListImpl<E>.fromIterable(combinedElements);
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
      return emptyInstance<E>(); // Use the getter for the typed empty instance
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
    if (isEmpty) return this;

    // TODO: Implement truly efficient bulk remove using transients/builders.
    // Intermediate approach: Iterate and build new tree structure directly.
    ApexListImpl<E> newList = emptyInstance<E>(); // Start with an empty list
    int newLength = 0;
    bool changed = false;

    // Use the efficient iterator
    for (final element in this) {
      if (test(element)) {
        changed = true; // Mark that at least one element needs removal
      } else {
        // Add element to the new list being built
        // Use the internal constructor and add method for potential efficiency
        // (though add currently delegates to node.add)
        newList = ApexListImpl._(newList._root.add(element), newLength + 1);
        newLength++;
      }
    }

    if (!changed) {
      return this; // No elements matched the test, return original list
    }
    // newList already holds the result, no need to check isEmpty separately
    return newList;
  }

  @override
  ApexList<E> sublist(int start, [int? end]) {
    // Standard List.sublist range checks:
    // 1. Check start bounds (0 <= start <= length)
    if (start < 0 || start > _length) {
      throw RangeError.range(start, 0, _length, "start");
    }
    // 2. Determine effective end and check its bounds (start <= end <= length)
    int effectiveEnd = end ?? _length;
    if (effectiveEnd < start || effectiveEnd > _length) {
      throw RangeError.range(effectiveEnd, start, _length, "end");
    }

    // If range is empty, return empty instance
    final subLength = effectiveEnd - start;
    if (subLength <= 0) {
      return emptyInstance<E>();
    }
    // If range covers the whole list, return this instance
    if (start == 0 && effectiveEnd == _length) {
      return this;
    }
    // Note: Use effectiveEnd for the rest of the logic now
    final actualEnd = effectiveEnd;

    // TODO: Implement truly efficient slicing using node operations (e.g., splitAt)
    //       if/when available in rrb_node.dart. This would avoid iterating
    //       and rebuilding the tree structure for the sublist range.
    // Current approach: Use the iterator to gather elements efficiently,
    // then build a new list using the factory. O(M) where M is sublist length,
    // but with higher constant factors due to iteration and tree rebuild.
    final sublistElements = List<E>.empty(growable: true);
    int currentIndex = 0;
    for (final element in this) {
      // Uses the efficient _RrbTreeIterator
      if (currentIndex >= actualEnd) break; // Stop after reaching the end index
      if (currentIndex >= start) {
        sublistElements.add(element);
      }
      currentIndex++;
    }

    // Build the new list from the gathered elements using the efficient factory.
    return ApexListImpl<E>.fromIterable(sublistElements);
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
    if (isEmpty)
      return other; // Should already be ApexList<E> due to type system

    // TODO: Implement truly efficient concatenation using node joining operations
    //       (e.g., concatenate or join) if/when available in rrb_node.dart.
    //       This would avoid iterating both lists and rebuilding the tree.
    // Current approach: Iterate both lists and build a new one using the factory.
    // O(N+M) where N and M are lengths, but with higher constant factors.
    final combinedElements = List<E>.empty(growable: true);
    combinedElements.addAll(this); // Add elements from 'this'
    combinedElements.addAll(other); // Add elements from 'other'

    // Build the new list from the combined elements using the efficient factory.
    return ApexListImpl<E>.fromIterable(combinedElements);
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

    // Use the efficient iterator for O(N) search.
    int index = 0;
    for (final currentElement in this) {
      // Uses _RrbTreeIterator
      if (index >= start) {
        if (currentElement == element) {
          return index;
        }
      }
      // Optimization: Stop early if we've passed the end of the list
      // (Shouldn't be necessary with a correct iterator, but safe).
      if (index >= _length - 1) break;
      index++;
    }
    return -1;
  }

  @override
  int lastIndexOf(E element, [int? end]) {
    int startIndex = end ?? _length - 1;
    if (startIndex < 0) return -1;
    if (startIndex >= _length) startIndex = _length - 1; // Clamp to valid range

    // Iterate forward using efficient iterator, keeping track of the last match.
    int lastIndex = -1;
    int currentIndex = 0;
    for (final currentElement in this) {
      if (currentIndex > startIndex)
        break; // Stop if we've passed the search range
      if (currentElement == element) {
        lastIndex = currentIndex;
      }
      currentIndex++;
    }
    return lastIndex;
  }

  @override
  ApexList<E> clear() {
    // Return the canonical empty instance for this type via the getter
    return emptyInstance<E>();
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
    if (length <= 1) return this; // Already sorted

    // Standard approach: convert to mutable, sort, rebuild efficiently.
    final mutableList = toList(
      growable: false,
    ); // Use non-growable for potential efficiency
    mutableList.sort(compare);

    // Check if the list was already sorted (optimization)
    // This requires iterating again, might not be worth it unless lists are often pre-sorted.
    // bool wasSorted = true;
    // for(int i = 0; i < length; ++i) {
    //   if (!identical(this[i], mutableList[i])) { // Use identical for perf? Or == ?
    //      wasSorted = false;
    //      break;
    //   }
    // }
    // if (wasSorted) return this;

    // Rebuild using the efficient factory constructor.
    return ApexListImpl<E>.fromIterable(mutableList);
  }

  @override
  ApexList<E> shuffle([Random? random]) {
    if (length <= 1) return this; // No shuffling needed

    // Standard approach: convert to mutable, shuffle, rebuild efficiently.
    final mutableList = toList(
      growable: true,
    ); // Needs to be growable for List.shuffle
    mutableList.shuffle(random);

    // Rebuild using the efficient factory constructor.
    return ApexListImpl<E>.fromIterable(mutableList);
  }

  // TODO: Implement efficient == and hashCode based on structural equality.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Use `is` for type check, works correctly with subtypes.
    if (other is ApexList<E>) {
      if (length != other.length) return false;
      if (isEmpty) return true; // Both empty and same length

      // Efficient comparison using iterators
      final thisIterator = iterator;
      final otherIterator = other.iterator;
      while (thisIterator.moveNext()) {
        if (!otherIterator.moveNext() ||
            thisIterator.current != otherIterator.current) {
          return false;
        }
      }
      // If we finish thisIterator, otherIterator should also be finished if lengths match.
      // No need for !otherIterator.moveNext() check here due to length check earlier.
      return true;
    }
    return false; // Not an ApexList<E>
  }

  @override
  int get hashCode {
    // Based on the standard Jenkins hash combination used in ListEquality/Objects.hash
    // https://api.dart.dev/stable/3.4.3/dart-core/Object/hashCode.html
    if (isEmpty) return 1; // Or some other constant for empty

    int result = 0;
    for (final element in this) {
      // Uses efficient iterator
      int h = element.hashCode;
      result = 0x1fffffff & (result + h); // Combine with addition
      result =
          0x1fffffff & (result + ((0x0007ffff & result) << 10)); // Shuffle bits
      result = result ^ (result >> 6); // XOR shift
    }
    result =
        0x1fffffff & (result + ((0x03ffffff & result) << 3)); // Final shuffle
    result = result ^ (result >> 11); // Final XOR shift
    return 0x1fffffff &
        (result + ((0x00003fff & result) << 15)); // Final combine
  }
} // <<< THIS IS THE CORRECT CLOSING BRACE FOR ApexListImpl

/// Efficient iterator for traversing the RRB-Tree.
class _RrbTreeIterator<E> implements Iterator<E> {
  // Stack storing nodes currently being iterated.
  final List<rrb.RrbNode<E>> _nodeStack = []; // Use prefixed type
  // Stack storing the next child/element index to visit within the node at the same stack level.
  final List<int> _indexStack = [];

  E? _currentElement;

  _RrbTreeIterator(ApexListImpl<E> list) {
    if (!list.isEmpty) {
      _pushNode(list._root);
    }
  }

  /// Pushes an internal node onto the stack to start iterating its children.
  void _pushNode(rrb.RrbNode<E> node) {
    // Use prefixed type
    _nodeStack.add(node);
    _indexStack.add(0); // Start iteration from the first child/element
  }

  @override
  E get current {
    if (_currentElement == null) {
      // moveNext must be called and return true before accessing current.
      throw StateError('No current element. Call moveNext() first.');
    }
    return _currentElement!;
  }

  @override
  bool moveNext() {
    while (_nodeStack.isNotEmpty) {
      final node = _nodeStack.last;
      final index = _indexStack.last;

      if (node is rrb.RrbLeafNode<E>) {
        // Use prefixed type
        // Leaf node: yield the element at the current index
        if (index < node.elements.length) {
          _currentElement = node.elements[index];
          _indexStack[_indexStack.length -
              1]++; // Move to next element in this leaf
          return true;
        } else {
          // Finished with this leaf node, pop it
          _nodeStack.removeLast();
          _indexStack.removeLast();
          continue; // Continue with the parent node
        }
      } else if (node is rrb.RrbInternalNode<E>) {
        // Use prefixed type
        // Internal node: descend into the next child
        if (index < node.children.length) {
          _indexStack[_indexStack.length -
              1]++; // Move to next child in this internal node
          _pushNode(node.children[index]); // Push the child node to explore
          continue; // Restart loop to process the newly pushed node
        } else {
          // Finished with this internal node's children, pop it
          _nodeStack.removeLast();
          _indexStack.removeLast();
          continue; // Continue with the parent node
        }
      } else {
        // Should not happen if root wasn't empty (RrbEmptyNode case handled in constructor)
        _nodeStack.removeLast();
        _indexStack.removeLast();
      }
    }

    // Stack is empty, iteration complete
    _currentElement = null; // Invalidate current
    return false;
  }
}
