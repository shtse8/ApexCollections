/// Defines extension methods for 'remove' operation helpers and node shrinking/collapsing
/// logic on [ChampSparseNode].
library;

import 'champ_sparse_node.dart';
// Remove unused: import 'champ_array_node.dart'; // Now handled by immutable utils
import 'champ_node_base.dart';
import 'champ_utils.dart';
import 'champ_empty_node.dart';
import 'champ_data_node.dart';
import 'champ_sparse_node_mutation_utils.dart'; // For in-place mutation helpers
import 'champ_sparse_node_immutable_utils.dart'; // For createImmutableNode

extension ChampSparseNodeRemoveUtils<K, V> on ChampSparseNode<K, V> {
  // --- Transient Remove Helpers (SparseNode) ---

  ChampRemoveResult<K, V> removeTransientData(
    K key,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (children[payloadIndex] == key) {
      // Found the key to remove
      // Use extension method for mutation
      removeDataEntryInPlace(dataIndex, bitpos); // Mutate in place
      // Check if node needs shrinking/collapsing (Sparse version)
      final newNode = _shrinkIfNeeded(owner);
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> removeTransientDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    // Calculate index from the end
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, children.length);
    final subNode = children[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    // Sub-node changed, update content in place
    children[contentIdx] = removeResult.node;

    // Check if the sub-node became empty or needs merging
    if (removeResult.node.isEmptyNode) {
      // Use extension method for mutation
      removeNodeEntryInPlace(
        nodeIndex,
        bitpos,
      ); // Mutate in place (uses correct index)
      final newNode = _shrinkIfNeeded(owner); // Check for collapse
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // If sub-node collapsed to a data node, replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      // Use extension method for mutation
      replaceNodeWithDataInPlace(
        nodeIndex, // Pass the conceptual reversed index
        dataNode.dataKey,
        dataNode.dataValue,
        bitpos,
      ); // Mutate in place (uses correct index)
      // Shrinking check is not needed here as count remains the same
      return (node: this, didRemove: true);
    }
    // Sub-node modified but not removed/collapsed, return mutable node
    return (node: this, didRemove: true);
  }

  // --- Immutable Remove Helpers (SparseNode) ---

  ChampRemoveResult<K, V> removeImmutableData(K key, int frag, int bitpos) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (children[payloadIndex] == key) {
      // Found the key to remove
      final newDataMap = dataMap ^ bitpos;
      if (newDataMap == 0 && nodeMap == 0) {
        return (node: ChampEmptyNode<K, V>(), didRemove: true);
      }

      // Create new list with data entry removed
      final newChildren = List<Object?>.of(children)
        ..removeRange(payloadIndex, payloadIndex + 2);
      // Create new node (will be Sparse or simpler)
      final newNode = createImmutableNode(newDataMap, nodeMap, newChildren);
      return (node: newNode, didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> removeImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    // Calculate index from the end
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, children.length);
    final subNode = children[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      null,
    ); // Immutable remove

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    // Sub-node changed...
    if (removeResult.node.isEmptyNode) {
      // Remove the empty sub-node entry
      final newNodeMap = nodeMap ^ bitpos;
      if (dataMap == 0 && newNodeMap == 0) {
        return (node: ChampEmptyNode<K, V>(), didRemove: true);
      }
      // Create new list with node removed
      final newChildren = List<Object?>.of(children)..removeAt(contentIdx);
      // Create new node (may shrink/collapse)
      final newNode = createImmutableNode(
        dataMap,
        newNodeMap,
        newChildren,
      ); // Use extension method
      return (node: newNode, didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // Replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      final newDataMap = dataMap | bitpos;
      final newNodeMap = nodeMap ^ bitpos;
      final dataPayloadIndex = dataIndexFromFragment(frag, newDataMap) * 2;

      // Create new content list: copy old data, insert new data, copy remaining old nodes
      final dataCount = bitCount(dataMap); // Use old dataMap count
      final nodeCount = bitCount(nodeMap); // Use old nodeMap count
      final newDataCount = bitCount(newDataMap);
      final newNodeCount = bitCount(newNodeMap);
      final newChildrenList = List<Object?>.filled(
        newDataCount * 2 + newNodeCount,
        null,
      );

      // --- Copy elements into newChildrenList ---
      // Copy data entries before the insertion point
      if (dataPayloadIndex > 0) {
        newChildrenList.setRange(0, dataPayloadIndex, children, 0);
      }
      // Insert the new data entry
      newChildrenList[dataPayloadIndex] = dataNode.dataKey;
      newChildrenList[dataPayloadIndex + 1] = dataNode.dataValue;
      // Copy data entries after the insertion point
      final oldDataEnd = dataCount * 2;
      if (dataPayloadIndex < oldDataEnd) {
        newChildrenList.setRange(
          dataPayloadIndex + 2, // Start index in new list
          newDataCount * 2, // End index for data in new list
          children, // Source list
          dataPayloadIndex, // Start index in old list
        );
      }

      // Copy the remaining node entries (excluding the replaced one) into the end
      final newNodeDataEnd = newDataCount * 2;
      int targetIdx = newNodeDataEnd;
      for (int i = 0; i < nodeCount; i++) {
        if (i != nodeIndex) {
          // Skip the replaced node index (conceptual reversed index)
          // Calculate index from end for old list
          final oldContentIdx = contentIndexFromNodeIndex(i, children.length);
          newChildrenList[targetIdx++] = children[oldContentIdx];
        }
      }
      // --- End Copy ---

      // Create new node (may shrink/collapse)
      final newNode = createImmutableNode(
        newDataMap,
        newNodeMap,
        newChildrenList,
      ); // Use extension method
      return (node: newNode, didRemove: true);
    } else {
      // Sub-node modified but not removed/collapsed
      // Create new children list with updated sub-node
      final newChildren = List<Object?>.of(children);
      newChildren[contentIdx] = removeResult.node;
      // Create new node (type determined by helper)
      final newNode = createImmutableNode(
        dataMap,
        nodeMap,
        newChildren,
      ); // Use extension method
      return (node: newNode, didRemove: true);
    }
  }

  // --- Shrinking Helper ---

  /// Checks if the node needs shrinking/collapsing after a removal and performs it (in place).
  /// Returns the potentially new node (e.g., if collapsed).
  /// Assumes the node is transient and owned.
  ChampNode<K, V>? _shrinkIfNeeded(TransientOwner? owner) {
    assert(isTransient(owner));
    final currentChildCount = childCount;

    // Condition 1: Collapse to EmptyNode
    if (currentChildCount == 0) {
      assert(dataMap == 0 && nodeMap == 0);
      return ChampEmptyNode<K, V>();
    }

    // Condition 2: Collapse to DataNode
    if (currentChildCount == 1 && nodeMap == 0) {
      assert(bitCount(dataMap) == 1);
      final key = children[0] as K;
      final value = children[1] as V;
      return ChampDataNode<K, V>(
        hashOfKey(key),
        key,
        value,
      ); // Return immutable DataNode
    }

    // Condition 3: Collapse to single sub-node
    if (currentChildCount == 1 && dataMap == 0) {
      assert(bitCount(nodeMap) == 1);
      // The single node is at the end (index 0 from end)
      return children[0] as ChampNode<K, V>; // Return the sub-node
    }

    // No shrinking/collapsing needed, return this (mutable) SparseNode
    return this;
  }

  // _createImmutableNode is now in champ_sparse_node_immutable_utils.dart
}
