import 'dart:math'; // For Random
import 'package:collection/collection.dart'; // For ListEquality
import 'apex_list_api.dart';
// Import the split node files with the same prefix 'rrb'
import 'rrb_node_base.dart' as rrb;
import 'rrb_leaf_node.dart' as rrb;
import 'rrb_internal_node.dart' as rrb;
import 'rrb_tree_utils.dart' as treeUtils; // Import the extracted utils

/// Concrete implementation of [ApexList] using a Relaxed Radix Balanced Tree (RRB-Tree).
///
/// This class provides the internal logic and data structures for the immutable list.
/// It should generally not be used directly; prefer using the factories on [ApexList]
/// like [ApexList.empty], [ApexList.from], etc.
class ApexListImpl<E> extends ApexList<E> {
  /// The root node of the RRB-Tree.
  /// This can be an [rrb.RrbInternalNode], [rrb.RrbLeafNode], or the canonical
  /// empty leaf node instance.
  final rrb.RrbNode<E> _root;
  // TODO: Add tail/focus buffer for optimization

  /// The total number of elements in the list, cached for O(1) access.
  final int _length;

  /// Cache for canonical empty instances, keyed by element type.
  /// Uses an [Expando] to associate the empty instance with the type object.
  static final Expando _emptyCache = Expando(); // Use non-generic Expando

  /// Public accessor for the canonical empty instance for a given type E.
  /// Ensures that all empty lists of the same type share the same instance.
  static ApexListImpl<E> emptyInstance<E>() {
    // Retrieve or create and cache the empty instance for type E.
    return (_emptyCache[E] ??= ApexListImpl<E>._(
          rrb.RrbLeafNode.emptyInstance
              as rrb.RrbNode<E>, // Cast the shared Never node
          0,
        ))
        as ApexListImpl<E>;
  }

  /// Internal getter for debugging purposes, exposing the root node.
  /// **Warning:** Should not be used in production code.
  rrb.RrbNode<E>? get debugRoot => _root;

  /// Internal constructor to create an [ApexListImpl] instance.
  /// Takes the [root] node and the pre-calculated [length].
  ApexListImpl._(this._root, this._length);

  /// Factory constructor to create an [ApexListImpl] from an [Iterable].
  ///
  /// Creates an [ApexList] by efficiently building an RRB-Tree from the
  /// given [elements]. It uses a recursive divide-and-conquer strategy,
  /// building sub-trees from halves of the input and concatenating them using
  /// [treeUtils.concatenateTrees]. This approach optimizes for subsequent fast
  /// lookups (`[]`, ~0.15us for 10k) and sublist operations (~5.8us for 10k),
  /// though the initial build time (~2960us for 10k) might be higher than
  /// alternative strategies or competitors like FIC.
  /// operations, though the initial build time might be slightly higher
  /// than a purely bottom-up approach for very large inputs.
  ///
  /// If [elements] is already an [ApexList], it is returned directly without modification.
  /// If [elements] is a standard [List], it's used directly. Other [Iterable] types
  /// are first converted to a [List].
  factory ApexListImpl.fromIterable(Iterable<E> elements) {
    // Optimization: If input is already an ApexListImpl, return it directly.
    if (elements is ApexListImpl<E>) {
      return elements;
    }

    final List<E> sourceList;
    // Optimization: Avoid copying if it's already a List.
    if (elements is List<E>) {
      sourceList = elements;
    } else {
      // Materialize other iterables into a list first.
      sourceList = List<E>.of(elements, growable: false);
    }

    final int totalLength = sourceList.length;
    if (totalLength == 0) {
      return emptyInstance<E>();
    }

    // --- Use Recursive Concatenation Building ---
    final owner = rrb.TransientOwner();

    // Build the tree recursively using the helper
    final rootNode = _buildTreeFromRange<E>(sourceList, 0, totalLength, owner);

    // Freeze the potentially transient tree structure built by the helper
    final frozenRoot = rootNode.freeze(owner);
    return ApexListImpl._(frozenRoot, totalLength);
  }

