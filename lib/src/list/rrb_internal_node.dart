/// Defines the [RrbInternalNode] class for the RRB-Tree implementation.
library;

import 'dart:math';
import 'rrb_node_base.dart';
import 'rrb_leaf_node.dart'; // Import leaf node for type checks and merging

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

  /// Creates an internal RRB-Tree node, copying a range of children from an input list.
  /// Used primarily by the bulk loader (`ApexListImpl.fromIterable`).
  factory RrbInternalNode.fromRange(
    int height,
    int count,
    List<RrbNode<E>> childrenInput,
    int start,
    int end, [
    List<int>?
    sizeTable, // Size table corresponds to the children *within the range*
    TransientOwner? owner,
  ]) {
    final rangeLength = end - start; // Calculate range length
    final childrenList = List<RrbNode<E>>.generate(
      // Use generate
      rangeLength,
      (i) => childrenInput[start + i], // Access directly by index
      growable: owner != null, // Growable only if transient
    );
    // Use the default constructor with the prepared children list
    return RrbInternalNode<E>(height, count, childrenList, sizeTable, owner);
  }

  /// Creates an internal node directly from a given list of children (e.g., for splitting, merging).
  /// Use `RrbInternalNode.fromRange` for bulk loading.
  RrbInternalNode(
    this.height,
    this.count,
    List<RrbNode<E>> children, [
    List<int>? sizeTable,
    TransientOwner? owner,
  ]) : children =
           (owner != null)
               ? children
               : List.unmodifiable(children), // Use list directly
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

    int slot;
    int indexInChild;

    if (isRelaxed) {
      // --- Relaxed Path: Use Binary Search on sizeTable ---
      final sizes = sizeTable!;
      // Binary search to find the first slot where sizes[slot] > index
      int low = 0;
      int high = sizes.length - 1;
      slot =
          sizes
              .length; // Default to last slot if index is >= last cumulative count

      while (low <= high) {
        final mid = low + ((high - low) >> 1); // Efficient midpoint calculation
        if (sizes[mid] > index) {
          slot = mid; // Potential slot found, try searching lower half
          high = mid - 1;
        } else {
          low = mid + 1; // Index is in the upper half
        }
      }

      final countBeforeSlot = (slot == 0) ? 0 : sizes[slot - 1];
      indexInChild = index - countBeforeSlot;
    } else {
      // --- Strict Path: Reverted to Linear Scan ---
      // Iterate through children summing counts for strict nodes.
      // Direct O(1) calculation was causing errors, likely due to imperfect node fullness
      // or relaxation not being perfectly tracked without a size table.
      int countBeforeSlot = 0;
      slot = 0; // Reset slot for linear scan
      while (slot < children.length - 1 &&
          countBeforeSlot + children[slot].count <= index) {
        countBeforeSlot += children[slot].count;
        slot++;
      }
      indexInChild = index - countBeforeSlot;
    }

    assert(
      slot >= 0 && slot < children.length,
      'Get: Calculated slot $slot is out of bounds. index: $index, height: $height, isRelaxed: $isRelaxed',
    );
    final child = children[slot];
    assert(
      indexInChild >= 0 && indexInChild < child.count,
      'Get: Invalid indexInChild ($indexInChild). index: $index, slot: $slot, childCount: ${child.count}, height: $height, isRelaxed: $isRelaxed',
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
    // Use default constructor as we created a full copy of children
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
        // Use default constructor
        return RrbInternalNode<E>(
          height,
          newCount,
          newChildren,
          finalSizeTable,
        );
      } else {
        // Node needs to split
        final newNodeList = [nodeToAdd];
        // Use default constructor
        final newParentInternal = RrbInternalNode<E>(
          height,
          nodeToAdd.count,
          newNodeList, // Pass the list directly
          null, // New node is strict
        );
        // Create new parent using default constructor
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
      // Use default constructor
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
        if (newChild.count < minSize && tempChildren.length > 1) {
          final result = _rebalanceOrMerge(
            slot,
            tempChildren,
            tempSizeTable,
            null,
          );
          tempChildren = result.$1;
          tempSizeTable = result.$2;
          // Note: Immutable rebalance would need to return new lists. For now, this will throw.
        }
      }
      // --- Final checks (Original logic before last attempt) ---
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
      // Use the potentially updated tempSizeTable from rebalancing/merging
      // Recalculate only if it was null *before* rebalancing and might be needed now,
      // or if the original node was relaxed (implying it might still need one).
      final finalSizeTable =
          (tempSizeTable != null || isRelaxed)
              ? (tempSizeTable ?? _computeSizeTableIfNeeded(tempChildren))
              : null;
      // Use default constructor
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
    if (childHeight < 0) {
      return null; // All children must be leaves if height is 1
    }

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
      // Use default constructor
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
        // Use default constructor
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
        // Use default constructor
        final newLeftNode = RrbInternalNode<E>(
          height,
          leftCount,
          leftChildren,
          leftSizeTable,
        );
        // Use default constructor
        final newRightNode = RrbInternalNode<E>(
          height,
          rightCount,
          rightChildren,
          rightSizeTable,
        );
        // Create new parent using default constructor
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
    // Create a mutable copy with the new owner using default constructor
    return RrbInternalNode<E>(
      height,
      count,
      List<RrbNode<E>>.of(children, growable: true),
      sizeTable != null ? List<int>.of(sizeTable!, growable: true) : null,
      owner,
    );
  }

  /// Updates the count of this node during transient operations.
  /// Should only be called on a node owned by the current [owner].
  void _transientSetCount(int newCount, TransientOwner? owner) {
    assert(isTransient(owner), 'Cannot set count on non-transient node');
    count = newCount;
  }

  @override
  RrbNode<E> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // If owned, become immutable
      for (int i = 0; i < children.length; i++) {
        // Recursively freeze children
        children[i] = children[i].freeze(owner);
      }
      internalClearOwner(owner); // Use base class method to clear owner
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

  /// Handles rebalancing or merging of adjacent child nodes after a removal
  /// operation might have left one or both underfull. It attempts to merge nodes
  /// if their combined size fits within [kBranchingFactor], or steal elements/children
  /// if one is underfull and the other has spare capacity. If neither merge nor
  /// steal is possible or sufficient, it uses a plan-based rebalancing strategy
  /// (`_createRebalancePlan`, `_executeRebalancePlan`/`_executeTransientRebalancePlan`)
  /// to redistribute elements/children across the affected nodes according to the
  /// Search Step Invariant.
  ///
  /// - [slot]: The index of the *first* node in the pair to consider merging or
  ///   rebalancing (i.e., node at `slot` and `slot + 1`).
  /// - [children]: The list of child nodes (mutable if transient).
  /// - [sizeTable]: The size table (mutable if transient).
  /// - [owner]: The [TransientOwner] if operating transiently.
  ///
  /// **Returns:**
  /// A tuple `(List<RrbNode<E>>, List<int>?)`.
  /// - For the transient path (`owner != null`), returns the *same* (potentially mutated)
  ///   `children` and `sizeTable` lists passed in.
  /// - For the immutable path (`owner == null`), returns *new* list instances
  ///   representing the children and size table after the operation.
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

    // Removed debug print

    if (owner != null) {
      // --- Transient Path ---
      // Ensure the parent node is mutable
      final mutableParent = ensureMutable(owner);
      // Use the mutable lists from the parent
      final mutableChildren = mutableParent.children;
      final mutableSizeTable = mutableParent.sizeTable;

      if (canMerge) {
        // Transient Merge Logic
        RrbNode<E> mergedNode;
        if (node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) {
          // Merge leaves by creating a new mutable leaf with combined elements
          final combinedElements = List<E>.of(node1.elements, growable: true)
            ..addAll(node2.elements);
          mergedNode = RrbLeafNode<E>.internal(
            // Use public internal constructor
            combinedElements,
            owner,
          ); // Pass owner
        } else if (node1 is RrbInternalNode<E> &&
            node2 is RrbInternalNode<E> &&
            node1.height == node2.height) {
          // Merge internal nodes by creating a new mutable internal node
          final combinedChildren = List<RrbNode<E>>.of(
            node1.children,
            growable: true,
          )..addAll(node2.children);
          // Ensure children are potentially mutable if needed later
          for (int k = 0; k < combinedChildren.length; ++k) {
            // Use isTransient to check ownership
            if (!combinedChildren[k].isTransient(owner)) {
              // Correctly use isTransient here
              // This might be overly aggressive if child doesn't need mutation,
              // but safer for ensuring transient propagation if merge happens deep down.
              // A more refined approach could check if child *will* be mutated.
              // For now, ensure ownership for simplicity.
              // Note: This assumes ensureMutable exists on RrbNode or subtypes handle it.
              // We might need a way to make a node mutable without full copy if already owned.
              // Let's assume ensureMutable handles this correctly for now.
              // TODO: Revisit transient propagation efficiency.
              if (combinedChildren[k] is RrbInternalNode<E>) {
                combinedChildren[k] = (combinedChildren[k]
                        as RrbInternalNode<E>)
                    .ensureMutable(owner);
              } else if (combinedChildren[k] is RrbLeafNode<E>) {
                combinedChildren[k] = (combinedChildren[k] as RrbLeafNode<E>)
                    .ensureMutable(owner);
              }
            }
          }
          final mergedNodeSizeTable = _computeSizeTableIfNeeded(
            combinedChildren,
          );
          mergedNode = RrbInternalNode<E>(
            node1.height,
            combinedCount,
            combinedChildren, // Already mutable list
            mergedNodeSizeTable,
            owner, // Pass owner
          );
        } else {
          // Should not happen if canMerge is true
          throw StateError(
            '[Transient] Cannot merge nodes of different types or heights: ${node1.runtimeType} and ${node2.runtimeType}',
          );
        }

        // Modify parent's children list in place
        mutableChildren.removeAt(slot + 1);
        mutableChildren[slot] = mergedNode;

        // Update parent's size table in place if it exists
        if (mutableSizeTable != null) {
          // Remove entry for node2
          mutableSizeTable.removeAt(slot + 1);
          // Update entry for the new merged node and subsequent entries
          int currentCumulative = (slot == 0) ? 0 : mutableSizeTable[slot - 1];
          for (int k = slot; k < mutableSizeTable.length; k++) {
            currentCumulative += mutableChildren[k].count;
            mutableSizeTable[k] = currentCumulative;
          }
        }
        // No need to return lists, mutation happened in place.
        // The calling `removeAt` will handle returning the mutated parent.
      } else {
        // Transient Steal Logic (Rebalance)
        if (node1.count < minSize && node2.count > minSize) {
          // Steal from right (node2) to left (node1)
          // Cast to specific types before calling ensureMutable
          final mutableNode1 =
              (node1 is RrbInternalNode<E>)
                  ? (node1 as RrbInternalNode<E>).ensureMutable(owner)
                  : (node1 as RrbLeafNode<E>).ensureMutable(owner);
          final mutableNode2 =
              (node2 is RrbInternalNode<E>)
                  ? (node2 as RrbInternalNode<E>).ensureMutable(owner)
                  : (node2 as RrbLeafNode<E>).ensureMutable(owner);

          if (mutableNode1 is RrbLeafNode<E> &&
              mutableNode2 is RrbLeafNode<E>) {
            // Steal first element from node2 leaf
            final elementToSteal = mutableNode2.elements.removeAt(0);
            mutableNode1.elements.add(elementToSteal);
          } else if (mutableNode1 is RrbInternalNode<E> &&
              mutableNode2 is RrbInternalNode<E> &&
              mutableNode1.height == mutableNode2.height) {
            // Steal first child from node2 internal node
            final childToSteal = mutableNode2.children.removeAt(0);
            mutableNode1.children.add(childToSteal);
            // Recalculate node1's size table (mutable)
            mutableNode1.sizeTable = _computeSizeTableIfNeeded(
              mutableNode1.children,
            );
            // Recalculate node2's size table (mutable)
            mutableNode2.sizeTable = _computeSizeTableIfNeeded(
              mutableNode2.children,
            );
          } else {
            throw StateError(
              '[Transient] Cannot steal between nodes of different types or heights: ${node1.runtimeType} and ${node2.runtimeType}',
            );
          }
          // Update counts using the transient setter for internal nodes
          if (mutableNode1 is RrbInternalNode<E>) {
            mutableNode1._transientSetCount(mutableNode1.count + 1, owner);
          }
          if (mutableNode2 is RrbInternalNode<E>) {
            mutableNode2._transientSetCount(mutableNode2.count - 1, owner);
          }

          // Update parent's size table (mutableSizeTable) if necessary
          if (mutableSizeTable != null) {
            int currentCumulative =
                (slot == 0) ? 0 : mutableSizeTable[slot - 1];
            for (int k = slot; k < mutableSizeTable.length; k++) {
              currentCumulative +=
                  mutableChildren[k].count; // Use updated counts
              mutableSizeTable[k] = currentCumulative;
            }
          }
          // Ensure the modified nodes are placed back (might be redundant if ensureMutable returned same instance)
          mutableChildren[slot] = mutableNode1;
          mutableChildren[slot + 1] = mutableNode2;
        } else if (node2.count < minSize && node1.count > minSize) {
          // Steal from left (node1) to right (node2)
          // Cast to specific types before calling ensureMutable
          final mutableNode1 =
              (node1 is RrbInternalNode<E>)
                  ? (node1 as RrbInternalNode<E>).ensureMutable(owner)
                  : (node1 as RrbLeafNode<E>).ensureMutable(owner);
          final mutableNode2 =
              (node2 is RrbInternalNode<E>)
                  ? (node2 as RrbInternalNode<E>).ensureMutable(owner)
                  : (node2 as RrbLeafNode<E>).ensureMutable(owner);

          if (mutableNode1 is RrbLeafNode<E> &&
              mutableNode2 is RrbLeafNode<E>) {
            // Steal last element from node1 leaf
            final elementToSteal = mutableNode1.elements.removeLast();
            mutableNode2.elements.insert(0, elementToSteal);
          } else if (mutableNode1 is RrbInternalNode<E> &&
              mutableNode2 is RrbInternalNode<E> &&
              mutableNode1.height == mutableNode2.height) {
            // Steal last child from node1 internal node
            final childToSteal = mutableNode1.children.removeLast();
            mutableNode2.children.insert(0, childToSteal);
            // Recalculate node1's size table (mutable)
            mutableNode1.sizeTable = _computeSizeTableIfNeeded(
              mutableNode1.children,
            );
            // Recalculate node2's size table (mutable)
            mutableNode2.sizeTable = _computeSizeTableIfNeeded(
              mutableNode2.children,
            );
          } else {
            throw StateError(
              '[Transient] Cannot steal between nodes of different types or heights: ${node1.runtimeType} and ${node2.runtimeType}',
            );
          }
          // Update counts using the transient setter for internal nodes
          if (mutableNode1 is RrbInternalNode<E>) {
            mutableNode1._transientSetCount(mutableNode1.count - 1, owner);
          }
          if (mutableNode2 is RrbInternalNode<E>) {
            mutableNode2._transientSetCount(mutableNode2.count + 1, owner);
          }

          // Update parent's size table (mutableSizeTable) if necessary
          if (mutableSizeTable != null) {
            int currentCumulative =
                (slot == 0) ? 0 : mutableSizeTable[slot - 1];
            for (int k = slot; k < mutableSizeTable.length; k++) {
              currentCumulative +=
                  mutableChildren[k].count; // Use updated counts
              mutableSizeTable[k] = currentCumulative;
            }
          }
          // Ensure the modified nodes are placed back
          mutableChildren[slot] = mutableNode1;
          mutableChildren[slot + 1] = mutableNode2;
        } else {
          // Cannot merge or steal: Use plan-based rebalancing.

          // 1. Define the nodes to rebalance (use the original node references)
          final nodesToRebalance = [node1, node2];

          // 2. Create the rebalancing plan
          final plan = _createRebalancePlan(nodesToRebalance);

          // 3. Execute the plan transiently to get the list of balanced nodes
          //    (mutating original nodes or creating new mutable ones as needed).
          final balancedNodes = _executeTransientRebalancePlan(
            nodesToRebalance, // Pass the original nodes (potentially already mutable)
            plan,
            owner,
          );

          // 4. Modify parent's children list in place
          mutableChildren.removeRange(
            slot,
            slot + 2,
          ); // Remove original node1 and node2
          mutableChildren.insertAll(
            slot,
            balancedNodes,
          ); // Insert the balanced nodes

          // 5. Update parent's size table (mutableSizeTable) if necessary
          if (mutableSizeTable != null) {
            // Safer approach: Recalculate the relevant part of the size table from scratch
            int currentCumulative =
                (slot == 0) ? 0 : mutableSizeTable[slot - 1];
            for (int k = slot; k < mutableChildren.length; ++k) {
              currentCumulative += mutableChildren[k].count;
              if (k < mutableSizeTable.length) {
                mutableSizeTable[k] = currentCumulative;
              } else {
                // This should not happen if sizeTable was correctly sized initially
                // or handled during list modifications. For safety, add if needed.
                // Requires sizeTable to be growable if created transiently.
                // Let's assume ensureMutable handled this.
                mutableSizeTable.add(currentCumulative);
              }
            }
            // Adjust table length if nodes were removed overall
            if (mutableChildren.length < mutableSizeTable.length) {
              mutableSizeTable.removeRange(
                mutableChildren.length,
                mutableSizeTable.length,
              );
            }
          }
        }
      }
      // Return the original (potentially mutated) list references for the transient path.
      return (mutableChildren, mutableSizeTable);
    } else {
      // --- Immutable Path ---
      if (canMerge) {
        // Immutable Merge Logic
        RrbNode<E> newMergedNode;

        if (node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) {
          // Merge two leaf nodes
          final combinedElements = [...node1.elements, ...node2.elements];
          // Use default constructor
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
          // Use default constructor
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

        // Return the new lists for the immutable path
        return (newParentChildren, newParentSizeTable);
      } else {
        // Immutable Steal Logic (Rebalance)
        // Simplified: Assume we always steal from right (node2) to left (node1) if node1 is underfull.
        // A full implementation would check node2 size and potentially steal from left neighbor if needed.
        if (node1.count < minSize && node2.count > minSize) {
          RrbNode<E> newNode1;
          RrbNode<E> newNode2;

          if (node1 is RrbLeafNode<E> && node2 is RrbLeafNode<E>) {
            // Steal first element from node2 leaf
            final elementToSteal = node2.elements[0];
            final newNode1Elements = [...node1.elements, elementToSteal];
            final newNode2Elements = node2.elements.sublist(1);

            // Use default constructor
            newNode1 = RrbLeafNode<E>(newNode1Elements);
            // Use default constructor
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

            // Use default constructor
            newNode1 = RrbInternalNode<E>(
              node1.height,
              newNode1Count,
              newNode1Children,
              newNode1SizeTable,
            );
            // Use default constructor
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

          return (newParentChildren, newParentSizeTable);
        } else if (node2.count < minSize && node1.count > minSize) {
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

            // Use default constructor
            newNode1 = RrbLeafNode<E>(newNode1Elements);
            // Use default constructor
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

            // Use default constructor
            newNode1 = RrbInternalNode<E>(
              node1.height,
              newNode1Count,
              newNode1Children,
              newNode1SizeTable,
            );
            // Use default constructor
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

          return (newParentChildren, newParentSizeTable);
        } else {
          // Cannot merge or steal. Use the general rebalancing plan.
          // This handles cases where nodes are incompatible or both are too small.

          // 1. Define the nodes to rebalance (just the adjacent pair for now)
          final nodesToRebalance = [node1, node2];

          // 2. Create the rebalancing plan based on the Search Step Invariant
          final plan = _createRebalancePlan(nodesToRebalance);

          // 3. Execute the plan to get the new list of balanced nodes
          final balancedNodes = _executeRebalancePlan(nodesToRebalance, plan);

          // 4. Create the new parent children list by replacing the original pair
          //    with the newly balanced nodes.
          final newParentChildren =
              List<RrbNode<E>>.of(children)
                ..removeRange(slot, slot + 2) // Remove original node1 and node2
                ..insertAll(slot, balancedNodes); // Insert the balanced nodes

          // 5. Recalculate the parent's size table
          final newParentSizeTable = _computeSizeTableIfNeeded(
            newParentChildren,
          );

          // 6. Return the new children and size table
          return (newParentChildren, newParentSizeTable);
        }
      }
    }
  }

  /// Generates a rebalancing plan (list of target sizes) for a sequence of sibling
  /// nodes (`nodesToBalance`). The goal is to redistribute the total number of
  /// elements/children (`s`) among the minimum number of nodes (`n`) required
  /// while satisfying the RRB-Tree Search Step Invariant: `n <= ceil(s / M) + E_MAX`,
  /// where `M` is [kBranchingFactor] and `E_MAX` is [kEMax].
  ///
  /// This ensures that nodes are reasonably full, maintaining efficient lookup performance.
  /// The algorithm iteratively merges or redistributes items from the least full nodes
  /// until the invariant is met.
  ///
  /// Based on `createConcatPlan` from Bagwell's RRB-Tree paper/reference implementations.
  List<int> _createRebalancePlan(List<RrbNode<E>> nodesToBalance) {
    if (nodesToBalance.isEmpty) {
      return [];
    }

    // Initial plan is the current distribution of counts
    // Make it growable as we might modify it in place before slicing
    final plan = nodesToBalance
        .map((node) => node.count)
        .toList(growable: true);

    // Count the total number of items/elements
    final int s = plan.fold(0, (a, b) => a + b);

    // Calculate the optimal number of slots necessary according to the invariant
    // Using double division for ceil, then converting back to int
    final int opt = (s / kBranchingFactor).ceil();

    int i = 0;
    int n = plan.length; // Current effective length of the plan

    // Check if our invariant is met (Search Step Invariant: S <= ceil(P / M) + E_MAX)
    // Keep reducing the number of slots (n) until the invariant holds.
    while (n > opt + kEMax) {
      // Skip slots that are already sufficiently full and don't need redistributing.
      // Use integer division for kEMax / 2.
      // This loop finds the first slot 'i' that needs redistribution.
      while (i < n && plan[i] >= kBranchingFactor - (kEMax ~/ 2)) {
        i++;
      }

      // If we scanned through all remaining slots and they are all sufficiently full,
      // it implies an issue with the invariant logic or initial check.
      // The loop condition `n > opt + kEMax` should prevent this if logic is sound.
      if (i == n) {
        throw StateError(
          'Rebalance plan error: Invariant violated but no slots found needing redistribution.',
        );
      }

      // Slot 'i' needs distributing over its subsequent siblings.
      // 'r' tracks the number of items remaining to be distributed from slot 'i'.
      int r = plan[i];
      int currentSlot = i; // Start distributing into the slot *after* i

      // Distribute items 'r' from plan[i] into subsequent slots (plan[i+1], plan[i+2], ...)
      while (r > 0) {
        currentSlot++; // Move to the next slot to potentially place items into

        // Ensure we don't go out of bounds when accessing plan[currentSlot]
        if (currentSlot >= n) {
          // This indicates an issue: we have items left to distribute ('r' > 0)
          // but no more slots available in the current plan length 'n'.
          // This might happen if the invariant logic allows too many small nodes initially.
          throw StateError(
            'Rebalance plan error: Ran out of slots to distribute remaining items ($r).',
          );
        }

        // Calculate how many items the target slot (plan[currentSlot]) can take
        int spaceInTarget = kBranchingFactor - plan[currentSlot];
        int itemsToMove = min(r, spaceInTarget);

        // Add items to the target slot and update remaining 'r'
        plan[currentSlot] += itemsToMove;
        r -= itemsToMove;
      }
      // After the loop, r == 0, meaning all items from the original plan[i] have been distributed.

      // The original slot plan[i] is now conceptually empty.
      // Shift subsequent plan entries (from i+1 up to n-1) one position to the left
      // to overwrite the now-empty slot i and fill the gap.
      for (int j = i; j < n - 1; j++) {
        plan[j] = plan[j + 1];
      }

      // Decrease the effective plan length because we eliminated one slot (slot 'i')
      n--;

      // Reset 'i' to re-evaluate from the start of the modified plan segment?
      // The reference code uses i--. This seems intended to potentially re-check
      // the slot at the *new* index 'i' (which now contains what was previously at i+1)
      // or the slot before it if i > 0. Let's stick to the reference logic.
      // If i was 0, it remains 0. If i > 0, it moves back one slot.
      if (i > 0) {
        i--;
      }
      // The outer loop `while (n > opt + kEMax)` will continue if the invariant
      // is still not met with the reduced number of slots 'n'.
    } // End while (n > opt + kEMax)

    // Return the final plan containing n entries. Use sublist to get the correct length.
    // The underlying list `plan` might be longer if it wasn't growable:false initially.
    return plan.sublist(0, n);
  }

  /// Executes a rebalancing plan to create a new list of balanced nodes.
  ///
  /// Takes a list of original sibling nodes (`originalNodes`) and a `plan`
  /// (list of target sizes from `_createRebalancePlan`) and returns a new
  /// list of nodes containing the same elements/children redistributed according
  /// to the plan.
  ///
  /// This method performs immutable rebalancing by creating new node instances
  /// according to the sizes specified in the [plan]. It reads from the
  /// [originalNodes] and constructs a new list of balanced nodes.
  ///
  /// Based on `executeConcatPlan` from Bagwell's RRB-Tree paper/reference implementations.
  /// Handles redistribution for both [RrbLeafNode] elements and [RrbInternalNode] children.
  List<RrbNode<E>> _executeRebalancePlan(
    List<RrbNode<E>> originalNodes,
    List<int> plan,
  ) {
    final List<RrbNode<E>> newNodes =
        []; // The resulting list of balanced nodes
    int originalNodeIndex = 0; // Index into the originalNodes list
    int offsetInOriginalNode =
        0; // Offset within the current original node's items/children

    // Iterate through the target sizes defined in the plan
    for (final targetSize in plan) {
      // Get the current node from the original list we are processing
      // Ensure we don't read past the end of originalNodes
      if (originalNodeIndex >= originalNodes.length) {
        throw StateError(
          'Rebalance plan execution error: Ran out of original nodes while processing plan.',
        );
      }
      final currentOriginalNode = originalNodes[originalNodeIndex];

      // Optimization: If the current original node matches the target size exactly
      // and we are at the beginning of that node (offset is 0), we can reuse it directly.
      if (offsetInOriginalNode == 0 &&
          currentOriginalNode.count == targetSize) {
        newNodes.add(currentOriginalNode);
        originalNodeIndex++; // Move to the next original node
        continue; // Move to the next target size in the plan
      }

      // If optimization doesn't apply, we need to construct a new node of the target size.
      // This list will accumulate the items (for leaves) or children (for internal nodes).
      final List<dynamic> newNodeItemsOrChildren = [];

      // Keep taking items/children from the original nodes until the new node reaches the target size.
      while (newNodeItemsOrChildren.length < targetSize) {
        // Ensure we don't read past the end of originalNodes in the inner loop
        if (originalNodeIndex >= originalNodes.length) {
          throw StateError(
            'Rebalance plan execution error: Ran out of original nodes while filling target size $targetSize.',
          );
        }
        // Get the node we are currently taking items/children from.
        // It might have changed if originalNodeIndex was incremented in the previous iteration.
        final nodeToTakeFrom = originalNodes[originalNodeIndex];

        final int required = targetSize - newNodeItemsOrChildren.length;
        // Ensure count is non-null before calculation
        final int nodeCount = nodeToTakeFrom.count ?? 0;
        final int available = nodeCount - offsetInOriginalNode;
        final int countToTake = min(required, available);

        // Check for invalid countToTake which might indicate offset issues
        if (countToTake < 0) {
          throw StateError(
            'Rebalance plan execution error: Negative countToTake ($countToTake). Offset: $offsetInOriginalNode, Available: $available',
          );
        }
        if (countToTake == 0 && required > 0) {
          // This might happen if a node has count 0 but we still need items.
          // Move to the next node.
          offsetInOriginalNode = 0;
          originalNodeIndex++;
          continue;
        }

        // Add the required items/children to the accumulator list.
        if (nodeToTakeFrom is RrbLeafNode<E>) {
          // Ensure sublist bounds are valid
          final endSublist = offsetInOriginalNode + countToTake;
          if (offsetInOriginalNode < 0 ||
              endSublist > nodeToTakeFrom.elements.length) {
            throw StateError(
              'Rebalance plan execution error: Invalid sublist range for leaf node. Offset: $offsetInOriginalNode, Count: $countToTake, Length: ${nodeToTakeFrom.elements.length}',
            );
          }
          newNodeItemsOrChildren.addAll(
            nodeToTakeFrom.elements.sublist(offsetInOriginalNode, endSublist),
          );
        } else if (nodeToTakeFrom is RrbInternalNode<E>) {
          // Ensure sublist bounds are valid
          final endSublist = offsetInOriginalNode + countToTake;
          if (offsetInOriginalNode < 0 ||
              endSublist > nodeToTakeFrom.children.length) {
            throw StateError(
              'Rebalance plan execution error: Invalid sublist range for internal node. Offset: $offsetInOriginalNode, Count: $countToTake, Length: ${nodeToTakeFrom.children.length}',
            );
          }
          newNodeItemsOrChildren.addAll(
            nodeToTakeFrom.children.sublist(offsetInOriginalNode, endSublist),
          );
        } else {
          // Should not happen
          throw StateError('Unexpected node type during plan execution');
        }

        // Update the offset and potentially move to the next original node.
        if (countToTake == available) {
          // Consumed the rest of the current original node.
          offsetInOriginalNode = 0; // Reset offset for the next node.
          originalNodeIndex++; // Move to the next original node.
        } else {
          // Partially consumed the current original node.
          offsetInOriginalNode += countToTake; // Advance the offset.
        }
      } // End while (accumulating items/children for the new node)

      // Create the new node (Leaf or Internal) using the accumulated items/children.
      // The height of the new node is one less than the parent's height (this.height).
      final int newNodeHeight = this.height - 1;
      if (newNodeHeight < 0) {
        throw StateError(
          'Rebalance plan execution error: Calculated node height is negative.',
        );
      }

      if (newNodeHeight == 0) {
        // Create a new Leaf node
        // Ensure items are of type E before creating the list
        final elements = List<E>.from(newNodeItemsOrChildren.whereType<E>());
        if (elements.length != newNodeItemsOrChildren.length) {
          throw StateError(
            'Rebalance plan execution error: Type mismatch when creating leaf node.',
          );
        }
        newNodes.add(RrbLeafNode<E>(elements));
      } else {
        // Create a new Internal node
        // Ensure items are of type RrbNode<E> before creating the list
        final children = List<RrbNode<E>>.from(
          newNodeItemsOrChildren.whereType<RrbNode<E>>(),
        );
        if (children.length != newNodeItemsOrChildren.length) {
          throw StateError(
            'Rebalance plan execution error: Type mismatch when creating internal node.',
          );
        }
        // Calculate size table and count *only* when creating an internal node
        final newSizeTable = _computeSizeTableIfNeeded(children);
        // Ensure count is non-null before fold
        final newCount = children.fold<int>(
          0,
          (sum, node) => sum + (node.count ?? 0),
        );
        newNodes.add(
          RrbInternalNode<E>(newNodeHeight, newCount, children, newSizeTable),
        );
      }
    } // End for (iterating through plan)

    // Final check: ensure all original items/children have been consumed
    if (originalNodeIndex < originalNodes.length &&
        offsetInOriginalNode < (originalNodes[originalNodeIndex].count ?? 0)) {
      throw StateError(
        'Rebalance plan execution error: Not all original items/children were consumed by the plan.',
      );
    }

    return newNodes;
  }

  /// Executes a rebalancing plan transiently, potentially mutating nodes in place.
  ///
  /// Takes a list of sibling nodes (`originalNodes`) intended for rebalancing,
  /// a `plan` (list of target sizes from `_createRebalancePlan`), and the current
  /// [TransientOwner]. It redistributes the elements/children from the `originalNodes`
  /// into a new list of nodes conforming to the `plan`.
  ///
  /// It attempts to reuse nodes from `originalNodes` if they are already owned by
  /// the [owner], clearing and refilling them. Otherwise, it creates new mutable
  /// nodes.
  ///
  /// **Returns:** A list containing the nodes that now represent the balanced segment.
  /// These nodes are potentially mutable and owned by the [owner].
  ///
  /// **Important:** This method assumes the caller will replace the original nodes
  /// in the parent's `children` list with the returned `finalBalancedNodes`.
  List<RrbNode<E>> _executeTransientRebalancePlan(
    List<RrbNode<E>> originalNodes, // Should contain mutable nodes
    List<int> plan,
    TransientOwner owner,
  ) {
    // This implementation aims to modify originalNodes *in place* where possible.
    // It assumes the caller handles inserting/removing the final balanced nodes
    // into the parent's children list.

    final List<RrbNode<E>> finalBalancedNodes = [];
    int sourceNodeIndex =
        0; // Index into the originalNodes list (source of items)
    int offsetInSourceNode = 0; // Offset within the current source node
    final int originalNodeCount = originalNodes.length;

    for (
      int targetNodeIndex = 0;
      targetNodeIndex < plan.length;
      targetNodeIndex++
    ) {
      final targetSize = plan[targetNodeIndex];

      // Get or create a mutable node to fill
      RrbNode<E> nodeToFill;
      if (targetNodeIndex < originalNodeCount) {
        // Try to reuse an existing node from the original list
        nodeToFill = originalNodes[targetNodeIndex];
        if (nodeToFill is RrbInternalNode<E>) {
          nodeToFill = nodeToFill.ensureMutable(owner);
          nodeToFill.children.clear(); // Clear existing content
          nodeToFill.sizeTable = null;
          nodeToFill._transientSetCount(0, owner);
        } else if (nodeToFill is RrbLeafNode<E>) {
          nodeToFill = nodeToFill.ensureMutable(owner);
          nodeToFill.elements.clear(); // Clear existing content
        }
      } else {
        // Need a new node
        final int newNodeHeight = this.height - 1;
        if (newNodeHeight == 0) {
          nodeToFill = RrbLeafNode<E>.internal(
            [],
            owner,
          ); // Use public internal constructor
        } else {
          nodeToFill = RrbInternalNode<E>(newNodeHeight, 0, [], null, owner);
        }
      }

      // Fill the nodeToFill with targetSize items/children
      int currentSize = 0;
      while (currentSize < targetSize) {
        if (sourceNodeIndex >= originalNodeCount) {
          throw StateError(
            'Transient rebalance error: Ran out of source nodes while filling target size.',
          );
        }
        final nodeToTakeFrom = originalNodes[sourceNodeIndex];
        final int nodeCount = nodeToTakeFrom.count ?? 0;
        final int available = nodeCount - offsetInSourceNode;
        final int required = targetSize - currentSize;
        final int countToTake = min(required, available);

        if (countToTake < 0) {
          throw StateError('Transient rebalance error: Negative countToTake.');
        }
        if (countToTake == 0 && required > 0) {
          offsetInSourceNode = 0;
          sourceNodeIndex++;
          continue;
        }

        // Add items/children to nodeToFill (which is mutable)
        if (nodeToFill is RrbLeafNode<E> && nodeToTakeFrom is RrbLeafNode<E>) {
          final sublist = nodeToTakeFrom.elements.sublist(
            offsetInSourceNode,
            offsetInSourceNode + countToTake,
          );
          nodeToFill.elements.addAll(sublist);
          currentSize += countToTake;
        } else if (nodeToFill is RrbInternalNode<E> &&
            nodeToTakeFrom is RrbInternalNode<E>) {
          final sublist = nodeToTakeFrom.children.sublist(
            offsetInSourceNode,
            offsetInSourceNode + countToTake,
          );
          nodeToFill.children.addAll(sublist);
          currentSize += countToTake; // Count children added
        } else {
          throw StateError(
            'Transient rebalance error: Type mismatch between nodeToFill and nodeToTakeFrom.',
          );
        }

        // Update source offset/index
        if (countToTake == available) {
          offsetInSourceNode = 0;
          sourceNodeIndex++;
        } else {
          offsetInSourceNode += countToTake;
        }
      } // End while filling nodeToFill

      // Finalize the filled node (update count and size table if internal)
      if (nodeToFill is RrbInternalNode<E>) {
        final finalCount = nodeToFill.children.fold<int>(
          0,
          (sum, node) => sum + (node.count ?? 0),
        );
        nodeToFill._transientSetCount(finalCount, owner);
        nodeToFill.sizeTable = _computeSizeTableIfNeeded(nodeToFill.children);
      }
      // Leaf count updates automatically

      finalBalancedNodes.add(nodeToFill);
    } // End for loop over plan

    // Optional final check (can be removed later)
    if (sourceNodeIndex < originalNodeCount &&
        offsetInSourceNode < (originalNodes[sourceNodeIndex].count ?? 0)) {
      throw StateError(
        'Transient rebalance error: Not all source items consumed.',
      );
    }

    return finalBalancedNodes;
  }
} // End of RrbInternalNode
