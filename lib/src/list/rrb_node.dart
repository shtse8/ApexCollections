/// Defines the core structures for Relaxed Radix Balanced Tree (RRB-Tree) nodes
/// used internally by [ApexList].
///
/// This library contains the abstract [RrbNode] base class and its concrete
/// implementations: [RrbInternalNode] for branches and [RrbLeafNode] for leaves.
/// It also includes constants like [kBranchingFactor] and helper classes like
/// [TransientOwner] for managing transient mutations.
library;

/// The branching factor (M) for the RRB-Tree. Determines the maximum number
/// of children an internal node can have or elements a leaf node can hold.
/// Typically a power of 2, often 32 for good performance characteristics.
const int kBranchingFactor = 32; // Or M, typically 32

/// The base-2 logarithm of the [kBranchingFactor]. Used for efficient index
/// calculations within the tree structure (log2(32) = 5).
const int kLog2BranchingFactor = 5; // log2(32)

// --- Transient Ownership ---

/// A marker object used to track ownership during transient (mutable) operations
/// on RRB-Tree nodes.
///
/// When performing bulk operations like `addAll` or `fromIterable`, nodes can be
/// temporarily mutated in place if they share the same [TransientOwner]. This
/// avoids excessive copying and improves performance. Once the operation is
/// complete, the tree is "frozen" back into an immutable state using [RrbNode.freeze].
class TransientOwner {
  /// Creates a new unique owner instance.
  const TransientOwner();
}

/// Abstract base class for nodes in the Relaxed Radix Balanced Tree (RRB-Tree).
///
/// Nodes can be either internal ([RrbInternalNode]) containing child nodes,
/// or leaf ([RrbLeafNode]) nodes containing the actual list elements.
/// Nodes are immutable by default but support transient mutation via the
/// [TransientOwner] mechanism for performance optimization during bulk updates.
abstract class RrbNode<E> {
  /// Optional owner for transient nodes. If non-null, this node might be mutable
  /// by the holder of this specific [TransientOwner] instance.
  TransientOwner? _owner; // Made mutable for freezing

  /// Constructor for subclasses. Assigns an optional [owner] for transient state.
  RrbNode([this._owner]); // Changed to non-const

  /// The height of the subtree rooted at this node.
  /// Leaf nodes ([RrbLeafNode]) have height 0. Internal nodes have height > 0.
  int get height;

  /// The total number of elements stored in the subtree rooted at this node.
  int get count;

  /// Returns `true` if this node is a leaf node ([RrbLeafNode]).
  bool get isLeaf => height == 0;

  /// Returns `true` if this node is an internal node ([RrbInternalNode]).
  bool get isBranch => height > 0;

  /// Retrieves the element at the effective [index] within this subtree.
  ///
  /// The [index] is relative to the start of the elements covered by this node.
  /// It must be non-negative and less than this node's [count].
  /// Complexity: O(log N) due to tree traversal.
  E get(int index);

  /// Returns a new node structure representing the tree after updating the
  /// element at the effective [index] within this subtree with the new [value].
  ///
  /// The [index] must be non-negative and less than this node's [count].
  /// Returns `this` if the value is identical to the existing value.
  /// Complexity: O(log N).
  RrbNode<E> update(int index, E value);

  /// Returns a new node structure representing the tree after appending [value]
  /// to the end of the subtree represented by this node.
  ///
  /// This might involve node splits and increasing tree height if nodes are full.
  /// Complexity: Amortized O(log N), potentially O(1) with tail optimizations.
  RrbNode<E> add(E value);

  /// Returns a new node structure representing the tree after removing the
  /// element at the effective [index] within this subtree.
  ///
  /// The [index] must be non-negative and less than this node's [count].
  /// This might involve node merges, rebalancing, and decreasing tree height.
  /// Returns `null` if the node becomes empty after removal.
  /// Accepts an optional [owner] for transient operations.
  /// Complexity: O(log N).
  RrbNode<E>? removeAt(int index, [TransientOwner? owner]); // Added owner

  /// Returns `true` if this node represents an empty tree structure.
  ///
  /// Only the canonical empty leaf node should return true.
  bool get isEmptyNode => false;

  /// Returns `true` if this node is currently mutable and belongs to the
  /// specified [owner].
  bool isTransient(TransientOwner? owner) => owner != null && _owner == owner;

  /// Returns an immutable version of this node.
  ///
  /// If the node is transient and owned by the provided [owner], it recursively
  /// freezes its children (if any), clears its owner, makes its internal lists
  /// unmodifiable, and returns itself. Otherwise, returns `this`.
  RrbNode<E> freeze(TransientOwner? owner);

  /// Returns a new node structure representing the tree after inserting [value]
  /// at the effective [index] within this subtree.
  ///
  /// The [index] must be non-negative and less than or equal to this node's [count].
  /// This might involve node splits and increasing tree height.
  /// Complexity: O(log N).
  RrbNode<E> insertAt(int index, E value);
}