  /// Recursive helper to build an RRB-Tree (potentially transient) from a range of elements.
  /// Uses a divide-and-conquer concatenation strategy.
  static rrb.RrbNode<E> _buildTreeFromRange<E>(
    List<E> sourceList,
    int start,
    int end,
    rrb.TransientOwner owner,
  ) {
    final rangeLength = end - start;

    // Base Case 1: Empty range
    if (rangeLength <= 0) {
      // Return the non-typed empty instance, it will be cast later if needed.
      // Or handle type casting carefully if returning ApexListImpl.emptyInstance<E>()._root
      return rrb.RrbLeafNode.emptyInstance as rrb.RrbNode<E>;
    }

    // Base Case 2: Small range fits in a single leaf node
    if (rangeLength <= rrb.kBranchingFactor) {
      return rrb.RrbLeafNode<E>.fromRange(sourceList, start, end, owner);
    }

    // Recursive Step: Split range, build subtrees, concatenate
    final mid = start + (rangeLength ~/ 2); // Find midpoint

    // Recursively build left and right subtrees (passing the owner)
    final leftNode = _buildTreeFromRange<E>(sourceList, start, mid, owner);
    final rightNode = _buildTreeFromRange<E>(sourceList, mid, end, owner);

    // Concatenate the resulting nodes.
    // Note: concatenateTrees currently returns an immutable node.
    // We rely on the final freeze operation outside this recursive call.
    // A fully transient concatenation might be more optimal but adds complexity.
    return treeUtils.concatenateTrees<E>(
      leftNode,
      mid - start, // Length of left part
      rightNode,
      end - mid, // Length of right part
    );
  }

