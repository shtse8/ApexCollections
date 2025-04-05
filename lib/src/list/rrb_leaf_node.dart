/// Defines the [RrbLeafNode] class for the RRB-Tree implementation.
library;

import 'rrb_node_base.dart';
import 'rrb_internal_node.dart'; // Import internal node for splitting logic

/// Represents a leaf node in the RRB-Tree.
/// Contains the actual list elements.
class RrbLeafNode<E> extends RrbNode<E> {
  @override
  int get height => 0;

  @override
  int get count => elements.length;

  /// The list of elements stored directly in this leaf.
  /// This list is mutable only if the node is transient (has an owner).
  List<E> elements;

  /// The canonical empty leaf node instance (typed as `Never`).
  static final RrbLeafNode<Never> emptyInstance = RrbLeafNode<Never>.internal(
    // Use internal
    const [],
    null,
  );

  /// Creates a leaf RRB-Tree node, potentially copying a range from a source list.
  /// Used primarily by the bulk loader (`ApexListImpl.fromIterable`).
  ///
  /// - [sourceList]: The source list containing the elements.
  /// - [start]: The starting index (inclusive) in [sourceList].
  /// - [end]: The ending index (exclusive) in [sourceList].
  /// - [owner]: Optional [TransientOwner] if creating a mutable transient node.
  ///
  /// If an [owner] is provided, the internal [elements] list is created as a mutable
  /// copy of the specified range. Otherwise, it's created as an unmodifiable copy.
  factory RrbLeafNode.fromRange(
    List<E> sourceList,
    int start,
    int end, [
    TransientOwner? owner,
  ]) {
    final rangeLength = end - start;
    assert(rangeLength >= 0 && rangeLength <= kBranchingFactor);
    // Use getRange for potentially better performance than sublist + List.of
    final elementsList = List<E>.generate(
      rangeLength,
      (i) => sourceList[start + i],
      growable: owner != null, // Growable only if transient
    );
    // Use internal constructor to assign the prepared list
    return RrbLeafNode<E>.internal(elementsList, owner); // Use internal
  }

  /// Creates a leaf node directly from a given list (e.g., for splitting).
  /// Use `RrbLeafNode.fromRange` for bulk loading.
  RrbLeafNode(List<E> elements, [TransientOwner? owner])
    : elements =
          (owner != null || elements.isEmpty)
              ? elements // Use directly if transient or empty
              : List.unmodifiable(elements), // Make immutable otherwise
      assert(elements.length <= kBranchingFactor),
      super(owner);

  /// Internal constructor used for empty instance, ensureMutable, and fromRange.
  /// Takes an already prepared list (e.g., const [], mutable copy, or range copy).
  /// Made public for use by RrbInternalNode during rebalancing.
  RrbLeafNode.internal(List<E> preparedElements, TransientOwner? owner)
    : elements = preparedElements, // Assign directly
      super(owner);

  @override
  E get(int index) {
    assert(index >= 0 && index < count);
    return elements[index];
  }

  @override
  RrbNode<E> update(int index, E value) {
    assert(index >= 0 && index < count);
    if (identical(elements[index], value) || elements[index] == value) {
      return this;
    }
    final newElements = List<E>.of(elements);
    newElements[index] = value;
    // Use default constructor
    return RrbLeafNode<E>(newElements);
  }

  @override
  RrbNode<E> add(E value) {
    if (elements.length < kBranchingFactor) {
      final newElements = List<E>.of(elements)..add(value);
      // Use default constructor
      return RrbLeafNode<E>(newElements);
    } else {
      // Leaf is full, split into a new parent internal node
      // Use default constructor
      final newLeaf = RrbLeafNode<E>([value]);
      // New parent has height 1, count = old count + 1, children = [this, newLeaf]
      // Use default constructor
      return RrbInternalNode<E>(1, count + 1, [this, newLeaf], null);
    }
  }

  @override
  RrbNode<E>? removeAt(int index, [TransientOwner? owner]) {
    assert(index >= 0 && index < count);

    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner);
      assert(index < mutableNode.elements.length, "Index out of bounds");
      if (mutableNode.elements.length == 1) {
        // Removing the last element makes the node empty
        return null;
      }
      mutableNode.elements.removeAt(index);
      return mutableNode;
    } else {
      // --- Immutable Path ---
      if (elements.length == 1) {
        // Removing the last element makes the node empty
        return null;
      }
      final newElements = List<E>.of(elements)..removeAt(index);
      // Return a new immutable leaf node using default constructor
      return RrbLeafNode<E>(newElements, null);
    }
  }

  @override
  RrbNode<E> insertAt(int index, E value) {
    assert(index >= 0 && index <= count);

    if (elements.length < kBranchingFactor) {
      // Leaf has space, insert directly
      final newElements = List<E>.of(elements)..insert(index, value);
      // Use default constructor
      return RrbLeafNode<E>(newElements);
    } else {
      // Leaf is full, needs to split
      final tempElements = List<E>.of(elements)..insert(index, value);
      final splitPoint = (kBranchingFactor + 1) ~/ 2;
      final leftElements = tempElements.sublist(0, splitPoint);
      final rightElements = tempElements.sublist(splitPoint);
      // Use default constructor
      final newLeftLeaf = RrbLeafNode<E>(leftElements);
      // Use default constructor
      final newRightLeaf = RrbLeafNode<E>(rightElements);
      // Create new parent internal node using default constructor
      return RrbInternalNode<E>(1, count + 1, [
        newLeftLeaf,
        newRightLeaf,
      ], null); // New parent is strict
    }
  }

  /// Returns this node if mutable and owned, otherwise a mutable copy.
  /// Used for transient operations.
  RrbLeafNode<E> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy of the current elements list using the internal constructor
    return RrbLeafNode<E>.internal(
      // Use internal
      List<E>.of(elements, growable: true), // Ensure the list is growable
      owner,
    );
  }

  @override
  RrbNode<E> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // If owned, become immutable
      internalClearOwner(owner); // Use base class method
      this.elements = List.unmodifiable(
        elements,
      ); // Make internal list immutable
      return this;
    }
    // Already immutable or not owned by the freezer
    return this;
  }

  @override
  bool get isEmptyNode => elements.isEmpty; // Empty if elements list is empty
} // End of RrbLeafNode
