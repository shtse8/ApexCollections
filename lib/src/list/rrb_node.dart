/// Defines the core structures for RRB-Tree nodes used by ApexList.
library;

const int kBranchingFactor = 32; // Or M, typically 32
const int kLog2BranchingFactor = 5; // log2(32)

// --- Transient Ownership ---

/// A marker object to track ownership for transient mutations.
class TransientOwner {
  const TransientOwner();
}

/// Base class for RRB-Tree nodes.
abstract class RrbNode<E> {
  /// Optional owner for transient nodes. If non-null, this node might be mutable.
  TransientOwner? _owner; // Made mutable for freezing

  /// Constructor for subclasses.
  RrbNode([this._owner]); // Changed to non-const

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
  RrbNode<E>? removeAt(int index, [TransientOwner? owner]); // Added owner

  /// Returns true if this node represents the canonical empty node.
  bool get isEmptyNode => false;

  /// Returns true if this node is marked as transient and owned by [owner].
  bool isTransient(TransientOwner? owner) => owner != null && _owner == owner;

  /// Returns an immutable version of this node.
  RrbNode<E> freeze(TransientOwner? owner);

  /// Returns a new node structure representing the tree after inserting [value]
  /// at the effective [index] within this subtree.
  /// The [index] must be valid (0 <= index <= count).
  /// This might involve node splits and increasing tree height.
  RrbNode<E> insertAt(int index, E value);
}

/// Represents an internal node (branch) in the RRB-Tree.
/// Contains references to child nodes and potentially a size table if relaxed.
class RrbInternalNode<E> extends RrbNode<E> {
  @override
  final int height;

  @override
  int count; // Made non-final for transient mutation

  // Made fields non-final and removed duplicates for transient mutability
  List<RrbNode<E>> children;
  List<int>? sizeTable;

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

  /// Indicates if this node requires a size table for relaxed radix search.
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
        int leftCount =
            leftSizeTable?.last ??
            leftChildren.fold(0, (sum, node) => sum + node.count);
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
  RrbInternalNode<E> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
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
      for (int i = 0; i < children.length; i++) {
        children[i] = children[i].freeze(owner);
      }
      this._owner = null;
      this.children = List.unmodifiable(children);
      if (sizeTable != null) {
        this.sizeTable = List.unmodifiable(sizeTable!);
      }
      return this;
    }
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
  /// For the immutable path (`owner == null`), this method should technically
  /// return the *new* children and sizeTable lists, but the current `removeAt`
  /// implementation doesn't handle that return value yet. We'll focus on the
  /// logic first and adapt the return later if needed for immutability.
  /// Returns the potentially modified children and sizeTable lists for the immutable path.
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
          // Cannot steal (e.g., both are minimal size, or types incompatible for merge/steal)
          // This might indicate a logic error or a need for more complex balancing.
          // For now, return unmodified nodes. This might lead to incorrect structure later.
          print('Cannot merge or steal for slot $slot - Returning unmodified.');
          return (children, sizeTable);
          // throw UnimplementedError('Cannot steal - Edge case not handled');
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

  List<E> elements;

  static final RrbLeafNode<Never> emptyInstance = RrbLeafNode<Never>._internal(
    const [],
    null,
  );

  RrbLeafNode(List<E> elements, [TransientOwner? owner])
    : elements =
          (owner != null || elements.isEmpty)
              ? elements
              : List.unmodifiable(elements),
      assert(elements.length <= kBranchingFactor),
      super(owner);

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
      final newLeaf = RrbLeafNode<E>([value]);
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
        return null;
      }
      mutableNode.elements.removeAt(index);
      return mutableNode;
    } else {
      // --- Immutable Path ---
      if (elements.length == 1) {
        return null;
      }
      final newElements = List<E>.of(elements)..removeAt(index);
      return RrbLeafNode<E>(newElements, null);
    }
  }

  @override
  RrbNode<E> insertAt(int index, E value) {
    assert(index >= 0 && index <= count);

    if (elements.length < kBranchingFactor) {
      final newElements = List<E>.of(elements)..insert(index, value);
      return RrbLeafNode<E>(newElements);
    } else {
      // Leaf needs to split
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
  RrbLeafNode<E> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    return RrbLeafNode<E>(List<E>.of(elements), owner);
  }

  @override
  RrbNode<E> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      this._owner = null;
      this.elements = List.unmodifiable(elements);
      return this;
    }
    return this;
  }
} // End of RrbLeafNode
