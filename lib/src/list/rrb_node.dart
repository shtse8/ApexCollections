/// Defines the core structures for RRB-Tree nodes used by ApexList.
library;

const int _kBranchingFactor = 32; // Or M, typically 32
const int _kLog2BranchingFactor = 5; // log2(32)

/// Base class for RRB-Tree nodes.
abstract class RrbNode<E> {
  /// Const constructor for subclasses.
  const RrbNode();

  /// The height of the subtree rooted at this node.
  /// Leaf nodes have height 0.
  int get height;

  /// The total number of elements in the subtree rooted at this node.
  int get count;

  /// Whether this node represents a leaf (contains elements directly).
  bool get isLeaf => height == 0;

  /// Whether this node represents an internal branch (contains child nodes).
  bool get isBranch => height > 0;

  /// Retrieves the element at the effective [index] within this subtree.
  /// The [index] must be valid within the bounds of this node's [count].
  E get(int index);

  /// Returns a new node structure representing the tree after updating the
  /// element at the effective [index] within this subtree with the new [value].
  /// The [index] must be valid within the bounds of this node's [count].
  RrbNode<E> update(int index, E value);

  /// Returns a new node structure representing the tree after appending [value]
  /// to the end of the subtree represented by this node.
  /// This might involve node splits and increasing tree height.
  RrbNode<E> add(E value);

  /// Returns a new node structure representing the tree after removing the
  /// element at the effective [index] within this subtree.
  /// The [index] must be valid within the bounds of this node's [count].
  /// This might involve node merges and decreasing tree height.
  /// Returns `null` if the node becomes empty after removal.
  RrbNode<E>? removeAt(int index);

  /// Returns true if this node represents the canonical empty node.
  bool get isEmptyNode => false;
}

/// Represents an internal node (branch) in the RRB-Tree.
/// Contains references to child nodes and potentially a size table if relaxed.
class RrbInternalNode<E> extends RrbNode<E> {
  @override
  final int height;

  @override
  final int count;

  /// Array containing child nodes (either RrbInternalNode or RrbLeafNode).
  /// The length is the number of slots currently used.
  final List<RrbNode<E>> children;

  /// Cumulative size table. Only present if the node is 'relaxed'
  /// (i.e., not all children subtrees have the maximum size for their height).
  /// `sizeTable[i]` stores the total count of elements in `children[0]` through `children[i]`.
  final List<int>? sizeTable;

  RrbInternalNode(this.height, this.count, this.children, [this.sizeTable])
    : assert(height > 0),
      assert(children.isNotEmpty),
      assert(sizeTable == null || sizeTable.length == children.length);

  /// Indicates if this node requires a size table for relaxed radix search.
  bool get isRelaxed => sizeTable != null;

  @override
  E get(int index) {
    assert(index >= 0 && index < count);

    final shift = height * _kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (_kBranchingFactor - 1);

    if (isRelaxed) {
      // Relaxed Radix Search
      int slot = indexInNode;
      final sizes = sizeTable!;
      // Skip slots until we find the one containing the index
      // Need to check against the *previous* slot's cumulative size
      while (slot > 0 && sizes[slot - 1] > index) {
        slot--; // Should not happen often if radix is close
      }
      while (sizes[slot] <= index) {
        slot++; // Linear scan for the correct slot
      }

      final child = children[slot];
      final indexInChild = (slot == 0) ? index : index - sizes[slot - 1];
      return child.get(indexInChild);
    } else {
      // Strict Radix Search (fixed size children)
      final child = children[indexInNode];
      final indexInChild = index & ((1 << shift) - 1); // Mask out upper bits
      return child.get(indexInChild);
    }
  }

  @override
  RrbNode<E> update(int index, E value) {
    assert(index >= 0 && index < count);

    final shift = height * _kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (_kBranchingFactor - 1);
    int slot = indexInNode; // Default for strict case
    int indexInChild = index & ((1 << shift) - 1); // Default for strict case

    if (isRelaxed) {
      // Find correct slot and index for relaxed node
      final sizes = sizeTable!;
      while (slot > 0 && sizes[slot - 1] > index) {
        slot--;
      }
      while (sizes[slot] <= index) {
        slot++;
      }
      indexInChild = (slot == 0) ? index : index - sizes[slot - 1];
    }

    final oldChild = children[slot];
    final newChild = oldChild.update(indexInChild, value);

    // If child didn't change (e.g., value was identical), return original node
    if (identical(oldChild, newChild)) {
      return this;
    }

    // Create a new internal node with the updated child
    final newChildren = List<RrbNode<E>>.of(children);
    newChildren[slot] = newChild;

    // Size table doesn't change on update, so reuse if it exists
    return RrbInternalNode<E>(height, count, newChildren, sizeTable);
  }

