// Utility functions for operating on RRB-Tree nodes.
// Extracted from ApexListImpl to improve separation of concerns.

import 'dart:math'; // For clamp

// Import the split node files with the same prefix 'rrb'
import 'rrb_node_base.dart' as rrb;
import 'rrb_leaf_node.dart' as rrb;
import 'rrb_internal_node.dart' as rrb;

/// Computes a size table for a list of children nodes at a given height,
/// returning null if the resulting parent node would be strict (i.e., does not
/// require relaxation).
///
/// A node needs relaxation (and thus a size table) if any of its children
/// (except the last one) are not "full" for their height, or if children
/// have inconsistent heights (which shouldn't happen in a balanced tree but
/// is checked for robustness).
/// - [childrenInput]: The list containing the children nodes.
/// - [start]: The starting index (inclusive) of the relevant children in [childrenInput].
/// - [end]: The ending index (exclusive) of the relevant children in [childrenInput].
/// - [parentHeight]: The height of the parent node being constructed.
List<int>? computeSizeTableIfNeeded<E>(
  List<rrb.RrbNode<E>> childrenInput,
  int start,
  int end,
  int parentHeight,
) {
  final numChildren = end - start;
  if (numChildren <= 0) return null;

  bool needsTable = false;
  final int childHeight = parentHeight - 1;
  // Allow check even if childHeight is -1 (for leaves becoming internal)
  // Check based on the relevant range of children
  if (childHeight < 0 &&
      childrenInput.getRange(start, end).any((c) => c is! rrb.RrbLeafNode)) {
    return null; // Should not happen with leaves
  }
  if (childHeight < 0)
    return null; // All children must be leaves if height is 1

  final int expectedChildNodeSize =
      (childHeight == 0)
          ? rrb.kBranchingFactor
          : (1 << (childHeight * rrb.kLog2BranchingFactor));

  int cumulativeCount = 0;
  final calculatedSizeTable = List<int>.filled(numChildren, 0);

  // Iterate only over the relevant range
  for (int i = 0; i < numChildren; i++) {
    final child = childrenInput[start + i];
    // Check height consistency
    if (child.height != childHeight) {
      // If heights mismatch, force relaxation and stop checking fullness
      needsTable = true;
    }
    cumulativeCount += child.count;
    calculatedSizeTable[i] = cumulativeCount;
    // Only check fullness if heights are consistent so far
    // and not the last child in the range
    if (!needsTable &&
        i < numChildren - 1 &&
        child.count != expectedChildNodeSize) {
      needsTable = true;
    }
  }
  // Return table if needed due to fullness or height mismatch
  return needsTable ? calculatedSizeTable : null;
}

/// Helper to perform efficient slicing on an RRB-Tree node.
///
/// Recursively traverses the tree, selecting and potentially slicing child
/// nodes that fall within the requested range [`start`, `end`). Returns a new
/// root node for the resulting slice, or `null` if the slice is empty.
/// Complexity: O(log N) where N is the number of elements in the original node.
rrb.RrbNode<E>? sliceTree<E>(
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
    final slicedElements = node.elements.sublist(effectiveStart, effectiveEnd);
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
        final slicedChild = sliceTree<E>(child, childSliceStart, childSliceEnd);

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
    // Pass full list and range [0, length)
    final newParentSizeTable = computeSizeTableIfNeeded<E>(
      resultChildren,
      0,
      resultChildren.length,
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

/// Helper to concatenate two RRB-Trees represented by their roots.
/// Handles height differences and delegates to node-level concatenation.
/// Complexity: O(log N) where N is the size of the larger tree.
rrb.RrbNode<E> concatenateTrees<E>(
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
    final concatenationResult = concatenateNodes<E>(leftRoot, rightRoot);
    if (concatenationResult.length == 1) {
      // Merged into a single node
      return concatenationResult[0];
    } else {
      // Could not merge directly, create a new parent
      final newHeight = leftHeight + 1;
      // Need to compute size table for the new parent if needed
      // Pass full list and range [0, length)
      final newSizeTable = computeSizeTableIfNeeded<E>(
        concatenationResult,
        0,
        concatenationResult.length,
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
    final concatenationResult = concatenateNodes<E>(nodeToConcat, rightRoot);

    // Rebuild path upwards
    return rebuildConcatenatedPath<E>(
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
    final concatenationResult = concatenateNodes<E>(leftRoot, nodeToConcat);

    // Rebuild path upwards (using reversed logic)
    return rebuildConcatenatedPathReversed<E>(
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
List<rrb.RrbNode<E>> concatenateNodes<E>(
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
    final combinedChildrenCount = node1.children.length + node2.children.length;
    if (combinedChildrenCount <= rrb.kBranchingFactor) {
      // Merge children into a single internal node
      final mergedChildren = [...node1.children, ...node2.children];
      // Use parent height (height + 1) to check relaxation needs for the *new* node
      // Pass full list and range [0, length)
      final mergedSizeTable = computeSizeTableIfNeeded<E>(
        mergedChildren,
        0,
        mergedChildren.length,
        height + 1, // Parent height for the new merged node
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
rrb.RrbNode<E> rebuildConcatenatedPath<E>(
  int totalCount,
  List<rrb.RrbInternalNode<E>> path, // Path from root to parent-of-merge-parent
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
      // Pass full list and range [0, length)
      final sizeTable = computeSizeTableIfNeeded<E>(
        children,
        0,
        children.length,
        currentHeight,
      );
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

      // Pass full list and range [0, length)
      final leftSizeTable = computeSizeTableIfNeeded<E>(
        leftChildren,
        0,
        leftChildren.length,
        currentHeight,
      );
      // Pass full list and range [0, length)
      final rightSizeTable = computeSizeTableIfNeeded<E>(
        rightChildren,
        0,
        rightChildren.length,
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
        // Pass full list and range [0, length)
        final rootSizeTable = computeSizeTableIfNeeded<E>(
          currentLevelNodes,
          0,
          currentLevelNodes.length,
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
rrb.RrbNode<E> rebuildConcatenatedPathReversed<E>(
  int totalCount,
  List<rrb.RrbInternalNode<E>> path, // Path from root to parent-of-merge-parent
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
      // Pass full list and range [0, length)
      final sizeTable = computeSizeTableIfNeeded<E>(
        children,
        0,
        children.length,
        currentHeight,
      );
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

      // Pass full list and range [0, length)
      final leftSizeTable = computeSizeTableIfNeeded<E>(
        leftChildren,
        0,
        leftChildren.length,
        currentHeight,
      );
      // Pass full list and range [0, length)
      final rightSizeTable = computeSizeTableIfNeeded<E>(
        rightChildren,
        0,
        rightChildren.length,
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
        // Pass full list and range [0, length)
        final rootSizeTable = computeSizeTableIfNeeded<E>(
          currentLevelNodes,
          0,
          currentLevelNodes.length,
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

/// Recursive helper to fill a list buffer from tree nodes.
/// Returns the number of elements added from this node.
int fillListFromNode<E>(rrb.RrbNode<E> node, List<E> buffer, int bufferOffset) {
  if (node is rrb.RrbLeafNode<E>) {
    final elements = node.elements;
    final nodeLength = elements.length;
    // Efficiently copy elements using setRange
    buffer.setRange(bufferOffset, bufferOffset + nodeLength, elements);
    return nodeLength;
  } else if (node is rrb.RrbInternalNode<E>) {
    int elementsAdded = 0;
    for (final child in node.children) {
      elementsAdded += fillListFromNode(
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
