import 'dart:math'; // For Random
import 'package:collection/collection.dart'; // For ListEquality
import 'apex_list_api.dart';
import 'rrb_node.dart' as rrb; // Use prefix for node types and constants

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
  /// Uses an efficient O(N) bottom-up transient build algorithm.
  /// It first creates transient leaf nodes, then builds transient internal
  /// nodes level by level until a single root node is formed. Finally,
  /// the entire transient tree is frozen into an immutable state.
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

    // --- Use Transient Building ---
    final owner = rrb.TransientOwner();

    // --- Build Leaf Nodes ---
    List<rrb.RrbNode<E>> currentLevelNodes = [];
    for (int i = 0; i < totalLength; i += rrb.kBranchingFactor) {
      // Use constant from rrb
      final end =
          (i + rrb.kBranchingFactor < totalLength)
              ? i + rrb.kBranchingFactor
              : totalLength;
      // Pass owner to create transient leaf nodes
      currentLevelNodes.add(
        rrb.RrbLeafNode<E>(sourceList.sublist(i, end), owner),
      );
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
            owner, // Pass owner to create transient internal nodes
          ),
        );
      }
      currentLevelNodes = parentLevelNodes;
    }

    // The single remaining node is the root (potentially transient)
    final rootNode = currentLevelNodes[0];
    // Freeze the entire transient structure before returning
    final frozenRoot = rootNode.freeze(owner);
    return ApexListImpl._(frozenRoot, totalLength);
  }

  /// Computes a size table for a list of children nodes at a given height,
  /// returning null if the resulting parent node would be strict (i.e., does not
  /// require relaxation).
  ///
  /// A node needs relaxation (and thus a size table) if any of its children
  /// (except the last one) are not "full" for their height, or if children
  /// have inconsistent heights (which shouldn't happen in a balanced tree but
  /// is checked for robustness).
  ///
  /// (Helper for the `fromIterable` constructor)
  static List<int>? _computeSizeTableIfNeeded<E>(
    List<rrb.RrbNode<E>> children, // Use prefixed type
    int parentHeight,
  ) {
    if (children.isEmpty) return null;

    bool needsTable = false;
    final int childHeight = parentHeight - 1;
    // Allow check even if childHeight is -1 (for leaves becoming internal)
    if (childHeight < 0 && children.any((c) => c is! rrb.RrbLeafNode)) {
      return null; // Should not happen with leaves
    }
    if (childHeight < 0)
      return null; // All children must be leaves if height is 1

    final int expectedChildNodeSize =
        (childHeight == 0)
            ? rrb.kBranchingFactor
            : (1 << (childHeight * rrb.kLog2BranchingFactor));

    int cumulativeCount = 0;
    final calculatedSizeTable = List<int>.filled(children.length, 0);

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      // Check height consistency
      if (child.height != childHeight) {
        // If heights mismatch, force relaxation and stop checking fullness
        needsTable = true;
      }
      cumulativeCount += child.count;
      calculatedSizeTable[i] = cumulativeCount;
      // Only check fullness if heights are consistent so far
      // The last child is allowed to be non-full.
      if (!needsTable &&
          i < children.length - 1 &&
          child.count != expectedChildNodeSize) {
        needsTable = true;
      }
    }
    // Return table if needed due to fullness or height mismatch
    return needsTable ? calculatedSizeTable : null;
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

    // --- Use Transient Add ---
    final owner = rrb.TransientOwner();
    // Get a mutable version of the current root node
    rrb.RrbNode<E> mutableRoot;
    if (_root is rrb.RrbInternalNode<E>) {
      mutableRoot = (_root as rrb.RrbInternalNode<E>).ensureMutable(owner);
    } else if (_root is rrb.RrbLeafNode<E>) {
      mutableRoot = (_root as rrb.RrbLeafNode<E>).ensureMutable(owner);
    } else {
      // Should not happen if list is not empty
      mutableRoot = rrb.RrbLeafNode.emptyInstance as rrb.RrbNode<E>;
    }

    int additions = 0;
    for (final element in elementsToAdd) {
      // Pass owner to mutate the root node structure via transient add
      // Note: RrbNode.add itself handles splits and returns the new root
      mutableRoot = mutableRoot.add(
        element,
      ); // Owner is implicit on mutableRoot
      additions++;
    }

    // If no additions occurred (e.g., iterable was empty after conversion, though checked earlier)
    // or if the root reference didn't change (unlikely with additions), handle potential copy.
    if (additions == 0) {
      if (!identical(mutableRoot, _root)) {
        // ensureMutable created a copy, but nothing was added. Freeze and return it.
        final frozenRoot = mutableRoot.freeze(owner);
        return ApexListImpl._(frozenRoot, _length);
      }
      return this; // No changes needed
    }

    // Freeze the final potentially mutable root node
    final frozenRoot = mutableRoot.freeze(owner);
    final newLength = _length + additions; // Use actual additions count

    // Return new instance with the frozen root and updated count
    return ApexListImpl._(frozenRoot, newLength);
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

    // --- Reverted Immutable Approach ---
    // Iterate, collect elements to keep, and build a new list.
    // Benchmarks showed transient approach wasn't better here.
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

    // Use the efficient O(log N) tree slicing helper.
    final slicedNode = _sliceTree<E>(_root, start, actualEnd);

    if (slicedNode == null) {
      // _sliceTree returns null if the resulting slice is empty.
      return emptyInstance<E>();
    } else {
      // Create a new ApexListImpl with the sliced node and calculated length.
      return ApexListImpl<E>._(slicedNode, subLength);
    }
  }

  /// Static helper to perform efficient slicing on an RRB-Tree node.
  ///
  /// Recursively traverses the tree, selecting and potentially slicing child
  /// nodes that fall within the requested range [`start`, `end`). Returns a new
  /// root node for the resulting slice, or `null` if the slice is empty.
  /// Complexity: O(log N) where N is the number of elements in the original node.
  static rrb.RrbNode<E>? _sliceTree<E>(
    rrb.RrbNode<E> node,
    int start, // Inclusive start index relative to this node
    int end, // Exclusive end index relative to this node
  ) {
    // Clamp range to node bounds
    final nodeCount = node.count;
    final effectiveStart = start.clamp(0, nodeCount);
    final effectiveEnd = end.clamp(0, nodeCount);
    final sliceLength = effectiveEnd - effectiveStart;

    if (sliceLength <= 0) {
      return null; // Empty slice
    }
    if (effectiveStart == 0 && effectiveEnd == nodeCount) {
      return node; // Slice covers the whole node
    }

    if (node is rrb.RrbLeafNode<E>) {
      // Slice the elements list directly
      final slicedElements = node.elements.sublist(
        effectiveStart,
        effectiveEnd,
      );
      return slicedElements.isEmpty ? null : rrb.RrbLeafNode<E>(slicedElements);
    } else if (node is rrb.RrbInternalNode<E>) {
      final List<rrb.RrbNode<E>> resultChildren = [];
      int currentOffset = 0;

      for (int i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final childCount = child.count;
        final childEndOffset = currentOffset + childCount;

        // Check for overlap:
        // Child starts before slice ends AND Child ends after slice starts
        if (currentOffset < effectiveEnd && childEndOffset > effectiveStart) {
          // Calculate slice range relative to this child
          final childSliceStart = effectiveStart - currentOffset;
          final childSliceEnd = effectiveEnd - currentOffset;

          // Recursively slice the child
          final slicedChild = _sliceTree<E>(
            child,
            childSliceStart,
            childSliceEnd,
          );

          if (slicedChild != null) {
            resultChildren.add(slicedChild);
          }
        }
        // Move to the next child's offset
        currentOffset = childEndOffset;

        // Optimization: Stop if we've passed the end of the slice
        if (currentOffset >= effectiveEnd) {
          break;
        }
      }

      // Post-processing the results:
      if (resultChildren.isEmpty) {
        return null; // Slice resulted in no children
      }
      if (resultChildren.length == 1) {
        // If only one child remains, potentially collapse the parent.
        // Check if height needs adjustment (e.g., internal node containing only a leaf)
        final singleChild = resultChildren[0];
        // Return the child directly if it's not an internal node that should remain internal
        // Or if its height matches the expected child height for this level
        if (node.height == 1 || singleChild.height == node.height - 1) {
          return singleChild;
        }
        // If heights mismatch significantly (e.g. internal node holding a leaf after slicing),
        // we might still need a parent, but recalculate count/size table. Fall through to create new parent.
      }

      // Rebuild a new parent node with the collected/sliced children
      final newParentHeight =
          node.height; // Height remains the same unless collapsed above
      final newParentCount = sliceLength; // Calculated earlier
      final newParentSizeTable = _computeSizeTableIfNeeded<E>(
        resultChildren,
        newParentHeight,
      );

      return rrb.RrbInternalNode<E>(
        newParentHeight,
        newParentCount,
        resultChildren,
        newParentSizeTable,
      );
    } else {
      // Should not happen (EmptyNode case handled by sliceLength <= 0)
      return null;
    }
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
    if (isEmpty) return other; // Already ApexList<E>

    // Efficient O(log N) concatenation using tree manipulation.
    final newRoot = _concatenateTrees<E>(
      _root,
      _length,
      (other as ApexListImpl<E>)._root, // Cast to access internal root
      other.length,
    );
    final newLength = _length + other.length;
    return ApexListImpl<E>._(newRoot, newLength);
  }

  /// Static helper to concatenate two RRB-Trees represented by their roots.
  /// Handles height differences and delegates to node-level concatenation.
  /// Complexity: O(log N) where N is the size of the larger tree.
  static rrb.RrbNode<E> _concatenateTrees<E>(
    rrb.RrbNode<E> leftRoot,
    int
    leftLength, // Keep for potential future use, not strictly needed for concat logic
    rrb.RrbNode<E> rightRoot,
    int rightLength, // Keep for potential future use
  ) {
    final leftHeight = leftRoot.height;
    final rightHeight = rightRoot.height;
    final newLength = leftLength + rightLength;

    // Handle trivial cases where one list is empty (already done in operator+)
    // if (leftLength == 0) return rightRoot;
    // if (rightLength == 0) return leftRoot;

    if (leftHeight == rightHeight) {
      // --- Case 1: Equal Heights ---
      final concatenationResult = _concatenateNodes<E>(leftRoot, rightRoot);
      if (concatenationResult.length == 1) {
        // Merged into a single node
        return concatenationResult[0];
      } else {
        // Could not merge directly, create a new parent
        final newHeight = leftHeight + 1;
        // Need to compute size table for the new parent if needed
        final newSizeTable = _computeSizeTableIfNeeded<E>(
          concatenationResult,
          newHeight,
        );
        return rrb.RrbInternalNode<E>(
          newHeight,
          newLength,
          concatenationResult, // Resulting nodes become children
          newSizeTable,
        );
      }
    } else if (leftHeight > rightHeight) {
      // --- Case 2: Left Tree Taller ---
      final path = <rrb.RrbInternalNode<E>>[];
      var currentLeft = leftRoot; // Start with root
      // Descend right spine until height matches rightHeight + 1 or rightHeight
      while (currentLeft.height > rightHeight + 1 &&
          currentLeft is rrb.RrbInternalNode<E>) {
        path.add(currentLeft);
        currentLeft = currentLeft.children.last;
      }
      // currentLeft is now the node at height rightHeight+1 (or potentially rightHeight if root was only 1 level higher)

      if (currentLeft is! rrb.RrbInternalNode<E>) {
        // Should not happen if leftHeight > rightHeight
        throw StateError("Internal error during concatenation descent (left)");
      }

      // Concatenate the rightmost child of currentLeft with rightRoot
      final nodeToConcat = currentLeft.children.last;
      final concatenationResult = _concatenateNodes<E>(nodeToConcat, rightRoot);

      // Rebuild path upwards
      return _rebuildConcatenatedPath<E>(
        newLength,
        path, // Path from root down to parent of merge point's parent
        currentLeft, // Parent node whose last child was involved in merge
        concatenationResult, // Result of merging nodeToConcat and rightRoot
      );
    } else {
      // --- Case 3: Right Tree Taller ---
      final path = <rrb.RrbInternalNode<E>>[];
      var currentRight = rightRoot; // Start with root
      // Descend left spine until height matches leftHeight + 1 or leftHeight
      while (currentRight.height > leftHeight + 1 &&
          currentRight is rrb.RrbInternalNode<E>) {
        path.add(currentRight);
        currentRight = currentRight.children.first;
      }
      // currentRight is now the node at height leftHeight+1 (or potentially leftHeight)

      if (currentRight is! rrb.RrbInternalNode<E>) {
        // Should not happen if rightHeight > leftHeight
        throw StateError("Internal error during concatenation descent (right)");
      }

      // Concatenate leftRoot with the leftmost child of currentRight
      final nodeToConcat = currentRight.children.first;
      final concatenationResult = _concatenateNodes<E>(leftRoot, nodeToConcat);

      // Rebuild path upwards (using reversed logic)
      return _rebuildConcatenatedPathReversed<E>(
        newLength,
        path, // Path from root down to parent of merge point's parent
        currentRight, // Parent node whose first child was involved in merge
        concatenationResult, // Result of merging leftRoot and nodeToConcat
      );
    }
  }

  /// Concatenates two nodes OF THE SAME HEIGHT.
  /// Returns a list containing:
  /// - One node: If the nodes could be merged into a single (potentially new) node
  ///             that doesn't exceed branching factor.
  /// - Two nodes: If they couldn't be merged directly and should become siblings
  ///              in a new parent node.
  static List<rrb.RrbNode<E>> _concatenateNodes<E>(
    rrb.RrbNode<E> node1,
    rrb.RrbNode<E> node2,
  ) {
    assert(node1.height == node2.height);
    final height = node1.height;
    final combinedCount = node1.count + node2.count;

    if (node1 is rrb.RrbLeafNode<E> && node2 is rrb.RrbLeafNode<E>) {
      // --- Concatenate Leaves ---
      if (combinedCount <= rrb.kBranchingFactor) {
        // Merge into a single leaf
        final mergedElements = [...node1.elements, ...node2.elements];
        return [rrb.RrbLeafNode<E>(mergedElements)];
      } else {
        // Cannot merge, return both to become siblings
        return [node1, node2];
      }
    } else if (node1 is rrb.RrbInternalNode<E> &&
        node2 is rrb.RrbInternalNode<E>) {
      // --- Concatenate Internal Nodes ---
      final combinedChildrenCount =
          node1.children.length + node2.children.length;
      if (combinedChildrenCount <= rrb.kBranchingFactor) {
        // Merge children into a single internal node
        final mergedChildren = [...node1.children, ...node2.children];
        // Use parent height (height + 1) to check relaxation needs for the *new* node
        final mergedSizeTable = _computeSizeTableIfNeeded<E>(
          mergedChildren,
          height + 1,
        );
        return [
          rrb.RrbInternalNode<E>(
            height,
            combinedCount,
            mergedChildren,
            mergedSizeTable,
          ),
        ];
      } else {
        // Cannot merge children directly, return both nodes
        return [node1, node2];
      }
    } else {
      // Should not happen if heights match and nodes are valid
      throw StateError(
        "Cannot concatenate nodes of different types at the same height.",
      );
    }
  }

  /// Helper to rebuild the tree path upwards after concatenation (Left tree taller case).
  static rrb.RrbNode<E> _rebuildConcatenatedPath<E>(
    int totalCount,
    List<rrb.RrbInternalNode<E>>
    path, // Path from root to parent-of-merge-parent
    rrb.RrbInternalNode<E> mergeParent, // Parent whose last child was merged
    List<rrb.RrbNode<E>> concatenationResult, // Result from _concatenateNodes
  ) {
    List<rrb.RrbNode<E>> currentLevelNodes = concatenationResult;
    rrb.RrbNode<E>? singleNodeResult; // Use nullable type

    // Process the mergeParent level first
    var children = List<rrb.RrbNode<E>>.of(mergeParent.children)..removeLast();
    children.addAll(currentLevelNodes);

    // Iterate upwards, rebuilding parent nodes
    while (true) {
      final currentHeight = (children[0].height) + 1;
      if (children.length <= rrb.kBranchingFactor) {
        // Fits in one node
        final sizeTable = _computeSizeTableIfNeeded<E>(children, currentHeight);
        // Calculate count accurately for this node
        final nodeCount =
            sizeTable?.last ??
            children.fold<int>(0, (sum, node) => sum + (node.count ?? 0));
        singleNodeResult = rrb.RrbInternalNode<E>(
          currentHeight,
          nodeCount ?? 0,
          children,
          sizeTable,
        ); // Use ?? 0 for count
        currentLevelNodes = []; // Clear the list as we have a single result
      } else {
        // Needs splitting
        final splitPoint =
            (children.length + 1) ~/
            2; // Bias towards left? Or use kBranchingFactor/2?
        final leftChildren = children.sublist(0, splitPoint);
        final rightChildren = children.sublist(splitPoint);

        final leftSizeTable = _computeSizeTableIfNeeded<E>(
          leftChildren,
          currentHeight,
        );
        final rightSizeTable = _computeSizeTableIfNeeded<E>(
          rightChildren,
          currentHeight,
        );
        final leftCount =
            leftSizeTable?.last ??
            leftChildren.fold<int>(0, (sum, node) => sum + (node.count ?? 0));
        // Right count can be derived if totalCount is accurate, but recalculating is safer
        final rightCount =
            rightSizeTable?.last ??
            rightChildren.fold<int>(0, (sum, node) => sum + (node.count ?? 0));

        final leftNode = rrb.RrbInternalNode<E>(
          currentHeight,
          leftCount ?? 0,
          leftChildren,
          leftSizeTable,
        ); // Use ?? 0 for count
        final rightNode = rrb.RrbInternalNode<E>(
          currentHeight,
          rightCount ?? 0,
          rightChildren,
          rightSizeTable,
        ); // Use ?? 0 for count
        currentLevelNodes = [
          leftNode,
          rightNode,
        ]; // These become children for the next level up
        singleNodeResult = null; // Clear single result as we split
      }

      // If path is empty, we've rebuilt the root
      if (path.isEmpty) {
        if (singleNodeResult != null) {
          // Final root is the single node created. Recreate it with the correct total count if internal.
          if (singleNodeResult is rrb.RrbInternalNode<E>) {
            return rrb.RrbInternalNode<E>(
              singleNodeResult.height,
              totalCount, // Use the final total count
              singleNodeResult.children,
              singleNodeResult.sizeTable,
            );
          } else {
            // Should be a leaf node if not internal (leaf count is inherent)
            return singleNodeResult;
          }
        } else {
          // Final root needs to be a new parent for the split nodes
          final rootHeight = currentHeight + 1;
          final rootSizeTable = _computeSizeTableIfNeeded<E>(
            currentLevelNodes,
            rootHeight,
          );
          return rrb.RrbInternalNode<E>(
            rootHeight,
            totalCount,
            currentLevelNodes,
            rootSizeTable,
          );
        }
      }

      // Move up the path
      final parent = path.removeLast();
      // Replace parent's last child with the result(s) from the level below
      children = List<rrb.RrbNode<E>>.of(parent.children)..removeLast();
      if (singleNodeResult != null) {
        children.add(singleNodeResult);
      } else {
        children.addAll(currentLevelNodes);
      }
      // Loop continues to rebuild this new list of children at the parent level
    }
  }

  /// Helper to rebuild the tree path upwards after concatenation (Right tree taller case).
  static rrb.RrbNode<E> _rebuildConcatenatedPathReversed<E>(
    int totalCount,
    List<rrb.RrbInternalNode<E>>
    path, // Path from root down to parent-of-merge-parent
    rrb.RrbInternalNode<E> mergeParent, // Parent whose first child was merged
    List<rrb.RrbNode<E>> concatenationResult, // Result from _concatenateNodes
  ) {
    List<rrb.RrbNode<E>> currentLevelNodes = concatenationResult;
    rrb.RrbNode<E>? singleNodeResult;

    // Process the mergeParent level first
    var children = List<rrb.RrbNode<E>>.of(mergeParent.children)
      ..removeAt(0); // Remove first child
    children.insertAll(0, currentLevelNodes); // Insert result at the beginning

    while (true) {
      final currentHeight = (children[0].height) + 1;
      if (children.length <= rrb.kBranchingFactor) {
        final sizeTable = _computeSizeTableIfNeeded<E>(children, currentHeight);
        final nodeCount =
            sizeTable?.last ??
            children.fold<int>(0, (sum, node) => sum + (node.count ?? 0));
        singleNodeResult = rrb.RrbInternalNode<E>(
          currentHeight,
          nodeCount ?? 0,
          children,
          sizeTable,
        ); // Use ?? 0 for count
        currentLevelNodes = [];
      } else {
        final splitPoint = (children.length + 1) ~/ 2;
        final leftChildren = children.sublist(0, splitPoint);
        final rightChildren = children.sublist(splitPoint);

        final leftSizeTable = _computeSizeTableIfNeeded<E>(
          leftChildren,
          currentHeight,
        );
        final rightSizeTable = _computeSizeTableIfNeeded<E>(
          rightChildren,
          currentHeight,
        );
        final leftCount =
            leftSizeTable?.last ??
            leftChildren.fold<int>(0, (sum, node) => sum + (node.count ?? 0));
        final rightCount =
            rightSizeTable?.last ??
            rightChildren.fold<int>(0, (sum, node) => sum + (node.count ?? 0));

        final leftNode = rrb.RrbInternalNode<E>(
          currentHeight,
          leftCount ?? 0,
          leftChildren,
          leftSizeTable,
        ); // Use ?? 0 for count
        final rightNode = rrb.RrbInternalNode<E>(
          currentHeight,
          rightCount ?? 0,
          rightChildren,
          rightSizeTable,
        ); // Use ?? 0 for count
        currentLevelNodes = [leftNode, rightNode];
        singleNodeResult = null;
      }

      if (path.isEmpty) {
        if (singleNodeResult != null) {
          // Final root is the single node created. Recreate it with the correct total count if internal.
          if (singleNodeResult is rrb.RrbInternalNode<E>) {
            return rrb.RrbInternalNode<E>(
              singleNodeResult.height,
              totalCount, // Use the final total count
              singleNodeResult.children,
              singleNodeResult.sizeTable,
            );
          } else {
            // Should be a leaf node if not internal (leaf count is inherent)
            return singleNodeResult;
          }
        } else {
          final rootHeight = currentHeight + 1;
          final rootSizeTable = _computeSizeTableIfNeeded<E>(
            currentLevelNodes,
            rootHeight,
          );
          return rrb.RrbInternalNode<E>(
            rootHeight,
            totalCount,
            currentLevelNodes,
            rootSizeTable,
          );
        }
      }

      final parent = path.removeLast();
      children = List<rrb.RrbNode<E>>.of(parent.children)
        ..removeAt(0); // Remove first child
      if (singleNodeResult != null) {
        children.insert(0, singleNodeResult); // Insert single node result
      } else {
        children.insertAll(0, currentLevelNodes); // Insert split node results
      }
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
  @override
  @override
  List<E> toList({bool growable = true}) {
    if (isEmpty) {
      return growable ? <E>[] : List<E>.empty(growable: false);
    }
    // Pre-allocate list with known length for efficiency
    // Need a default value for List.filled, get the first element.
    // This assumes the list is not empty, which is checked above.
    final list = List<E>.filled(_length, _root.get(0), growable: growable);
    _fillListFromNode<E>(_root, list, 0); // Call recursive helper
    return list;
  }

  /// Recursive helper to fill a list buffer from tree nodes.
  /// Returns the number of elements added from this node.
  static int _fillListFromNode<E>(
    rrb.RrbNode<E> node,
    List<E> buffer,
    int bufferOffset,
  ) {
    if (node is rrb.RrbLeafNode<E>) {
      final elements = node.elements;
      final nodeLength = elements.length;
      // Efficiently copy elements using setRange
      buffer.setRange(bufferOffset, bufferOffset + nodeLength, elements);
      return nodeLength;
    } else if (node is rrb.RrbInternalNode<E>) {
      int elementsAdded = 0;
      for (final child in node.children) {
        elementsAdded += _fillListFromNode(
          child,
          buffer,
          bufferOffset + elementsAdded,
        );
      }
      return elementsAdded;
    } else {
      // Empty node case (shouldn't be reached if initial isEmpty check passes)
      return 0;
    }
  }

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