  @override
  RrbNode<E> add(E value) {
    // Recursively add to the last child.
    final lastChildIndex = children.length - 1;
    final lastChild = children[lastChildIndex];

    // Calculate count of elements *before* the last child
    int countBeforeLast;
    if (isRelaxed) {
      countBeforeLast =
          (lastChildIndex == 0) ? 0 : sizeTable![lastChildIndex - 1];
    } else {
      // Strict node: size is predictable
      countBeforeLast =
          lastChildIndex * (1 << (height * _kLog2BranchingFactor));
    }

    final newLastChild = lastChild.add(value);

    // If last child didn't change structure (e.g., internal update), just update pointer
    if (identical(lastChild, newLastChild)) {
      return this;
    }

    final newChildren = List<RrbNode<E>>.of(children);
    List<int>? newSizeTable =
        sizeTable != null ? List<int>.of(sizeTable!) : null;

    if (newLastChild.height == height) {
      // Child split, returned a new internal node of same height containing original + new node
      // This means the current node needs to accommodate an extra child node.
      assert(newLastChild is RrbInternalNode<E>);
      final splitChild = newLastChild as RrbInternalNode<E>;
      assert(splitChild.children.length == 2); // Expecting split into two

      newChildren[lastChildIndex] =
          splitChild.children[0]; // Replace original last child
      final nodeToAdd = splitChild.children[1]; // Node to potentially add

      if (children.length < _kBranchingFactor) {
        // Current node has space
        newChildren.add(nodeToAdd);
        if (newSizeTable != null) {
          // Update size table: last entry is previous total + new node's count
          newSizeTable[lastChildIndex] =
              countBeforeLast + newChildren[lastChildIndex].count;
          newSizeTable.add(count + 1); // New total count
        }
        return RrbInternalNode<E>(height, count + 1, newChildren, newSizeTable);
      } else {
        // Current node is full, need to create a new parent
        final newNodeList = [
          nodeToAdd,
        ]; // Node containing the single overflow child
        final newParentInternal = RrbInternalNode<E>(
          height,
          nodeToAdd.count,
          newNodeList,
          null,
        ); // Strict node initially
        // New root node, height increases
        return RrbInternalNode<E>(height + 1, count + 1, [
          this,
          newParentInternal,
        ], null); // Strict node initially
      }
    } else {
      // Child did not split (height is child height = height - 1)
      newChildren[lastChildIndex] = newLastChild;
      if (newSizeTable != null) {
        newSizeTable[lastChildIndex] =
            count + 1; // Update cumulative count for the last slot
      }
      return RrbInternalNode<E>(height, count + 1, newChildren, newSizeTable);
    }
  }

