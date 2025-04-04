/// Defines extension methods for 'update' operation helpers on [ChampSparseNode].
library;

import 'champ_sparse_node.dart';
import 'champ_array_node.dart';
import 'champ_node_base.dart';
import 'champ_utils.dart';
import 'champ_merging.dart';
import 'champ_sparse_node_mutation_utils.dart'; // For in-place mutation helpers
// Import immutable utils for access to createImmutableNode and replaceDataWithNodeImmutable
import 'champ_sparse_node_immutable_utils.dart'; // For createImmutableNode, replaceDataWithNodeImmutable

extension ChampSparseNodeUpdateUtils<K, V> on ChampSparseNode<K, V> {
  // --- Transient Update Helpers (SparseNode) ---

  ChampUpdateResult<K, V> updateTransientData(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value in place
      final currentValue = children[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue)) {
        return (node: this, sizeChanged: false);
      }
      children[payloadIndex + 1] = updatedValue; // Mutate value in place
      return (node: this, sizeChanged: false);
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = children[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hashOfKey(currentKey), // Use hash of existing key
          currentKey,
          currentVal,
          hash, // Hash of the new key
          key,
          newValue,
          owner,
        );
        // Use extension method for mutation
        replaceDataWithNodeInPlace(
          dataIndex,
          subNode,
          bitpos,
        ); // Mutate in place
        // Count doesn't change, but type might (Array->Sparse not possible here)
        return (node: this, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> updateTransientDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    // Calculate index from the end
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, children.length);
    final subNode = children[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: owner,
    );

    if (identical(updateResult.node, subNode)) {
      return (node: this, sizeChanged: updateResult.sizeChanged);
    }

    // Update children array in place
    children[contentIdx] = updateResult.node;
    // Count doesn't change relative to this node, no transition check needed
    return (node: this, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> updateTransientEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
    TransientOwner owner, // Added owner
  ) {
    assert(isTransient(owner)); // Use owner
    if (ifAbsentFn != null) {
      // Insert new data entry using ifAbsentFn (in place)
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      // Use extension method for mutation
      insertDataEntryInPlace(
        dataIndex,
        key,
        newValue,
        bitpos,
      ); // Mutate in place

      // Check for transition Sparse -> Array
      if (childCount > kSparseNodeThreshold) {
        // Create ArrayNode, passing the current mutable children list and owner
        return (
          node: ChampArrayNode<K, V>(dataMap, nodeMap, children, owner),
          sizeChanged: true,
        );
      }
      // Remain SparseNode
      return (node: this, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // --- Immutable Update Helpers (SparseNode) ---

  ChampUpdateResult<K, V> updateImmutableData(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value
      final currentValue = children[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue)) {
        return (node: this, sizeChanged: false);
      }
      // Create new node with updated value (Manual Copy Optimization)
      final len = children.length;
      final newChildren = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newChildren[i] = children[i];
      }
      newChildren[payloadIndex + 1] = updatedValue; // Update the specific value
      // Count doesn't change, stays SparseNode
      return (
        node: ChampSparseNode<K, V>(dataMap, nodeMap, newChildren),
        sizeChanged: false,
      );
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = children[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hashOfKey(currentKey), // Use hash of existing key
          currentKey,
          currentVal,
          hash, // Hash of the new key
          key,
          newValue,
          null, // Immutable merge
        );
        // Create new node replacing data with sub-node
        final newNode = replaceDataWithNodeImmutable(
          dataIndex,
          subNode,
          bitpos,
        ); // Use extension method
        return (node: newNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> updateImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    // Calculate index from the end
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, children.length);
    final subNode = children[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: null,
    );

    if (identical(updateResult.node, subNode)) {
      return (node: this, sizeChanged: updateResult.sizeChanged);
    }

    // Create new node with updated sub-node
    final newChildren = List<Object?>.of(children);
    newChildren[contentIdx] = updateResult.node;
    // Create new node (type determined by helper)
    final newNode = createImmutableNode(
      dataMap,
      nodeMap,
      newChildren,
    ); // Use extension method
    return (node: newNode, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> updateImmutableEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
  ) {
    if (ifAbsentFn != null) {
      // Insert new data entry using ifAbsentFn
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final payloadIndex = dataIndex * 2;
      // Create new children list with inserted entry
      final newChildren = List<Object?>.of(children)
        ..insertAll(payloadIndex, [key, newValue]);
      final newDataMap = dataMap | bitpos;
      final newChildCount = childCount + 1; // Calculate new count

      // Check for transition Sparse -> Array
      if (newChildCount > kSparseNodeThreshold) {
        return (
          node: ChampArrayNode<K, V>(newDataMap, nodeMap, newChildren),
          sizeChanged: true,
        );
      } else {
        return (
          node: ChampSparseNode<K, V>(newDataMap, nodeMap, newChildren),
          sizeChanged: true,
        );
      }
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // Placeholder helpers are no longer needed as we import and use the actual methods
  // from champ_sparse_node_immutable_utils.dart
}