/// Represents an internal node (branch) in the RRB-Tree.
///
/// Internal nodes contain references to child nodes ([children]), which can be
/// either other internal nodes or leaf nodes ([RrbLeafNode]).
/// They maintain the tree's structure and height.
///
/// A key feature of RRB-Trees is relaxation. If a node's children are not all
/// "full" (i.e., containing the maximum possible elements for their height),
/// the node becomes "relaxed" and stores a [sizeTable] to enable efficient
/// O(log N) indexing despite the irregular child sizes. Strict nodes (where
/// all children except possibly the last are full) do not need a size table.
class RrbInternalNode<E> extends RrbNode<E> {
  @override
  final int height;

  @override
  int count; // Made non-final for transient mutation

  /// The list of child nodes. Can contain [RrbInternalNode] or [RrbLeafNode].
  /// This list is mutable only if the node is transient (has an owner).
  List<RrbNode<E>> children;

  /// Optional table storing cumulative element counts for each child.
  /// Present only if the node is "relaxed" (i.e., its children are not all full).
  /// This list is mutable only if the node is transient.
  List<int>? sizeTable;

  /// Creates an internal RRB-Tree node.
  ///
  /// - [height]: The height of this node (must be > 0).
  /// - [count]: The total number of elements in the subtree rooted here.
  /// - [children]: The list of child nodes.
  /// - [sizeTable]: Optional cumulative size table if the node is relaxed.
  /// - [owner]: Optional [TransientOwner] if creating a mutable transient node.
  ///
  /// If an [owner] is provided, the [children] and [sizeTable] lists are kept
  /// mutable. Otherwise, they are converted to unmodifiable lists.
  RrbInternalNode(
    this.height,
    this.count,
    List<RrbNode<E>> children, [
    List<int>? sizeTable,
    TransientOwner? owner,
  ]) : children = (owner != null) ? children : List.unmodifiable(children),
       sizeTable =
           (owner != null || sizeTable == null)
               ? sizeTable
               : List.unmodifiable(sizeTable),
       assert(height > 0),
       assert(children.isNotEmpty),
       assert(sizeTable == null || sizeTable.length == children.length),
       super(owner);

  /// Returns `true` if this node is relaxed (uses a size table).
  bool get isRelaxed => sizeTable != null;

  @override
  E get(int index) {
    assert(index >= 0 && index < count);

    // Determine the target child slot and index within the child.
    int slot = 0;
    int countBeforeSlot = 0;
    int indexInChild;

    if (isRelaxed) {
      // Use size table if available
      final sizes = sizeTable!;
      while (slot < sizes.length && sizes[slot] <= index) {
        slot++;
      }
      countBeforeSlot = (slot == 0) ? 0 : sizes[slot - 1];
    } else {
      // Iterate through children summing counts for strict nodes
      while (slot < children.length - 1 &&
          countBeforeSlot + children[slot].count <= index) {
        countBeforeSlot += children[slot].count;
        slot++;
      }
    }
    indexInChild = index - countBeforeSlot;

    assert(
      slot >= 0 && slot < children.length,
      'Get: Calculated slot $slot is out of bounds. index: $index, height: $height, isRelaxed: $isRelaxed',
    );
    final child = children[slot];
    assert(
      indexInChild >= 0 && indexInChild < child.count,
      'Get: Invalid indexInChild ($indexInChild). index: $index, slot: $slot, childCount: ${child.count}',
    );
    return child.get(indexInChild);
  }

  @override
  RrbNode<E> update(int index, E value) {
    assert(index >= 0 && index < count);

    // Determine the target child slot and index within the child.
    int slot = 0;
    int countBeforeSlot = 0;
    int indexInChild;

    if (isRelaxed) {
      // Use size table if available
      final sizes = sizeTable!;
      while (slot < sizes.length && sizes[slot] <= index) {
        slot++;
      }
      countBeforeSlot = (slot == 0) ? 0 : sizes[slot - 1];
    } else {
      // Iterate through children summing counts for strict nodes
      while (slot < children.length - 1 &&
          countBeforeSlot + children[slot].count <= index) {
        countBeforeSlot += children[slot].count;
        slot++;
      }
    }
    indexInChild = index - countBeforeSlot;

    assert(
      slot >= 0 && slot < children.length,
      'Update: Calculated slot $slot is out of bounds. index: $index, height: $height, isRelaxed: $isRelaxed',
    );
    final oldChild = children[slot];
    assert(
      indexInChild >= 0 && indexInChild < oldChild.count,
      'Update: Invalid indexInChild ($indexInChild). index: $index, slot: $slot, childCount: ${oldChild.count}',
    );

    final newChild = oldChild.update(indexInChild, value);

    if (identical(oldChild, newChild)) {
      return this;
    }

    final newChildren = List<RrbNode<E>>.of(children);
    newChildren[slot] = newChild;
    // Note: Size table doesn't change on update, only counts within children might
    // Recompute size table status if it wasn't relaxed before, but might need to be now.
    final finalSizeTable = _computeSizeTableIfNeeded(newChildren) ?? sizeTable;
    return RrbInternalNode<E>(height, count, newChildren, finalSizeTable);
  }