  @override
  RrbNode<E>? removeAt(int index) {
    assert(index >= 0 && index < count);

    final shift = height * _kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (_kBranchingFactor - 1);
    int slot = indexInNode; // Default for strict case
    int indexInChild = index & ((1 << shift) - 1); // Default for strict case

    if (isRelaxed) {
      // Find correct slot and index for relaxed node
      final sizes = sizeTable!;
      while (slot > 0 && sizes[slot - 1] > index) {
        slot--;
      }
      while (sizes[slot] <= index) {
        slot++;
      }
      indexInChild = (slot == 0) ? index : index - sizes[slot - 1];
    }

    final oldChild = children[slot];
    final newChild = oldChild.removeAt(indexInChild);

    if (identical(oldChild, newChild)) {
      return this; // No change below
    }

    final newChildren = List<RrbNode<E>>.of(children);
    List<int>? newSizeTable =
        sizeTable != null ? List<int>.of(sizeTable!) : null;
    final newCount = count - 1;

    if (newChild == null) {
      // Child became empty, remove it from this node
      newChildren.removeAt(slot);
      if (newChildren.isEmpty) {
        return null; // This node also becomes empty
      }
      if (newSizeTable != null) {
        // Need to recalculate size table after removal
        newSizeTable.removeAt(slot);
        for (int i = slot; i < newSizeTable.length; i++) {
          newSizeTable[i]--; // Decrement subsequent cumulative counts
        }
      }
    } else {
      // Child was modified but not removed
      newChildren[slot] = newChild;
      if (newSizeTable != null) {
        // Update size table from the modified slot onwards
        int currentCount = (slot == 0) ? 0 : newSizeTable[slot - 1];
        for (int i = slot; i < newSizeTable.length; i++) {
          currentCount += newChildren[i].count;
          newSizeTable[i] = currentCount;
        }
      }
    }

    // TODO: Implement node merging / rebalancing if a node becomes too small
    // This is the complex part involving invariants. For now, just return the modified node.

    // If this node now only has one child, collapse it (return the child directly)
    if (newChildren.length == 1 && height > 0) {
      // Only collapse if not the root node (which might be height 0 if list becomes small)
      // Or handle root collapse at the ApexListImpl level.
      // For simplicity here, assume we return the single child.
      return newChildren[0];
    }

    return RrbInternalNode<E>(height, newCount, newChildren, newSizeTable);
  }
}

/// Represents a leaf node in the RRB-Tree.
/// Contains the actual list elements.
class RrbLeafNode<E> extends RrbNode<E> {
  @override
  int get height => 0;

  @override
  int get count => elements.length;

  /// Array containing the elements stored in this leaf.
  /// Length should be between 1 and _kBranchingFactor.
  final List<E> elements;

  RrbLeafNode(this.elements)
    : assert(elements.isNotEmpty),
      assert(elements.length <= _kBranchingFactor);

  @override
  E get(int index) {
    assert(index >= 0 && index < count);
    return elements[index];
  }

  @override
  RrbNode<E> update(int index, E value) {
    assert(index >= 0 && index < count);

    // If the new value is identical to the old one, return the same node
    if (identical(elements[index], value) || elements[index] == value) {
      return this;
    }

    // Create a new leaf node with the updated element
    final newElements = List<E>.of(elements);
    newElements[index] = value;
    return RrbLeafNode<E>(newElements);
  }

  @override
  RrbNode<E> add(E value) {
    if (elements.length < _kBranchingFactor) {
      // Leaf has space, create new leaf with appended element
      final newElements = List<E>.of(elements)..add(value);
      return RrbLeafNode<E>(newElements);
    } else {
      // Leaf is full, create a new parent node (height 1)
      final newLeaf = RrbLeafNode<E>([value]);
      // New parent contains the original full leaf and the new single-element leaf
      // Parent is initially strict as children are max size or single
      return RrbInternalNode<E>(1, count + 1, [this, newLeaf], null);
    }
  }

  @override
  RrbNode<E>? removeAt(int index) {
    assert(index >= 0 && index < count);

    if (elements.length == 1) {
      // Removing the only element makes the leaf empty
      return null;
    }

    // Create a new leaf node with the element removed
    final newElements = List<E>.of(elements)..removeAt(index);
    return RrbLeafNode<E>(newElements);
  }
}

/// Represents the canonical empty RRB-Tree node.
class RrbEmptyNode<E> extends RrbNode<E> {
  static final RrbEmptyNode _instance = RrbEmptyNode._();

  /// Singleton instance of the empty node.
  static RrbEmptyNode<E> instance<E>() => _instance as RrbEmptyNode<E>;

  const RrbEmptyNode._();

  @override
  int get height => 0; // Or -1? Let's use 0 for consistency with empty leaf concept.

  @override
  int get count => 0;

  @override
  bool get isEmptyNode => true;

  @override
  E get(int index) =>
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot index into an empty node',
        0,
      );

  @override
  RrbNode<E> update(int index, E value) =>
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot update an empty node',
        0,
      );

  @override
  RrbNode<E> add(E value) {
    // Adding to empty creates a new leaf node with the single element.
    return RrbLeafNode<E>([value]);
  }

  @override
  RrbNode<E>? removeAt(int index) =>
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot remove from an empty node',
        0,
      );
}

// TODO: Implement factory constructors or static methods for creating nodes.
// TODO: Implement methods for node operations (get, update, insert, concat, etc.).
