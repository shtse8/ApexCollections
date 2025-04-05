/// Defines extension methods for 'add' operation helpers on [ChampSparseNode].
library;

import 'champ_sparse_node.dart';
import 'champ_array_node_base.dart'; // Import base for type
import 'champ_node_base.dart';
import 'champ_array_node_impl.dart'; // Import concrete implementation
import 'champ_utils.dart';
import 'champ_merging.dart';
import 'champ_sparse_node_mutation_utils.dart'; // For in-place mutation helpers
// Duplicate import removed by previous step, ensure comment reflects reality
import 'champ_sparse_node_immutable_utils.dart'; // For createImmutableNode, replaceDataWithNodeImmutable
import 'champ_sparse_node_immutable_utils.dart'; // For immutable helpers

extension ChampSparseNodeAddUtils<K, V> on ChampSparseNode<K, V> {
  // --- Transient Add Helpers (SparseNode) ---

  ChampAddResult<K, V> addTransientDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;
    final currentValue = children[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      children[payloadIndex + 1] = value; // Mutate in place
      return (node: this, didAdd: false);
    } else {
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hashOfKey(currentKey), // Use hash of existing key
        currentKey,
        currentValue,
        hash, // Hash of the new key
        key,
        value,
        owner,
      );
      // Use extension method for mutation
      replaceDataWithNodeInPlace(dataIndex, subNode, bitpos); // Mutate in place
      // Count doesn't change, but type might (Array->Sparse not possible here)
      return (node: this, didAdd: true);
    }
  }

  ChampAddResult<K, V> addTransientDelegate(
    K key,
    V value,
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
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (identical(addResult.node, subNode)) {
      return (node: this, didAdd: addResult.didAdd);
    }

    children[contentIdx] = addResult.node; // Update content in place
    // Count doesn't change relative to this node, no transition check needed
    return (node: this, didAdd: addResult.didAdd);
  }

  ChampAddResult<K, V> addTransientEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
    TransientOwner owner, // Added owner
  ) {
    assert(isTransient(owner)); // Use owner
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    // Use extension method for mutation
    insertDataEntryInPlace(dataIndex, key, value, bitpos); // Mutate in place

    // Check for transition Sparse -> Array
    if (childCount > kSparseNodeThreshold) {
      // Create ArrayNode, passing the current mutable children list and owner
      return (
        node: ChampArrayNodeImpl<K, V>(dataMap, nodeMap, children, owner),
        didAdd: true,
      );
    }
    // Remain SparseNode
    return (node: this, didAdd: true);
  }

  // --- Immutable Add Helpers (SparseNode) ---

  ChampAddResult<K, V> addImmutableDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;
    final currentValue = children[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      // Create new children list with updated value (Manual Copy Optimization)
      final len = children.length;
      final newChildren = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newChildren[i] = children[i];
      }
      newChildren[payloadIndex + 1] = value; // Update the specific value
      // Count doesn't change, stays SparseNode
      return (
        node: ChampSparseNode<K, V>(dataMap, nodeMap, newChildren),
        didAdd: false,
      );
    } else {
      // Hash collision, different keys -> create sub-node
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hashOfKey(currentKey), // Use hash of existing key
        currentKey,
        currentValue,
        hash, // Hash of the new key
        key,
        value,
        null, // Immutable merge
      );
      // Create new node replacing data with sub-node
      // Need access to _replaceDataWithNodeImmutable or similar logic
      // This logic needs to be part of the base or accessible here.
      // For now, assume _replaceDataWithNodeImmutable exists or is moved.
      // Let's call a placeholder - this needs fixing later.
      // Call the actual immutable helper from the utils extension
      final newNode = replaceDataWithNodeImmutable(dataIndex, subNode, bitpos);
      return (node: newNode, didAdd: true);
    }
  }

  ChampAddResult<K, V> addImmutableDelegate(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    // Calculate index from the end
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, children.length);
    final subNode = children[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      null,
    ); // Immutable add

    if (identical(addResult.node, subNode)) {
      return (node: this, didAdd: addResult.didAdd); // No change
    }

    // Create new children list with updated sub-node
    final newChildren = List<Object?>.of(children);
    newChildren[contentIdx] = addResult.node;
    // Count doesn't change, node type determined by _createImmutableNode
    // Need access to _createImmutableNode or similar logic.
    // Let's call a placeholder - this needs fixing later.
    return (
      node: createImmutableNode(
        dataMap,
        nodeMap,
        newChildren,
      ), // Use extension method
      didAdd: addResult.didAdd,
    );
  }

  ChampAddResult<K, V> addImmutableEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = dataIndex * 2;
    // Create new children list with inserted entry
    final newChildren = List<Object?>.of(children)
      ..insertAll(payloadIndex, [key, value]);
    final newDataMap = dataMap | bitpos;
    final newChildCount = childCount + 1; // Calculate new count

    // Check for transition Sparse -> Array
    if (newChildCount > kSparseNodeThreshold) {
      return (
        node: ChampArrayNodeImpl<K, V>(newDataMap, nodeMap, newChildren),
        didAdd: true,
      );
    } else {
      return (
        node: ChampSparseNode<K, V>(newDataMap, nodeMap, newChildren),
        didAdd: true,
      );
    }
  }

  // Placeholder helpers are no longer needed as we import and use the actual methods
  // from champ_sparse_node_immutable_utils.dart
}