  // *** REMOVED _computeSizeTableIfNeeded ***

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
    // Check length instead of isEmptyNode
    if (isEmpty) {
      // Special case: Adding to empty creates the first leaf directly with type E.
      newRoot = rrb.RrbLeafNode<E>([value]);
    } else {
      // Delegate to the existing root node's add method.
      newRoot = _root.add(value);
    }
    // Note: add might return a node of increased height if the root splits.
    return ApexListImpl._(newRoot, _length + 1);
  }

  /// Returns a new list containing all elements of this list followed by all
  /// elements of the [iterable].
  ///
  /// This operation is optimized by creating a new [ApexList] from the [iterable]
  /// (if it's not already one) and then concatenating the underlying RRB-Trees
  /// of the two lists using [treeUtils.concatenateTrees] in O(log N) time,
  /// where N is the combined size. Performance is excellent (~31us for 10k).
  @override
  ApexList<E> addAll(Iterable<E> iterable) {
    // Optimize for empty iterable
    final List<E> elementsToAdd;
    if (iterable is List<E>) {
      if (iterable.isEmpty) return this;
      elementsToAdd = iterable; // Avoid copying if already a List
    } else if (iterable is Set<E>) {
      if (iterable.isEmpty) return this;
      elementsToAdd = List<E>.of(iterable, growable: false); // Convert Set once
    } else {
      elementsToAdd = List<E>.of(
        iterable,
        growable: false,
      ); // Convert general Iterable once
      if (elementsToAdd.isEmpty) return this;
    }
    // Now elementsToAdd is guaranteed non-empty

    // Special case: Adding to an empty list is just creating a new list from the iterable
    if (isEmpty) {
      // Use the efficient factory constructor directly
      return ApexListImpl<E>.fromIterable(elementsToAdd);
    }

    // --- New Strategy: Create list from iterable and concatenate ---
    // Create a new ApexList from the elements to add using the efficient factory.
    final listToAdd = ApexListImpl<E>.fromIterable(elementsToAdd);

    // Concatenate the current list's tree with the new list's tree.
    final newRoot = treeUtils.concatenateTrees<E>(
      _root,
      _length,
      listToAdd._root, // Access internal root of the new list
      listToAdd.length,
    );
    final newLength = _length + listToAdd.length;

    // Return new instance with the concatenated root and updated count.
    return ApexListImpl<E>._(newRoot, newLength);
  }

  @override
  ApexList<E> insert(int index, E value) {
    // Allow insertion at index == _length (appending)
    RangeError.checkValidIndex(index, this, 'index', _length + 1);

    final rrb.RrbNode<E> newRoot;
    // Check length instead of isEmptyNode
    if (isEmpty) {
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

    // RrbNode.removeAt now returns null if the node becomes empty.
    if (newRoot == null) {
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

    // --- Immutable Approach ---
    // Iterate, collect elements to keep, and build a new list.
    // Benchmarks showed a transient approach wasn't significantly better here,
    // so the simpler immutable filter-and-rebuild strategy is used.
    final elementsToKeep = <E>[];
    bool changed = false;
    for (final element in this) {
      // Uses efficient iterator
      if (!test(element)) {
        elementsToKeep.add(element);
      } else {
        changed = true; // Mark that at least one element was removed
      }
    }

    // If no elements were removed, return the original list.
    if (!changed) {
      return this;
    }
    // If all elements were removed, return empty.
    if (elementsToKeep.isEmpty) {
      return emptyInstance<E>();
    }

    // Build a new list from the elements to keep using the efficient factory.
    return ApexListImpl<E>.fromIterable(elementsToKeep);
  }

  @override
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

    // Use the efficient O(log N) tree slicing helper from treeUtils.
    // Performance is excellent (~5.8us for 10k).
    final slicedNode = treeUtils.sliceTree<E>(_root, start, actualEnd);

    if (slicedNode == null) {
      // _sliceTree returns null if the resulting slice is empty.
      return emptyInstance<E>();
    } else {
      // Create a new ApexListImpl with the sliced node and calculated length.
      return ApexListImpl<E>._(slicedNode, subLength);
    }
  }

  // *** REMOVED _sliceTree ***

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
    if (isEmpty) return other; // Already ApexList<E>

    // Efficient O(log N) concatenation using the tree utility function.
    // Performance is very good (~7.2us for 10k).
    final newRoot = treeUtils.concatenateTrees<E>(
      _root,
      _length,
      (other as ApexListImpl<E>)._root, // Cast to access internal root
      other.length,
    );
    final newLength = _length + other.length;
    return ApexListImpl<E>._(newRoot, newLength);
  }

  // *** REMOVED _concatenateTrees ***
  // *** REMOVED _concatenateNodes ***
  // *** REMOVED _rebuildConcatenatedPath ***
  // *** REMOVED _rebuildConcatenatedPathReversed ***

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
  @override
  @override
  List<E> toList({bool growable = true}) {
    if (isEmpty) {
      // Return an empty list of the correct growable type directly.
      return growable ? <E>[] : List<E>.empty(growable: false);
    }

    // Use pre-allocation with a recursive helper for potentially better performance.
    // Create a nullable list first to avoid issues with non-nullable E and List.filled placeholder.
    final list = List<E?>.filled(_length, null, growable: growable);
    _fillListFromNode<E>(list, _root, 0); // Call the static helper

    // Cast back to List<E>. Assumes _fillListFromNode correctly filled all slots.
    // If E is non-nullable, any remaining nulls would cause runtime error on access,
    // but this shouldn't happen if _length and tree structure are consistent.
    final filledList = list.cast<E>();

    // Return based on growable flag.
    // If growable=true, the cast list is already growable.
    // If growable=false, create a fixed-length list from the cast list.
    return growable ? filledList : List<E>.of(filledList, growable: false);
  }

  /// Recursive helper to fill a pre-allocated list from the RRB-Tree nodes.
  /// Returns the number of elements written by this node and its children.
  static int _fillListFromNode<E>(
    List<E?> targetList,
    rrb.RrbNode<E> node,
    int targetStartIndex,
  ) {
    if (node is rrb.RrbLeafNode<E>) {
      // Base case: Leaf node
      final elements = node.elements;
      final count = elements.length;
      // Directly copy elements to the target list range
      targetList.setRange(targetStartIndex, targetStartIndex + count, elements);
      return count;
    } else if (node is rrb.RrbInternalNode<E>) {
      // Recursive step: Internal node
      int currentWriteIndex = targetStartIndex;
      int totalWritten = 0;
      for (final child in node.children) {
        final elementsWritten = _fillListFromNode(
          targetList,
          child,
          currentWriteIndex,
        );
        currentWriteIndex += elementsWritten;
        totalWritten += elementsWritten;
      }
      return totalWritten;
    } else {
      // Empty node case (shouldn't be reached if initial isEmpty check passes)
      return 0;
    }
  }

  // Note: The static _fillListFromNode helper above is used by toList.

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
    // Use growable: true because List.sort modifies in place
    final mutableList = toList(growable: true);
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
/// Uses a stack to manage descent into internal nodes and keeps track of the
/// current position within leaf nodes.
class _RrbTreeIterator<E> implements Iterator<E> {
  // Stack for internal node traversal (stores nodes to visit)
  final List<rrb.RrbNode<E>> _nodeStack = [];
  // Stack to track the index of the next child to visit within each internal node
  final List<int> _indexStack = [];

