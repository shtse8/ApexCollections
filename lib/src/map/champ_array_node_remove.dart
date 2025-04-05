/// Defines the remove logic for [ChampArrayNode].
library;

import 'champ_array_node_base.dart';
import 'champ_array_node_impl.dart'; // Import the concrete implementation
import 'champ_array_node_mutation_utils.dart'; // Import mutation utils
import 'champ_node_base.dart';
import 'champ_utils.dart';
import 'champ_empty_node.dart';
import 'champ_data_node.dart';
import 'champ_sparse_node.dart'; // For transitions

extension ChampArrayNodeRemoveExtension<K, V> on ChampArrayNode<K, V> {
  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if (isTransient(owner)) {
      // --- Transient Path ---
      if ((dataMap & bitpos) != 0) {
        return _removeTransientData(key, frag, bitpos, owner!);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeTransientDelegate(key, hash, shift, frag, bitpos, owner!);
      }
      return (node: this, didRemove: false); // Key not found
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _removeImmutableData(key, frag, bitpos);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeImmutableDelegate(key, hash, shift, frag, bitpos);
      }
      return (node: this, didRemove: false); // Key not found
    }
  }

  // --- Transient Remove Helpers (ArrayNode) ---

  ChampRemoveResult<K, V> _removeTransientData(
    K key,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (content[payloadIndex] == key) {
      // Found the key to remove
      // Use the extension method for mutation
      ChampArrayNodeMutationUtilsExtension(
        this,
      )._removeDataEntryInPlace(dataIndex, bitpos); // Mutate in place
      // Check if node needs shrinking or transition Array -> Sparse
      final newNode = _shrinkOrTransitionIfNeeded(owner);
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> _removeTransientDelegate(
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    // Sub-node changed, update content in place
    content[contentIdx] = removeResult.node;

    // Check if the sub-node became empty or needs merging
    if (removeResult.node.isEmptyNode) {
      // Use the extension method for mutation
      ChampArrayNodeMutationUtilsExtension(this)._removeNodeEntryInPlace(
        nodeIndex,
        bitpos,
      ); // Mutate in place (uses correct index)
      final newNode = _shrinkOrTransitionIfNeeded(
        owner,
      ); // Check for collapse/transition
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // If sub-node collapsed to a data node, replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      // Use the extension method for mutation
      ChampArrayNodeMutationUtilsExtension(this)._replaceNodeWithDataInPlace(
        nodeIndex, // Pass the conceptual reversed index
        dataNode.dataKey,
        dataNode.dataValue,
        bitpos,
      ); // Mutate in place (uses correct index)
      // Check if node needs shrinking or transition Array -> Sparse
      final newNode = _shrinkOrTransitionIfNeeded(owner);
      return (
        node: newNode ?? this, // Return potentially transitioned node
        didRemove: true,
      );
    }
    // Sub-node modified but not removed/collapsed, return mutable node
    return (node: this, didRemove: true);
  }

  /// Checks if the node needs shrinking or transitioning after a removal and performs it (in place).
  /// Returns the potentially new node (e.g., if collapsed or transitioned).
  /// Assumes the node is transient and owned.
  ChampNode<K, V>? _shrinkOrTransitionIfNeeded(TransientOwner? owner) {
    assert(isTransient(owner)); // Should only be called transiently

    final currentChildCount = childCount;

    // Condition 1: Collapse to EmptyNode
    if (currentChildCount == 0) {
      assert(dataMap == 0 && nodeMap == 0);
      return ChampEmptyNode<K, V>();
    }

    // Condition 2: Collapse to DataNode
    if (currentChildCount == 1 && nodeMap == 0) {
      assert(bitCount(dataMap) == 1);
      final key = content[0] as K; // Use 'content'
      final value = content[1] as V; // Use 'content'
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
      return content[0]
          as ChampNode<K, V>; // Return the sub-node from 'content'
    }

    // Condition 4: Transition from ArrayNode to SparseNode
    if (currentChildCount <= kSparseNodeThreshold) {
      // Convert this ArrayNode content to a SparseNode
      return ChampSparseNode<K, V>(
        dataMap,
        nodeMap,
        content, // Pass the existing (mutable) list
        owner, // Keep the owner
      );
    }

    // No shrinking or transition needed, return this (mutable) ArrayNode
    return this;
  }

  // --- Immutable Remove Helpers (ArrayNode) ---

  ChampRemoveResult<K, V> _removeImmutableData(K key, int frag, int bitpos) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (content[payloadIndex] == key) {
      // Found the key to remove
      final newDataMap = dataMap ^ bitpos;
      if (newDataMap == 0 && nodeMap == 0)
        return (node: ChampEmptyNode<K, V>(), didRemove: true);

      // Create new list with data entry removed
      final newContent = List<Object?>.of(content)
        ..removeRange(payloadIndex, payloadIndex + 2);
      // Check for immutable shrink / transition
      // Use the helper from the base class
      final newNode = createImmutableNode(
        newDataMap,
        nodeMap,
        newContent,
      ); // Call public extension method
      return (node: newNode, didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> _removeImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    // Calculate index from the end
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;
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
      final newContent = List<Object?>.of(content)..removeAt(contentIdx);
      // Create new node (may shrink/collapse/transition)
      // Use the helper from the base class
      final newNode = createImmutableNode(
        dataMap,
        newNodeMap,
        newContent,
      ); // Call public extension method
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
        newChildrenList.setRange(0, dataPayloadIndex, content, 0);
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
          content, // Source list
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
          final oldContentIdx = contentIndexFromNodeIndex(i, content.length);
          newChildrenList[targetIdx++] = content[oldContentIdx];
        }
      }
      // --- End Copy ---

      // Create new node (may shrink/collapse/transition)
      // Use the helper from the base class
      final newNode = createImmutableNode(
        // Call public extension method
        newDataMap,
        newNodeMap,
        newChildrenList,
      );
      return (node: newNode, didRemove: true);
    } else {
      // Sub-node modified but not removed/collapsed
      // Create new children list with updated sub-node
      final newContent = List<Object?>.of(content);
      newContent[contentIdx] = removeResult.node;
      // Create new node (type determined by helper in base class)
      final newNode = publicCreateImmutableNode( // Call public helper
        dataMap,
        nodeMap,
        newContent,
      );
      return (node: newNode, didRemove: true);
    }
}
}
}