  @override
  RrbNode<E> add(E value) {
    final lastChildIndex = children.length - 1;
    final lastChild = children[lastChildIndex];

    int countBeforeLast;
    if (isRelaxed) {
      countBeforeLast =
          (lastChildIndex == 0) ? 0 : sizeTable![lastChildIndex - 1];
    } else {
      // For strict nodes, count before last is simply index * expected size
      // Note: height-1 because we calculate based on child's expected size
      countBeforeLast =
          lastChildIndex * (1 << ((height - 1) * kLog2BranchingFactor));
    }

    final newLastChild = lastChild.add(value);

    if (identical(lastChild, newLastChild)) {
      return this;
    }

    final newChildren = List<RrbNode<E>>.of(children);
    List<int>? newSizeTable =
        sizeTable != null ? List<int>.of(sizeTable!) : null;
    final newCount = count + 1; // Increment count for the added element

    if (newLastChild.height == height) {
      // Child split during add
      assert(newLastChild is RrbInternalNode<E>);
      final splitChild = newLastChild as RrbInternalNode<E>;
      assert(splitChild.children.length == 2);

      newChildren[lastChildIndex] = splitChild.children[0];
      final nodeToAdd = splitChild.children[1];

      if (children.length < kBranchingFactor) {
        // Add new node to current level
        newChildren.add(nodeToAdd);
        if (newSizeTable != null) {
          // Update size table for modified last child and add new entry
          newSizeTable[lastChildIndex] =
              countBeforeLast + newChildren[lastChildIndex].count;
          newSizeTable.add(newCount); // Total count is the last entry
        }
        // Check if the new structure requires relaxation
        final finalSizeTable =
            _computeSizeTableIfNeeded(newChildren) ?? newSizeTable;
        return RrbInternalNode<E>(
          height,
          newCount,
          newChildren,
          finalSizeTable,
        );
      } else {
        // Node needs to split
        final newNodeList = [nodeToAdd];
        final newParentInternal = RrbInternalNode<E>(
          height,
          nodeToAdd.count,
          newNodeList,
          null,
        ); // New node is strict
        // Create new parent
        return RrbInternalNode<E>(height + 1, newCount, [
          this,
          newParentInternal,
        ], null); // New parent is strict
      }
    } else {
      // Child did not split (or leaf became internal node - height increased by 1)
      newChildren[lastChildIndex] = newLastChild;
      if (newSizeTable != null) {
        // Update the last entry in the size table
        newSizeTable[lastChildIndex] =
            newCount; // Total count is the last entry
      }
      // Check if the new structure requires relaxation
      final finalSizeTable =
          _computeSizeTableIfNeeded(newChildren) ?? newSizeTable;
      return RrbInternalNode<E>(height, newCount, newChildren, finalSizeTable);
    }
  }

  @override
  RrbNode<E>? removeAt(int index, [TransientOwner? owner]) {
    assert(index >= 0 && index < count);

    // Determine the target child slot and index within the child.
    int slot = 0;
    int countBeforeSlot = 0;
    int indexInChild;

    if (isRelaxed) {
      // Use size table if available
      final sizes = sizeTable!;
      while (slot < sizes.length && sizes[slot] <= index) {
        slot++;
      }
      countBeforeSlot = (slot == 0) ? 0 : sizes[slot - 1];
    } else {
      // Iterate through children summing counts for strict nodes
      while (slot < children.length - 1 &&
          countBeforeSlot + children[slot].count <= index) {
        countBeforeSlot += children[slot].count;
        slot++;
      }
    }
    indexInChild = index - countBeforeSlot;

    assert(
      slot >= 0 && slot < children.length,
      'RemoveAt: Calculated slot $slot is out of bounds. index: $index, height: $height, isRelaxed: $isRelaxed',
    );
    final oldChild = children[slot];
    assert(
      indexInChild >= 0,
      'RemoveAt: Calculated indexInChild $indexInChild is negative. index: $index, slot: $slot, height: $height, isRelaxed: $isRelaxed',
    );
    assert(
      indexInChild < oldChild.count,
      'RemoveAt: Invalid indexInChild ($indexInChild). index: $index, slot: $slot, childCount: ${oldChild.count}, isRelaxed: $isRelaxed, sizeTable: $sizeTable',
    );

    final newChild = oldChild.removeAt(indexInChild, owner); // Pass owner down

    if (identical(oldChild, newChild)) {
      return this;
    }

    final newCount = this.count - 1;

    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner);

      if (newChild == null) {
        final removedChildCount = oldChild.count;
        mutableNode.children.removeAt(slot);
        if (mutableNode.children.isEmpty) return null;

        if (mutableNode.sizeTable != null) {
          mutableNode.sizeTable!.removeAt(slot);
          for (int i = slot; i < mutableNode.sizeTable!.length; i++) {
            mutableNode.sizeTable![i] -= removedChildCount;
          }
        }
        // Transient rebalancing needed here
        _rebalanceOrMerge(
          slot > 0 ? slot - 1 : slot,
          mutableNode.children,
          mutableNode.sizeTable,
          owner,
        );
      } else {
        mutableNode.children[slot] = newChild;
        if (mutableNode.sizeTable != null) {
          int currentCumulativeCount =
              (slot == 0) ? 0 : mutableNode.sizeTable![slot - 1];
          for (int i = slot; i < mutableNode.sizeTable!.length; i++) {
            currentCumulativeCount += mutableNode.children[i].count;
            mutableNode.sizeTable![i] = currentCumulativeCount;
          }
        }
        // Transient rebalancing needed here if child underfull
        const minSize =
            (kBranchingFactor + 1) ~/ 2; // Or calculate based on height?
        if (newChild.count < minSize && mutableNode.children.length > 1) {
          // Don't rebalance if only one child left
          _rebalanceOrMerge(
            slot,
            mutableNode.children,
            mutableNode.sizeTable,
            owner,
          );
        }
      }