  // Current leaf node being processed
  rrb.RrbLeafNode<E>? _currentLeaf;
  // Index within the current leaf's elements list
  int _leafIndex = 0;

  // The element to be returned by the current getter
  E? _currentElement;

  /// Creates an iterator starting at the root of the given [list]'s RRB-Tree.
  _RrbTreeIterator(ApexListImpl<E> list) {
    if (!list.isEmpty) {
      _pushNode(list._root); // Start traversal at the root
    }
  }

  /// Pushes an internal node onto the traversal stack.
  void _pushNode(rrb.RrbNode<E> node) {
    _nodeStack.add(node);
    _indexStack.add(0); // Start at the first child (index 0)
  }

  @override
  E get current {
    if (_currentElement == null) {
      // Adhere to Iterator contract: throw if current is accessed before moveNext
      // or after moveNext returns false.
      throw StateError('No current element. Call moveNext() first.');
    }
    return _currentElement!;
  }

  @override
  bool moveNext() {
    // 1. Continue iterating through the current leaf if possible
    if (_currentLeaf != null) {
      if (_leafIndex < _currentLeaf!.elements.length) {
        _currentElement = _currentLeaf!.elements[_leafIndex];
        _leafIndex++;
        return true;
      } else {
        _currentLeaf = null; // Current leaf exhausted
        _leafIndex = 0;
      }
    }

    // 2. If no active leaf iterator, traverse the node stack to find the next leaf
    while (_nodeStack.isNotEmpty) {
      final node = _nodeStack.last;
      final index = _indexStack.last;

      if (node is rrb.RrbLeafNode<E>) {
        // Found a leaf node on the stack (should generally be pushed by internal node logic)
        _nodeStack.removeLast(); // Pop this leaf from the node stack
        _indexStack.removeLast();

        if (node.elements.isNotEmpty) {
          _currentLeaf = node;
          _leafIndex = 0;
          // Immediately try to get the first element of the new leaf
          if (_leafIndex < _currentLeaf!.elements.length) {
            _currentElement = _currentLeaf!.elements[_leafIndex];
            _leafIndex++;
            return true;
          } else {
            // Leaf was technically not empty but became exhausted immediately?
            // This case seems unlikely if node.elements.isNotEmpty passed. Reset just in case.
            _currentLeaf = null;
            _leafIndex = 0;
          }
        }
        // If leaf was empty or exhausted immediately, continue stack traversal
        continue;
      } else if (node is rrb.RrbInternalNode<E>) {
        // Internal node: descend into the next child
        if (index < node.children.length) {
          // Increment index for the current node before pushing child
          _indexStack[_indexStack.length - 1]++;
          // Push the next child to process
          _pushNode(node.children[index]);
          continue; // Restart loop to process the newly pushed node
        } else {
          // Finished with this internal node's children, pop it
          _nodeStack.removeLast();
          _indexStack.removeLast();
          continue; // Continue with the parent node on the stack
        }
      } else {
        // Should only be EmptyNode initially, which isn't pushed.
        // If encountered later (e.g., due to error), just pop.
        _nodeStack.removeLast();
        _indexStack.removeLast();
      }
    }

    // Stack is empty and no current leaf is active, iteration complete
    _currentElement = null;
    return false;
  }
}
