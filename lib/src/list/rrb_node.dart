/// Defines the core structures for RRB-Tree nodes used by ApexList.
library;

const int kBranchingFactor = 32; // Or M, typically 32
const int kLog2BranchingFactor = 5; // log2(32)

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

    final shift = height * kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (kBranchingFactor - 1);

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

    final shift = height * kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (kBranchingFactor - 1);
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
      countBeforeLast = lastChildIndex * (1 << (height * kLog2BranchingFactor));
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

      if (children.length < kBranchingFactor) {
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

    final shift = height * kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (kBranchingFactor - 1);
    int slot = indexInNode; // Default for strict case
    int indexInChild = index & ((1 << shift) - 1); // Default for strict case

    if (isRelaxed) {
      // Find correct slot and index for relaxed node
      final sizes = sizeTable!;
      // Find the first slot 's' such that index < sizes[s].
      // We know index < count (total elements), and sizes[last] == count.
      // Therefore, this loop is guaranteed to find a slot.
      slot = 0;
      while (sizes[slot] <= index) {
        slot++;
      }
      // Now 'slot' is the index of the child node containing the element at 'index'.
      // Calculate the index relative to the start of that child node.
      indexInChild = (slot == 0) ? index : index - sizes[slot - 1];
    }

    final oldChild = children[slot];
    final newChild = oldChild.removeAt(indexInChild);

    if (identical(oldChild, newChild)) {
      return this; // No change below
    }

    var newChildren = List<RrbNode<E>>.of(
      children,
    ); // Use 'var' as it might be reassigned
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
    // If child was modified (not removed), check if rebalancing is needed
    if (newChild != null) {
      // Check if the child is underfull and needs rebalancing/merging
      // Use a threshold, e.g., less than half the branching factor
      // Note: The exact threshold might depend on specific RRB-Tree variant rules.
      const minSize = (kBranchingFactor + 1) ~/ 2; // Example: ceil(M/2)
      if (newChild.count < minSize) {
        // Attempt to rebalance or merge the children array
        final rebalancedResult = _rebalanceOrMerge(
          slot,
          newChildren,
          newSizeTable,
        );
        // Update state based on rebalancing result
        newChildren = rebalancedResult.children;
        newSizeTable = rebalancedResult.sizeTable;
        // newCount remains count - 1, calculated earlier
      }
    }
    // If newChild was null, the child was removed earlier (lines 256-266)

    // After potential rebalancing/merging, check if this node needs collapsing
    if (newChildren.length == 1 && height > 0) {
      // If only one child remains (and we are not the root potentially becoming a leaf),
      // return the child directly to collapse this level.
      // Root node collapse (height 1 -> 0) should be handled by ApexListImpl.
      return newChildren[0];
    }

    // If this node itself became empty after removal/merging
    if (newChildren.isEmpty) {
      return null;
    }

    // Return the potentially modified node
    // Note: newCount was calculated before rebalancing. Rebalancing preserves total count.
    return RrbInternalNode<E>(height, newCount, newChildren, newSizeTable);
  } // End of removeAt

  // --- Rebalancing/Merging Helpers ---

  /// Result of a rebalancing/merging operation.
  /// Contains the potentially modified children list and size table.
  ({List<RrbNode<E>> children, List<int>? sizeTable}) _rebalanceOrMerge(
    int underfullSlotIndex,
    List<RrbNode<E>> currentChildren,
    List<int>? currentSizeTable,
  ) {
    const minSize = (kBranchingFactor + 1) ~/ 2; // Minimum size for a node

    // 1. Try borrowing from left sibling
    if (underfullSlotIndex > 0) {
      final leftSibling = currentChildren[underfullSlotIndex - 1];
      if (leftSibling.count > minSize) {
        // Left sibling can lend an element/node
        return _borrowFromLeft(
          underfullSlotIndex,
          currentChildren,
          currentSizeTable,
        );
      }
    }

    // 2. Try borrowing from right sibling
    if (underfullSlotIndex < currentChildren.length - 1) {
      final rightSibling = currentChildren[underfullSlotIndex + 1];
      if (rightSibling.count > minSize) {
        // Right sibling can lend an element/node
        return _borrowFromRight(
          underfullSlotIndex,
          currentChildren,
          currentSizeTable,
        );
      }
    }

    // 3. Try merging with left sibling
    if (underfullSlotIndex > 0) {
      // Merge underfull node with its left sibling
      return _mergeWithLeft(
        underfullSlotIndex,
        currentChildren,
        currentSizeTable,
      );
    }

    // 4. Try merging with right sibling
    // This case applies if the underfull node is the first child (index 0)
    // and couldn't borrow from the right sibling (index 1).
    if (underfullSlotIndex < currentChildren.length - 1) {
      // Merge underfull node (index 0) with its right sibling (index 1)
      // Note: The merge operation typically merges the *right* node into the *left*.
      // So we call mergeWithLeft on the *right* sibling's index.
      return _mergeWithLeft(
        underfullSlotIndex +
            1, // Index of the node to merge *into* (the right sibling)
        currentChildren,
        currentSizeTable,
      );
    }

    // Should not be reached if called correctly (an underfull node must have a sibling to merge with unless it's the root's only child, handled earlier)
    print(
      "WARNING: Rebalancing/merging failed unexpectedly at height $height, slot $underfullSlotIndex.",
    );
    return (children: currentChildren, sizeTable: currentSizeTable);
  }

  ({List<RrbNode<E>> children, List<int>? sizeTable}) _borrowFromLeft(
    int receiverIndex, // Index of the underfull node receiving the element
    List<RrbNode<E>> currentChildren,
    List<int>? currentSizeTable,
  ) {
    assert(receiverIndex > 0 && receiverIndex < currentChildren.length);

    final leftDonorNode = currentChildren[receiverIndex - 1];
    final receiverNode = currentChildren[receiverIndex];
    final newChildren = List<RrbNode<E>>.of(currentChildren);
    List<int>? newSizeTable =
        currentSizeTable != null ? List<int>.of(currentSizeTable) : null;

    if (leftDonorNode is RrbLeafNode<E> && receiverNode is RrbLeafNode<E>) {
      // --- Borrow from left leaf to right leaf ---
      final donorElements = leftDonorNode.elements;
      final elementToMove = donorElements.last;

      final newDonorElements = donorElements.sublist(
        0,
        donorElements.length - 1,
      );
      final newReceiverElements = [elementToMove, ...receiverNode.elements];

      final newDonorNode = RrbLeafNode<E>(newDonorElements);
      final newReceiverNode = RrbLeafNode<E>(newReceiverElements);

      newChildren[receiverIndex - 1] = newDonorNode;
      newChildren[receiverIndex] = newReceiverNode;

      if (newSizeTable != null) {
        // Pass the updated children list to the corrected helper
        _updateSizeTableAfterBorrow(
          receiverIndex - 1, // Start update from the left node index
          newChildren,
          newSizeTable,
        );
      }
    } else if (leftDonorNode is RrbInternalNode<E> &&
        receiverNode is RrbInternalNode<E>) {
      // --- Borrow from left internal to right internal ---
      assert(leftDonorNode.height == receiverNode.height);

      final donorChildren = leftDonorNode.children;
      final childNodeToMove = donorChildren.last; // Node to move

      final newDonorChildren = donorChildren.sublist(
        0,
        donorChildren.length - 1,
      );
      final newReceiverChildren = [childNodeToMove, ...receiverNode.children];

      // Create new nodes with updated children and counts
      final newDonorNode = RrbInternalNode<E>(
        leftDonorNode.height,
        leftDonorNode.count - childNodeToMove.count, // Update count
        newDonorChildren,
        _computeSizeTableIfNeeded(newDonorChildren), // Recalculate size table
      );
      final newReceiverNode = RrbInternalNode<E>(
        receiverNode.height,
        receiverNode.count + childNodeToMove.count, // Update count
        newReceiverChildren,
        _computeSizeTableIfNeeded(
          newReceiverChildren,
        ), // Recalculate size table
      );

      newChildren[receiverIndex - 1] = newDonorNode;
      newChildren[receiverIndex] = newReceiverNode;

      if (newSizeTable != null) {
        // Pass the updated children list to the corrected helper
        _updateSizeTableAfterBorrow(
          receiverIndex - 1, // Start update from the left node index
          newChildren,
          newSizeTable,
        );
      }
    } else {
      throw StateError(
        'Cannot borrow between nodes of different types (leaf/internal).',
      );
    }

    return (children: newChildren, sizeTable: newSizeTable);
  }

  ({List<RrbNode<E>> children, List<int>? sizeTable}) _borrowFromRight(
    int receiverIndex, // Index of the underfull node receiving the element
    List<RrbNode<E>> currentChildren,
    List<int>? currentSizeTable,
  ) {
    assert(receiverIndex >= 0 && receiverIndex < currentChildren.length - 1);

    final receiverNode = currentChildren[receiverIndex];
    final rightDonorNode = currentChildren[receiverIndex + 1];
    final newChildren = List<RrbNode<E>>.of(currentChildren);
    List<int>? newSizeTable =
        currentSizeTable != null ? List<int>.of(currentSizeTable) : null;

    if (receiverNode is RrbLeafNode<E> && rightDonorNode is RrbLeafNode<E>) {
      // --- Borrow from right leaf to left leaf ---
      final donorElements = rightDonorNode.elements;
      final elementToMove = donorElements.first;

      final newReceiverElements = [...receiverNode.elements, elementToMove];
      final newDonorElements = donorElements.sublist(
        1,
      ); // Elements after the first

      final newReceiverNode = RrbLeafNode<E>(newReceiverElements);
      final newDonorNode = RrbLeafNode<E>(newDonorElements);

      newChildren[receiverIndex] = newReceiverNode;
      newChildren[receiverIndex + 1] = newDonorNode;

      if (newSizeTable != null) {
        // Pass the updated children list to the corrected helper
        _updateSizeTableAfterBorrow(
          receiverIndex, // Start update from the left node index (the receiver)
          newChildren,
          newSizeTable,
        );
      }
    } else if (receiverNode is RrbInternalNode<E> &&
        rightDonorNode is RrbInternalNode<E>) {
      // --- Borrow from right internal to left internal ---
      assert(receiverNode.height == rightDonorNode.height);

      final donorChildren = rightDonorNode.children;
      final childNodeToMove = donorChildren.first; // Node to move

      final newReceiverChildren = [...receiverNode.children, childNodeToMove];
      final newDonorChildren = donorChildren.sublist(
        1,
      ); // Children after the first

      // Create new nodes with updated children and counts
      final newReceiverNode = RrbInternalNode<E>(
        receiverNode.height,
        receiverNode.count + childNodeToMove.count, // Update count
        newReceiverChildren,
        _computeSizeTableIfNeeded(
          newReceiverChildren,
        ), // Recalculate size table
      );
      final newDonorNode = RrbInternalNode<E>(
        rightDonorNode.height,
        rightDonorNode.count - childNodeToMove.count, // Update count
        newDonorChildren,
        _computeSizeTableIfNeeded(newDonorChildren), // Recalculate size table
      );

      newChildren[receiverIndex] = newReceiverNode;
      newChildren[receiverIndex + 1] = newDonorNode;

      if (newSizeTable != null) {
        // Pass the updated children list to the corrected helper
        _updateSizeTableAfterBorrow(
          receiverIndex, // Start update from the left node index (the receiver)
          newChildren,
          newSizeTable,
        );
      }
    } else {
      throw StateError(
        'Cannot borrow between nodes of different types (leaf/internal).',
      );
    }

    return (children: newChildren, sizeTable: newSizeTable);
  }

  ({List<RrbNode<E>> children, List<int>? sizeTable}) _mergeWithLeft(
    int
    rightNodeIndex, // Index of the right node (the one being merged *into* the left)
    List<RrbNode<E>> currentChildren,
    List<int>? currentSizeTable,
  ) {
    assert(rightNodeIndex > 0 && rightNodeIndex < currentChildren.length);

    final leftNode = currentChildren[rightNodeIndex - 1];
    final rightNode = currentChildren[rightNodeIndex];
    final newChildren = List<RrbNode<E>>.of(currentChildren);
    List<int>? newSizeTable =
        currentSizeTable != null ? List<int>.of(currentSizeTable) : null;

    if (leftNode is RrbLeafNode<E> && rightNode is RrbLeafNode<E>) {
      // --- Merge two leaf nodes ---
      final combinedElements = [...leftNode.elements, ...rightNode.elements];

      if (combinedElements.length <= kBranchingFactor) {
        // Merged node fits in a single leaf
        final mergedNode = RrbLeafNode<E>(combinedElements);
        newChildren[rightNodeIndex - 1] = mergedNode; // Replace left sibling
        newChildren.removeAt(rightNodeIndex); // Remove right node
        if (newSizeTable != null) {
          // Remove size entry for the removed right node
          newSizeTable.removeAt(rightNodeIndex);
          // Update size entry for the merged node (left sibling's original index)
          // and subsequent entries
          // Pass the updated children list and the already-shortened size table
          _updateSizeTableAfterMerge(
            rightNodeIndex - 1, // Index of the merged node
            newChildren,
            newSizeTable,
          );
        }
      } else {
        // Merged node needs to split into two leaves
        // This case implies the original nodes were likely near full, which contradicts
        // the merge condition (one node being underfull). However, handling defensively.
        // Split the combined elements (simple split for now)
        final splitPoint =
            (kBranchingFactor + 1) ~/ 2; // Or other split strategy
        final newLeftLeafElements = combinedElements.sublist(0, splitPoint);
        final newRightLeafElements = combinedElements.sublist(splitPoint);
        final newLeftLeaf = RrbLeafNode<E>(newLeftLeafElements);
        final newRightLeaf = RrbLeafNode<E>(newRightLeafElements);

        // Replace the original two nodes with the two new split nodes
        newChildren[rightNodeIndex - 1] = newLeftLeaf;
        newChildren[rightNodeIndex] =
            newRightLeaf; // Replace right node instead of removing

        if (newSizeTable != null) {
          // Update size table for both new nodes
          // Pass the updated children list. Size table length hasn't changed here (split case).
          _updateSizeTableAfterMerge(
            rightNodeIndex - 1, // Index of the first modified node
            newChildren,
            newSizeTable,
          );
        }
      }
    } else if (leftNode is RrbInternalNode<E> &&
        rightNode is RrbInternalNode<E>) {
      // --- Merge two internal nodes ---
      assert(
        leftNode.height == rightNode.height,
      ); // Must be same height to merge

      final combinedChildren = [...leftNode.children, ...rightNode.children];
      final combinedCount = leftNode.count + rightNode.count;

      if (combinedChildren.length <= kBranchingFactor) {
        // Merged children fit in a single internal node
        // Create the merged node. Size table needs recalculation.
        final mergedNode = RrbInternalNode<E>(
          leftNode.height,
          combinedCount,
          combinedChildren,
          _computeSizeTableIfNeeded(combinedChildren), // Recalculate size table
        );

        newChildren[rightNodeIndex - 1] = mergedNode; // Replace left sibling
        newChildren.removeAt(rightNodeIndex); // Remove right node
        if (newSizeTable != null) {
          newSizeTable.removeAt(rightNodeIndex);
          // Update size table from the merged node onwards
          // Pass the updated children list and the already-shortened size table
          _updateSizeTableAfterMerge(
            rightNodeIndex - 1, // Index of the merged node
            newChildren,
            newSizeTable,
          );
        }
      } else {
        // Merged children overflow, need to split into two internal nodes
        // Distribute combinedChildren across two new nodes (simple split)
        final splitPoint =
            (kBranchingFactor + 1) ~/ 2; // Or other split strategy
        final newLeftChildren = combinedChildren.sublist(0, splitPoint);
        final newRightChildren = combinedChildren.sublist(splitPoint);

        // Calculate counts for the new nodes
        int newLeftCount = 0;
        for (final child in newLeftChildren) {
          newLeftCount += child.count;
        }
        final newRightCount = combinedCount - newLeftCount;

        // Create the two new internal nodes
        final newLeftNode = RrbInternalNode<E>(
          leftNode.height,
          newLeftCount,
          newLeftChildren,
          _computeSizeTableIfNeeded(newLeftChildren),
        );
        final newRightNode = RrbInternalNode<E>(
          leftNode.height,
          newRightCount,
          newRightChildren,
          _computeSizeTableIfNeeded(newRightChildren),
        );

        // Replace the original two nodes with the two new split nodes
        newChildren[rightNodeIndex - 1] = newLeftNode;
        newChildren[rightNodeIndex] = newRightNode; // Replace right node

        if (newSizeTable != null) {
          // Update size table for both new nodes
          // Pass the updated children list. Size table length hasn't changed here (split case).
          _updateSizeTableAfterMerge(
            rightNodeIndex - 1, // Index of the first modified node
            newChildren,
            newSizeTable,
          );
        }
      }
    } else {
      // Merging leaf and internal node directly is not standard in RRB-Trees.
      // This suggests an issue with tree structure or invariants.
      throw StateError(
        'Cannot merge nodes of different types (leaf/internal) directly.',
      );
    }

    // Return the modified children list and size table
    return (children: newChildren, sizeTable: newSizeTable);
  }

  /// Helper to update the size table after a merge operation.
  /// Assumes the `newChildren` list has been updated *before* calling this.
  /// The `sizeTable` passed should also have had the merged node's entry removed already if the merge didn't split.
  void _updateSizeTableAfterMerge(
    int
    startIndex, // Index of the node that received the merge (the left node) or the first node after a split
    List<RrbNode<E>>
    newChildren, // The *updated* children list (after merge and potential split)
    List<int> sizeTable, // The size table being updated (potentially shortened)
  ) {
    // Recalculate sizes starting from the node that received the merge or the first split node.
    int cumulativeCount = (startIndex == 0) ? 0 : sizeTable[startIndex - 1];

    for (int i = startIndex; i < sizeTable.length; i++) {
      // Ensure we don't go out of bounds of the potentially modified children list
      if (i >= newChildren.length) break;
      cumulativeCount += newChildren[i].count;
      sizeTable[i] = cumulativeCount;
    }
    // If the merge resulted in a split, newChildren.length and sizeTable.length should match the state *before* the merge.
    // If the merge didn't split, newChildren is shorter, and sizeTable should also be shorter (entry removed before calling this).
  }

  /// Helper to update the size table after a borrow operation.
  /// Assumes the `newChildren` list contains the *updated* nodes before calling this.
  void _updateSizeTableAfterBorrow(
    int leftNodeIndex, // Index of the left node involved (donor or receiver)
    List<RrbNode<E>> newChildren, // The *updated* children list
    List<int> sizeTable, // The size table being updated
  ) {
    // Recalculate sizes starting from the left node involved in the borrow.
    int cumulativeCount =
        (leftNodeIndex == 0) ? 0 : sizeTable[leftNodeIndex - 1];

    for (int i = leftNodeIndex; i < sizeTable.length; i++) {
      // Ensure we don't go out of bounds if children list shrank (shouldn't happen in borrow)
      if (i >= newChildren.length) break;
      cumulativeCount += newChildren[i].count;
      sizeTable[i] = cumulativeCount;
    }
    // If the borrow caused the children list length to change (it shouldn't),
    // the sizeTable length might need adjustment, but borrow preserves length.
  }

  /// Computes a size table for a list of children for a node at `this.height`.
  /// Returns null if the node can remain strict (all children except potentially
  /// the last one are full for their height).
  List<int>? _computeSizeTableIfNeeded(List<RrbNode<E>> children) {
    if (children.isEmpty) return null; // Should not happen for internal nodes

    bool needsTable = false;
    // Expected size of children depends on the height *below* the current node.
    final int childHeight =
        height - 1; // Since this is called from RrbInternalNode
    final int expectedChildNodeSize =
        (childHeight == 0)
            ? kBranchingFactor // Expected size for leaf children
            : (1 <<
                (childHeight *
                    kLog2BranchingFactor)); // Expected size for internal children

    int cumulativeCount = 0;
    final calculatedSizeTable = List<int>.filled(children.length, 0);

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      // Ensure children are at the correct height (important invariant)
      assert(
        child.height == childHeight,
        'Child height mismatch: expected $childHeight, got ${child.height}',
      );

      cumulativeCount += child.count;
      calculatedSizeTable[i] = cumulativeCount;

      // Check if relaxation is needed: Any child *except the last* being non-full requires a table.
      if (i < children.length - 1) {
        if (child.count != expectedChildNodeSize) {
          needsTable = true;
          // Optimization: if we know we need a table, we don't need to keep checking.
          // However, we still need to finish calculating the cumulative counts.
        }
      }
    }

    return needsTable ? calculatedSizeTable : null;
  }

  @override
  RrbNode<E> insertAt(int index, E value) {
    assert(index >= 0 && index <= count); // Allow insertion at the end

    // --- Find the target child node ---
    final shift = height * kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (kBranchingFactor - 1);
    int slot = indexInNode; // Default for strict case
    int indexInChild = index & ((1 << shift) - 1); // Default for strict case

    if (isRelaxed) {
      // Find correct slot and index for relaxed node
      final sizes = sizeTable!;
      while (slot > 0 && sizes[slot - 1] > index) {
        slot--;
      }
      // Important: For insert, we might insert *at* the end of a child's range,
      // so we need <= comparison here, unlike get/update/removeAt.
      // Find the first slot whose cumulative size is >= index.
      while (slot < sizes.length && sizes[slot] < index) {
        slot++;
      }
      // If index is exactly the size of a child, it means insertion at the beginning of the next child,
      // but the recursive call handles index 0 correctly.
      // If index is equal to the total count, slot will be children.length, handled below.

      // Adjust indexInChild based on the found slot
      indexInChild = (slot == 0) ? index : index - sizes[slot - 1];
    }

    // --- Handle insertion at the very end (past the last child) ---
    // This happens if the calculated slot is equal to the number of children.
    // In this case, we effectively 'add' to the last child.
    if (slot == children.length) {
      // This logic is similar to 'add', but we need to handle the index correctly.
      // We insert into the *last* child at its end index.
      slot = children.length - 1;
      indexInChild =
          children[slot].count; // Insert at the end of the last child
    }

    // --- Recursively insert into the child ---
    final oldChild = children[slot];
    final newChildResult = oldChild.insertAt(indexInChild, value);

    if (identical(oldChild, newChildResult)) {
      return this; // Child didn't change (shouldn't happen on insert?)
    }

    // --- Handle result of child insertion ---
    final newChildren = List<RrbNode<E>>.of(children);
    final newCount = count + 1;

    if (newChildResult.height == oldChild.height) {
      // Child did NOT split, just update the child pointer and size table
      newChildren[slot] = newChildResult;
      List<int>? newSizeTable =
          sizeTable != null ? List<int>.of(sizeTable!) : null;
      if (newSizeTable != null) {
        // Update size table from the modified slot onwards
        int currentCumulative = (slot == 0) ? 0 : newSizeTable[slot - 1];
        for (int i = slot; i < newSizeTable.length; i++) {
          currentCumulative += newChildren[i].count;
          newSizeTable[i] = currentCumulative;
        }
      }
      // Recompute if needed, in case the update caused relaxation change
      final finalSizeTable =
          _computeSizeTableIfNeeded(newChildren) ?? newSizeTable;
      return RrbInternalNode<E>(height, newCount, newChildren, finalSizeTable);
    } else {
      // Child DID split (returned an internal node of same height as this one)
      assert(newChildResult is RrbInternalNode<E>);
      assert(newChildResult.height == height);
      final splitChild = newChildResult as RrbInternalNode<E>;
      assert(splitChild.children.length == 2); // Expecting split into two

      // Replace the original child with the left part of the split
      newChildren[slot] = splitChild.children[0];
      // Insert the right part of the split *after* the original slot
      newChildren.insert(slot + 1, splitChild.children[1]);

      if (newChildren.length <= kBranchingFactor) {
        // Current node has space for the new child from the split
        // Size table needs recalculation from the split point
        final newSizeTable = _computeSizeTableIfNeeded(newChildren);
        return RrbInternalNode<E>(height, newCount, newChildren, newSizeTable);
      } else {
        // Current node is full, need to split this node and create a new parent
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

        // Return a new parent node (height + 1) containing the two split nodes
        return RrbInternalNode<E>(
          height + 1,
          newCount,
          [newLeftNode, newRightNode],
          null, // New parent is initially strict
        );
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

  /// Array containing the elements stored in this leaf.
  /// Length should be between 1 and _kBranchingFactor.
  final List<E> elements;

  RrbLeafNode(this.elements)
    : assert(elements.isNotEmpty),
      assert(elements.length <= kBranchingFactor);

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
    if (elements.length < kBranchingFactor) {
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

  @override
  RrbNode<E> insertAt(int index, E value) {
    assert(index >= 0 && index <= count); // Allow insertion at the end

    if (elements.length < kBranchingFactor) {
      // Leaf has space, create new leaf with inserted element
      final newElements = List<E>.of(elements)..insert(index, value);
      return RrbLeafNode<E>(newElements);
    } else {
      // Leaf is full, need to split into two leaves and create a parent
      final tempElements = List<E>.of(elements)..insert(index, value);
      final splitPoint = (kBranchingFactor + 1) ~/ 2; // Split roughly in half

      final leftElements = tempElements.sublist(0, splitPoint);
      final rightElements = tempElements.sublist(splitPoint);

      final newLeftLeaf = RrbLeafNode<E>(leftElements);
      final newRightLeaf = RrbLeafNode<E>(rightElements);

      // New parent contains the two new leaves. Parent is strict.
      return RrbInternalNode<E>(
        1, // New parent height
        count + 1, // New total count
        [newLeftLeaf, newRightLeaf],
        null, // Strict node
      );
    }
  }
}

/// Represents the canonical empty RRB-Tree node.
class RrbEmptyNode<E> extends RrbNode<E> {
  /// Canonical const instance of the empty node.
  /// Use `Never` as the type argument for a type-agnostic empty node.
  static const RrbEmptyNode<Never> instance = RrbEmptyNode._();

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

  @override
  RrbNode<E> insertAt(int index, E value) {
    if (index != 0) {
      throw RangeError.index(
        index,
        this,
        'index',
        'Cannot insert at non-zero index in empty node',
        1,
      );
    }
    // Inserting into empty creates a new leaf node with the single element.
    return RrbLeafNode<E>([value]);
  }
}

// TODO: Implement factory constructors or static methods for creating nodes.
// TODO: Implement methods for node operations (get, update, insert, concat, etc.).