      mutableNode.count = newCount;
      if (mutableNode.children.length == 1 && mutableNode.height > 0) {
        // Check if the single child itself needs collapsing (height mismatch)
        if (mutableNode.children[0].height < mutableNode.height - 1) {
          return mutableNode.children[0];
        }
        return mutableNode.children[0]; // Collapse
      }
      if (mutableNode.children.isEmpty) {
        return null;
      } // Should be caught earlier
      return mutableNode;
    } else {
      // --- Immutable Path ---
      List<RrbNode<E>> tempChildren;
      List<int>? tempSizeTable;

      if (newChild == null) {
        // Child became empty
        if (this.children.length == 1) return null; // Node becomes empty

        tempChildren = List<RrbNode<E>>.of(children)..removeAt(slot);
        if (sizeTable != null) {
          final removedChildCount = oldChild.count;
          tempSizeTable = List<int>.of(sizeTable!)..removeAt(slot);
          for (int i = slot; i < tempSizeTable.length; i++) {
            tempSizeTable[i] -= removedChildCount;
          }
        } else {
          tempSizeTable = null;
        }
        // Immutable rebalancing needed here after child removal
        final result = _rebalanceOrMerge(
          slot > 0 ? slot - 1 : slot,
          tempChildren,
          tempSizeTable,
          null,
        );
        tempChildren = result.$1;
        tempSizeTable = result.$2;
        // Note: Immutable rebalance would need to return new lists. For now, this will throw.
      } else {
        // Child modified
        tempChildren = List<RrbNode<E>>.of(children);
        tempChildren[slot] = newChild; // Place the modified child
        if (sizeTable != null) {
          tempSizeTable = List<int>.of(sizeTable!);
          int currentCumulativeCount =
              (slot == 0) ? 0 : tempSizeTable[slot - 1];
          for (int i = slot; i < tempSizeTable.length; i++) {
            currentCumulativeCount +=
                tempChildren[i].count; // Use tempChildren here
            tempSizeTable[i] = currentCumulativeCount;
          }
        } else {
          tempSizeTable = null;
        }
        // Immutable rebalancing needed here if child underfull
        const minSize =
            (kBranchingFactor + 1) ~/ 2; // Or calculate based on height?
        if (newChild!.count < minSize && tempChildren.length > 1) {
          // Use newChild! as it's not null here
          final result = _rebalanceOrMerge(
            slot,
            tempChildren,
            tempSizeTable,
            null,
          );
          tempChildren = result.$1;
          tempSizeTable = result.$2;
          tempChildren = result.$1;
          tempSizeTable = result.$2;
          // Note: Immutable rebalance would need to return new lists. For now, this will throw.
        }
      }
      // --- Final checks (No Rebalancing Yet) ---
      if (tempChildren.length == 1 && height > 0) {
        // Check if the single child itself needs collapsing (height mismatch)
        // This handles the case where the recursive call collapsed the child
        if (tempChildren[0].height < this.height - 1) {
          // This state should ideally not happen if collapses are handled perfectly,
          // but return the collapsed child if it does.
          return tempChildren[0];
        }
        // Otherwise, collapse this node
        return tempChildren[0];
      }
      if (tempChildren.isEmpty) {
        return null; // Node became empty
      }

      // Return new node without rebalancing, recalculate size table if needed
      final finalSizeTable =
          (tempSizeTable != null || isRelaxed)
              ? _computeSizeTableIfNeeded(tempChildren)
              : null;
      return RrbInternalNode<E>(height, newCount, tempChildren, finalSizeTable);
    }
  } // End of removeAt

  /// Computes a size table for a list of children for a node at `this.height`.
  /// Returns null if the node can remain strict (all children except potentially
  /// the last one are full for their height).
  List<int>? _computeSizeTableIfNeeded(List<RrbNode<E>> children) {
    if (children.isEmpty) return null;

    bool needsTable = false;
    final int childHeight = height - 1;
    // Allow check even if childHeight is -1 (for leaves becoming internal)
    if (childHeight < 0 && children.any((c) => c is! RrbLeafNode)) {
      return null; // Should not happen with leaves
    }
    if (childHeight < 0)
      return null; // All children must be leaves if height is 1

    final int expectedChildNodeSize =
        (childHeight == 0)
            ? kBranchingFactor
            : (1 << (childHeight * kLog2BranchingFactor));

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
  RrbNode<E> insertAt(int index, E value) {
    assert(index >= 0 && index <= count);

    // Determine the target child slot and index within the child.
    int slot = 0;
    int countBeforeSlot = 0;
    int indexInChild;

    if (isRelaxed) {
      // Use size table if available
      final sizes = sizeTable!;
      while (slot < sizes.length && sizes[slot] <= index) {
        // Check index bounds for safety
        if (slot < sizes.length - 1) {
          countBeforeSlot = sizes[slot];
        } else {
          // If index is beyond the last recorded size, it belongs in the last slot
          countBeforeSlot = sizes.last;
        }
        slot++;
      }
      // Adjust countBeforeSlot if we didn't iterate (inserting in first slot)
      if (slot > 0) {
        countBeforeSlot = sizeTable![slot - 1];
      } else {
        countBeforeSlot = 0;
      }
      // Ensure slot is within bounds if index is exactly count
      if (index == count && slot > 0 && slot == children.length) {
        slot = children.length - 1;
        countBeforeSlot = sizeTable![slot - 1];
      } else if (index == count && slot == 0) {
        // Inserting at end of a list that fits entirely in the first slot
        countBeforeSlot = 0;
      }
    } else {
      // Iterate through children summing counts for strict nodes
      while (slot < children.length - 1 &&
          countBeforeSlot + children[slot].count <= index) {
        countBeforeSlot += children[slot].count;
        slot++;
      }
    }

    // Calculate index within the child
    indexInChild = index - countBeforeSlot;

    // Handle insertion at the very end edge case more robustly
    if (index == count) {
      slot = children.length - 1; // Target the last child
      indexInChild = children[slot].count; // Insert at the end of that child
      // Recalculate countBeforeSlot accurately for the last slot
      countBeforeSlot = 0;
      for (int i = 0; i < slot; i++) {
        countBeforeSlot += children[i].count;
      }
      // Sanity check: indexInChild should match index - countBeforeSlot
      assert(
        indexInChild == index - countBeforeSlot,
        "End insertion index calculation mismatch",
      );
    }

    final oldChild = children[slot];
    // Assertion before recursive call
    assert(
      indexInChild >= 0 && indexInChild <= oldChild.count,
      'Invalid indexInChild ($indexInChild) before recursive insertAt. index: $index, slot: $slot, childCount: ${oldChild.count}',
    );

    final newChildResult = oldChild.insertAt(indexInChild, value);

    if (identical(oldChild, newChildResult)) {
      return this;
    }

    final newChildren = List<RrbNode<E>>.of(children);
    final newCount = count + 1;

    if (newChildResult.height == oldChild.height) {
      // Child did not split, just update the child and potentially the size table
      newChildren[slot] = newChildResult;
      List<int>? newSizeTable =
          sizeTable != null ? List<int>.of(sizeTable!) : null;
      if (newSizeTable != null) {
        int currentCumulative = (slot == 0) ? 0 : newSizeTable[slot - 1];
        for (int i = slot; i < newSizeTable.length; i++) {
          // Ensure index is valid before accessing newChildren
          if (i < newChildren.length) {
            currentCumulative += newChildren[i].count;
            newSizeTable[i] = currentCumulative;
          }
        }
      }
      final finalSizeTable =
          _computeSizeTableIfNeeded(newChildren) ?? newSizeTable;
      return RrbInternalNode<E>(height, newCount, newChildren, finalSizeTable);
    } else {
      // Child split, creating a new internal node of the same height
      assert(newChildResult is RrbInternalNode<E>);
      assert(
        newChildResult.height == height,
      ); // Should be same height after split
      final splitChild = newChildResult as RrbInternalNode<E>;
      assert(splitChild.children.length == 2);

      newChildren[slot] =
          splitChild
              .children[0]; // Replace original child with left part of split
      newChildren.insert(
        slot + 1,
        splitChild.children[1],
      ); // Insert right part of split

      if (newChildren.length <= kBranchingFactor) {
        // No need for parent split, just update size table if needed
        final newSizeTable = _computeSizeTableIfNeeded(newChildren);
        return RrbInternalNode<E>(height, newCount, newChildren, newSizeTable);
      } else {
        // This node needs to split as well
        final splitPoint = (kBranchingFactor + 1) ~/ 2;
        final leftChildren = newChildren.sublist(0, splitPoint);
        final rightChildren = newChildren.sublist(splitPoint);
        final leftSizeTable = _computeSizeTableIfNeeded(leftChildren);
        final rightSizeTable = _computeSizeTableIfNeeded(rightChildren);
        // Ensure count is non-nullable with default 0
        int leftCount =
            leftSizeTable?.last ??
            leftChildren.fold<int>(0, (sum, node) => sum + (node.count ?? 0));
        int rightCount = newCount - leftCount;
        final newLeftNode = RrbInternalNode<E>(
          height,
          leftCount,
          leftChildren,
          leftSizeTable,
        );
        final newRightNode = RrbInternalNode<E>(
          height,
          rightCount,
          rightChildren,
          rightSizeTable,
        );
        // Create new parent
        return RrbInternalNode<E>(height + 1, newCount, [
          newLeftNode,
          newRightNode,
        ], null); // New parent is strict
      }
    }
  }

  /// Returns this node if mutable and owned, otherwise a mutable copy.
  /// Used for transient operations.
  RrbInternalNode<E> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy with the new owner
    return RrbInternalNode<E>(
      height,
      count,
      List<RrbNode<E>>.of(children, growable: true),
      sizeTable != null ? List<int>.of(sizeTable!, growable: true) : null,
      owner,
    );
  }

  @override
  RrbNode<E> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // If owned, become immutable
      for (int i = 0; i < children.length; i++) {
        // Recursively freeze children
        children[i] = children[i].freeze(owner);
      }
      this._owner = null; // Clear owner
      this.children = List.unmodifiable(
        children,
      ); // Make children list immutable
      if (sizeTable != null) {
        // Make size table immutable if it exists
        this.sizeTable = List.unmodifiable(sizeTable!);
      }
      return this;
    }
    // Already immutable or not owned by the freezer
    return this;
  }

  /// Handles rebalancing or merging of nodes after a removal operation
  /// might have left a node underfull.
  ///
  /// `slot` is the index of the *first* node in the pair to consider merging or
  /// rebalancing (i.e., node at `slot` and `slot + 1`).
  ///
  /// For the transient path (`owner != null`), this method modifies the `children`
  /// and `sizeTable` lists directly.
  /// For the immutable path (`owner == null`), this method returns the *new*
  /// children and sizeTable lists resulting from the operation.
  ///
  /// Returns a tuple containing the potentially modified children list and size table.
  (List<RrbNode<E>>, List<int>?) _rebalanceOrMerge(
    int slot,
    List<RrbNode<E>> children, // The list of children (mutable if transient)
    List<int>? sizeTable, // The size table (mutable if transient)
    TransientOwner? owner,
  ) {
    // Basic checks
    if (children.length <= 1 || slot >= children.length - 1) {
      // Cannot merge/rebalance if only one child or targeting the last possible pair.
      return (
        children,
        sizeTable,
      ); // Return original lists as no action was needed
    }

    final node1 = children[slot];
    final node2 = children[slot + 1];
    final combinedCount = node1.count + node2.count;

    // Define minimum size (simplified for now, might depend on height)
    // TODO: Define minSize more accurately based on RRB-Tree paper/specs
    const minSize = kBranchingFactor ~/ 2; // Example: Half full

    // Check if either node is significantly underfull or if merging is beneficial
    final bool needsAction = node1.count < minSize || node2.count < minSize;
    final bool canMerge =
        (combinedCount <= kBranchingFactor) &&
        ((node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) ||
            (node1 is RrbInternalNode<E> &&
                node2 is RrbInternalNode<E> &&
                node1.height == node2.height));

    if (!needsAction) {
      // Nodes are sufficiently full, no action needed for this pair.
      return (
        children,
        sizeTable,
      ); // Return original lists as no action was needed
    }

    print(
      'DEBUG: _rebalanceOrMerge triggered for slot $slot. Node1 count: ${node1.count}, Node2 count: ${node2.count}, Combined: $combinedCount, CanMerge: $canMerge',
    );

    if (owner != null) {
      // --- Transient Path ---
      if (canMerge) {
        // TODO: Implement transient merge logic
        // 1. Combine children/elements of node1 and node2 into node1.
        // 2. Remove node2 from the children list.
        // 3. Update sizeTable if present.
        print('Transient Merge logic needed for slot $slot');
        throw UnimplementedError('Transient Merge not implemented');
      } else {
        // TODO: Implement transient steal logic (rebalance)
        // 1. Determine direction (steal from left or right neighbor - this function only handles right neighbor `slot+1`).
        // 2. Move one child/element from node2 to node1.
        // 3. Update counts of node1 and node2.
        // 4. Update sizeTable if present.
        print('Transient Steal logic needed for slot $slot');
        throw UnimplementedError('Transient Steal not implemented');
      }
      // Remember to update parent count (handled in removeAt)
    } else {
      // --- Immutable Path ---
      if (canMerge) {
        // Immutable Merge Logic
        print('Attempting Immutable Merge for slot $slot');
        RrbNode<E> newMergedNode;

        if (node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) {
          // Merge two leaf nodes
          final combinedElements = [...node1.elements, ...node2.elements];
          newMergedNode = RrbLeafNode<E>(combinedElements);
        } else if (node1 is RrbInternalNode<E> &&
            node2 is RrbInternalNode<E> &&
            node1.height == node2.height) {
          // Merge two internal nodes of the same height
          final combinedChildren = [...node1.children, ...node2.children];
          // Recalculate size table for the merged node's children
          final newMergedNodeSizeTable = _computeSizeTableIfNeeded(
            combinedChildren,
          );
          newMergedNode = RrbInternalNode<E>(
            node1.height, // Height remains the same
            combinedCount,
            combinedChildren,
            newMergedNodeSizeTable,
          );
        } else {
          // This case should ideally not happen in standard RRB-Tree merge scenarios
          // after balanced removals, but throw for safety.
          throw StateError(
            'Cannot merge nodes of different types or heights: ${node1.runtimeType} and ${node2.runtimeType}',
          );
        }

        // Create new parent children list with the merged node
        final newParentChildren =
            List<RrbNode<E>>.of(children)
              ..removeAt(slot + 1) // Remove node2 first
              ..removeAt(slot) // Then remove node1
              ..insert(slot, newMergedNode); // Insert the merged node

        // Recalculate parent's size table (important!)
        final newParentSizeTable = _computeSizeTableIfNeeded(newParentChildren);

        // TODO: Modify removeAt to accept and use these new lists
        print(
          'Immutable Merge completed (logic only). New children count: ${newParentChildren.length}',
        );

        // Return the new lists for the immutable path
        return (newParentChildren, newParentSizeTable);
      } else {
        // Immutable Steal Logic (Rebalance)
        print('Attempting Immutable Steal for slot $slot');

        // Simplified: Assume we always steal from right (node2) to left (node1) if node1 is underfull.
        // A full implementation would check node2 size and potentially steal from left neighbor if needed.
        if (node1.count < minSize && node2.count > minSize) {
          print('Stealing from node2 to node1');
          RrbNode<E> newNode1;
          RrbNode<E> newNode2;

          if (node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) {
            // Steal first element from node2 leaf
            final elementToSteal = node2.elements[0];
            final newNode1Elements = [...node1.elements, elementToSteal];
            final newNode2Elements = node2.elements.sublist(1);

            newNode1 = RrbLeafNode<E>(newNode1Elements);
            newNode2 = RrbLeafNode<E>(newNode2Elements);
          } else if (node1 is RrbInternalNode<E> &&
              node2 is RrbInternalNode<E> &&
              node1.height == node2.height) {
            // Steal first child from node2 internal node
            final childToSteal = node2.children[0];
            final newNode1Children = [...node1.children, childToSteal];
            final newNode2Children = node2.children.sublist(1);

            // Recalculate counts and size tables for the new nodes
            final newNode1Count = node1.count + childToSteal.count;
            final newNode2Count = node2.count - childToSteal.count;
            final newNode1SizeTable = _computeSizeTableIfNeeded(
              newNode1Children,
            );
            final newNode2SizeTable = _computeSizeTableIfNeeded(
              newNode2Children,
            );

            newNode1 = RrbInternalNode<E>(
              node1.height,
              newNode1Count,
              newNode1Children,
              newNode1SizeTable,
            );
            newNode2 = RrbInternalNode<E>(
              node2.height,
              newNode2Count,
              newNode2Children,
              newNode2SizeTable,
            );
          } else {
            // Cannot steal between different types/heights
            throw StateError(
              'Cannot steal between nodes of different types or heights: ${node1.runtimeType} and ${node2.runtimeType}',
            );
          }

          // Create new parent children list
          final newParentChildren = List<RrbNode<E>>.of(children);
          newParentChildren[slot] = newNode1;
          newParentChildren[slot + 1] = newNode2;

          // Recalculate parent's size table
          final newParentSizeTable = _computeSizeTableIfNeeded(
            newParentChildren,
          );

          print('Immutable Steal (right-to-left) completed.');
          return (newParentChildren, newParentSizeTable);
        } else if (node2.count < minSize && node1.count > minSize) {
          print('Stealing from node1 to node2');
          RrbNode<E> newNode1;
          RrbNode<E> newNode2;

          if (node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) {
            // Steal last element from node1 leaf
            final elementToSteal = node1.elements.last;
            final newNode1Elements = node1.elements.sublist(
              0,
              node1.elements.length - 1,
            );
            final newNode2Elements = [elementToSteal, ...node2.elements];

            newNode1 = RrbLeafNode<E>(newNode1Elements);
            newNode2 = RrbLeafNode<E>(newNode2Elements);
          } else if (node1 is RrbInternalNode<E> &&
              node2 is RrbInternalNode<E> &&
              node1.height == node2.height) {
            // Steal last child from node1 internal node
            final childToSteal = node1.children.last;
            final newNode1Children = node1.children.sublist(
              0,
              node1.children.length - 1,
            );
            final newNode2Children = [childToSteal, ...node2.children];

            // Recalculate counts and size tables for the new nodes
            final newNode1Count = node1.count - childToSteal.count;
            final newNode2Count = node2.count + childToSteal.count;
            final newNode1SizeTable = _computeSizeTableIfNeeded(
              newNode1Children,
            );
            final newNode2SizeTable = _computeSizeTableIfNeeded(
              newNode2Children,
            );

            newNode1 = RrbInternalNode<E>(
              node1.height,
              newNode1Count,
              newNode1Children,
              newNode1SizeTable,
            );
            newNode2 = RrbInternalNode<E>(
              node2.height,
              newNode2Count,
              newNode2Children,
              newNode2SizeTable,
            );
          } else {
            // Cannot steal between different types/heights
            throw StateError(
              'Cannot steal between nodes of different types or heights: ${node1.runtimeType} and ${node2.runtimeType}',
            );
          }

          // Create new parent children list
          final newParentChildren = List<RrbNode<E>>.of(children);
          newParentChildren[slot] = newNode1;
          newParentChildren[slot + 1] = newNode2;

          // Recalculate parent's size table
          final newParentSizeTable = _computeSizeTableIfNeeded(
            newParentChildren,
          );

          print('Immutable Steal (left-to-right) completed.');
          return (newParentChildren, newParentSizeTable);
        } else {
          // Cannot steal: Merge the two nodes even if oversized, then split.
          print('Cannot steal for slot $slot - Performing Merge-Split.');

          // 1. Merge node1 and node2 (similar to 'canMerge' logic)
          RrbNode<E> mergedNode;
          if (node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) {
            final combinedElements = [...node1.elements, ...node2.elements];
            // Create potentially oversized leaf
            mergedNode = RrbLeafNode<E>(combinedElements);
          } else if (node1 is RrbInternalNode<E> &&
              node2 is RrbInternalNode<E> &&
              node1.height == node2.height) {
            final combinedChildren = [...node1.children, ...node2.children];
            // Create potentially oversized internal node (size table calculated later)
            mergedNode = RrbInternalNode<E>(
              node1.height,
              combinedCount,
              combinedChildren,
              null,
            );
          } else {
            throw StateError(
              'Cannot merge-split nodes of different types or heights: ${node1.runtimeType} and ${node2.runtimeType}',
            );
          }

          // 2. Split the mergedNode into two new nodes
          RrbNode<E> newNode1;
          RrbNode<E> newNode2;
          if (mergedNode is RrbLeafNode<E>) {
            final splitPoint = (mergedNode.elements.length + 1) ~/ 2;
            final leftElements = mergedNode.elements.sublist(0, splitPoint);
            final rightElements = mergedNode.elements.sublist(splitPoint);
            newNode1 = RrbLeafNode<E>(leftElements);
            newNode2 = RrbLeafNode<E>(rightElements);
          } else if (mergedNode is RrbInternalNode<E>) {
            final splitPoint = (mergedNode.children.length + 1) ~/ 2;
            final leftChildren = mergedNode.children.sublist(0, splitPoint);
            final rightChildren = mergedNode.children.sublist(splitPoint);
            // Recalculate counts and size tables for split nodes
            final newNode1SizeTable = _computeSizeTableIfNeeded(leftChildren);
            final newNode2SizeTable = _computeSizeTableIfNeeded(rightChildren);
            // Ensure count is non-nullable with default 0
            final newNode1Count =
                newNode1SizeTable?.last ??
                leftChildren.fold<int>(
                  0,
                  (sum, node) => sum + (node.count ?? 0),
                );
            // Ensure count is non-nullable with default 0
            final newNode2Count =
                combinedCount -
                (newNode1Count ?? 0); // Use default if newNode1Count is null

            newNode1 = RrbInternalNode<E>(
              mergedNode.height,
              newNode1Count ?? 0,
              leftChildren,
              newNode1SizeTable,
            );
            newNode2 = RrbInternalNode<E>(
              mergedNode.height,
              newNode2Count,
              rightChildren,
              newNode2SizeTable,
            );
          } else {
            // Should not happen
            throw StateError('Merged node is of unexpected type during split');
          }

          // 3. Create new parent children list
          final newParentChildren = List<RrbNode<E>>.of(children);
          newParentChildren[slot] = newNode1;
          newParentChildren[slot + 1] = newNode2;

          // 4. Recalculate parent's size table
          final newParentSizeTable = _computeSizeTableIfNeeded(
            newParentChildren,
          );

          print('Immutable Merge-Split completed.');
          return (newParentChildren, newParentSizeTable);
        }
        // Fallback throw if no steal logic path was taken (shouldn't happen with current checks)
        // throw UnimplementedError('Immutable Steal logic path missed');
      }
    }
  }
} // End of RrbInternalNode

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
  static final RrbLeafNode<Never> emptyInstance = RrbLeafNode<Never>._internal(
    const [],
    null,
  );

  /// Creates a leaf RRB-Tree node.
  ///
  /// - [elements]: The list of elements for this leaf. Must not exceed [kBranchingFactor].
  /// - [owner]: Optional [TransientOwner] if creating a mutable transient node.
  ///
  /// If an [owner] is provided, the [elements] list is kept mutable.
  /// Otherwise, it is converted to an unmodifiable list.
  RrbLeafNode(List<E> elements, [TransientOwner? owner])
    : elements =
          (owner != null || elements.isEmpty)
              ? elements
              : List.unmodifiable(elements),
      assert(elements.length <= kBranchingFactor),
      super(owner);

  /// Internal constructor used only for the canonical empty instance.
  RrbLeafNode._internal(this.elements, TransientOwner? owner) : super(owner);

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
    return RrbLeafNode<E>(newElements);
  }

  @override
  RrbNode<E> add(E value) {
    if (elements.length < kBranchingFactor) {
      final newElements = List<E>.of(elements)..add(value);
      return RrbLeafNode<E>(newElements);
    } else {
      // Leaf is full, split into a new parent internal node
      final newLeaf = RrbLeafNode<E>([value]);
      // New parent has height 1, count = old count + 1, children = [this, newLeaf]
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
      // Return a new immutable leaf node
      return RrbLeafNode<E>(newElements, null);
    }
  }

  @override
  RrbNode<E> insertAt(int index, E value) {
    assert(index >= 0 && index <= count);

    if (elements.length < kBranchingFactor) {
      // Leaf has space, insert directly
      final newElements = List<E>.of(elements)..insert(index, value);
      return RrbLeafNode<E>(newElements);
    } else {
      // Leaf is full, needs to split
      final tempElements = List<E>.of(elements)..insert(index, value);
      final splitPoint = (kBranchingFactor + 1) ~/ 2;
      final leftElements = tempElements.sublist(0, splitPoint);
      final rightElements = tempElements.sublist(splitPoint);
      final newLeftLeaf = RrbLeafNode<E>(leftElements);
      final newRightLeaf = RrbLeafNode<E>(rightElements);
      // Create new parent internal node
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
    // Create a mutable copy with the new owner
    return RrbLeafNode<E>(List<E>.of(elements), owner);
  }

  @override
  RrbNode<E> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // If owned, become immutable
      this._owner = null;
      this.elements = List.unmodifiable(
        elements,
      ); // Make internal list immutable
      return this;
    }
    // Already immutable or not owned by the freezer
    return this;
  }
} // End of RrbLeafNode
