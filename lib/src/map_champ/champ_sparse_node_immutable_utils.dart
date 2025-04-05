/// Defines utility extension methods for creating and modifying immutable [ChampSparseNode] instances.
library;

import 'champ_sparse_node.dart';
import 'champ_array_node_base.dart'; // Import base for type
import 'champ_node_base.dart';
import 'champ_array_node_impl.dart'; // Import concrete implementation
import 'champ_utils.dart';
import 'champ_empty_node.dart';
import 'champ_data_node.dart';

extension ChampSparseNodeImmutableUtils<K, V> on ChampSparseNode<K, V> {
  /// Helper to create the correct immutable node type (Sparse, Array, Data, Empty)
  /// based on the final child count after an immutable operation.
  /// Assumes the caller has already calculated the final bitmaps and content.
  ChampNode<K, V> createImmutableNode(
    int newDataMap,
    int newNodeMap,
    List<Object?> newContent,
  ) {
    final childCount = bitCount(newDataMap) + bitCount(newNodeMap);

    if (childCount == 0) return ChampEmptyNode<K, V>();

    if (childCount == 1) {
      if (bitCount(newDataMap) == 1) {
        // Collapse to DataNode
        final key = newContent[0] as K;
        final value = newContent[1] as V;
        return ChampDataNode<K, V>(hashOfKey(key), key, value);
      } else {
        // Collapse to single sub-node (return the sub-node directly)
        // The single node is at the end (index 0 from end)
        return newContent[0] as ChampNode<K, V>;
      }
    }

    // Check threshold *before* creating node
    if (childCount <= kSparseNodeThreshold) {
      // Stay or become SparseNode
      return ChampSparseNode<K, V>(newDataMap, newNodeMap, newContent);
    } else {
      // Transition to ArrayNode
      return ChampArrayNodeImpl<K, V>(newDataMap, newNodeMap, newContent);
    }
  }

  /// Creates a new node replacing a data entry with a sub-node immutably.
  /// Handles potential transition to ArrayNode.
  ChampNode<K, V> replaceDataWithNodeImmutable(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    final dataPayloadIndex = dataIndex * 2;
    final dataCount = bitCount(dataMap);
    final nodeCount = bitCount(nodeMap);
    final newDataCount = dataCount - 1;
    final newNodeCount = nodeCount + 1;

    // Create the new children list
    final newChildren = List<Object?>.filled(
      newDataCount * 2 + newNodeCount, // Correct size calculation
      null,
      growable: false,
    );

    // --- Copy elements into newChildren ---
    // Copy data entries (excluding the one being replaced)
    if (dataIndex > 0) {
      newChildren.setRange(0, dataPayloadIndex, children, 0);
    }
    if (dataIndex < dataCount - 1) {
      newChildren.setRange(
        dataPayloadIndex, // Start index in new list
        newDataCount * 2, // End index for data in new list
        children, // Source list
        dataPayloadIndex + 2, // Start index in old list (skip replaced)
      );
    }

    // Calculate insertion position for the new subNode (index from the end)
    final frag = bitCount(bitpos - 1);
    final targetNodeMap = nodeMap | bitpos;
    final targetNodeIndexRev = nodeIndexFromFragment(frag, targetNodeMap);
    final nodeInsertPos = newChildren.length - 1 - targetNodeIndexRev;

    // Copy existing nodes into the end of the new list, leaving space for the new node
    final oldNodeStartIndex =
        dataCount * 2; // Start of nodes in old list (original order)
    final newNodeDataEnd = newDataCount * 2; // End of data in new list

    // Copy nodes that come *after* the new node in the reversed order
    // (These correspond to indices *smaller* than targetNodeIndexRev in the conceptual reversed array)
    // In the original list, these are the first targetNodeIndexRev nodes.
    if (targetNodeIndexRev > 0) {
      newChildren.setRange(
        newNodeDataEnd, // Start writing nodes after data in new list
        nodeInsertPos, // Write up to the insertion point
        children.getRange(
          oldNodeStartIndex,
          oldNodeStartIndex + targetNodeIndexRev,
        ), // Get the correct range from old list
      );
    }
    // Copy nodes that come *before* the new node in the reversed order
    // (These correspond to indices *greater than or equal to* targetNodeIndexRev in the conceptual reversed array)
    // In the original list, these are the nodes from targetNodeIndexRev onwards.
    if (targetNodeIndexRev < nodeCount) {
      newChildren.setRange(
        nodeInsertPos + 1, // Start writing after the inserted node
        newChildren.length, // Write to the end
        children.getRange(
          oldNodeStartIndex + targetNodeIndexRev,
          oldNodeStartIndex + nodeCount,
        ), // Get the correct range from old list
      );
    }

    // Insert the new subNode at the calculated position
    newChildren[nodeInsertPos] = subNode;
    // --- End Copy ---

    final newDataMap = dataMap ^ bitpos; // Remove data bit
    final newNodeMap = nodeMap | bitpos; // Add node bit

    // Decide node type based on the *new* count using the other helper method
    return createImmutableNode(newDataMap, newNodeMap, newChildren);
  }
}
