/// Defines the add logic for [ChampArrayNode].
library;

import 'champ_array_node_base.dart';
import 'champ_array_node_impl.dart'; // Import the concrete implementation
import 'champ_array_node_mutation_utils.dart'; // Import mutation utils
// Removed: import 'champ_array_node_immutable_utils.dart';
import 'champ_node_base.dart';
import 'champ_utils.dart';
import 'champ_merging.dart'; // For mergeDataEntries
import 'champ_empty_node.dart'; // Import needed node types
import 'champ_data_node.dart';
import 'champ_sparse_node.dart';

extension ChampArrayNodeAddExtension<K, V> on ChampArrayNode<K, V> {
  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if (isTransient(owner)) {
      // --- Transient Path ---
      if ((dataMap & bitpos) != 0) {
        return _addTransientDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _addTransientDelegate(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else {
        // Pass owner to transient empty slot add
        return _addTransientEmptySlot(key, value, frag, bitpos, owner!);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _addImmutableDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _addImmutableDelegate(key, value, hash, shift, frag, bitpos);
      } else {
        return _addImmutableEmptySlot(key, value, frag, bitpos);
      }
    }
  }

  // --- Transient Add Helpers (ArrayNode) ---
  ChampAddResult<K, V> _addTransientDataCollision(
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
    final currentKey = content[payloadIndex] as K;
    final currentValue = content[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      content[payloadIndex + 1] = value; // Mutate in place
      return (node: this, didAdd: false);
    } else {
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hash, // Use existing hash for currentKey
        currentKey,
        currentValue,
        hash, // Hash of the new key
        key,
        value,
        owner,
      );
      // Use the extension method for mutation
      ChampArrayNodeMutationUtilsExtension(this)._replaceDataWithNodeInPlace(
        dataIndex,
        subNode,
        bitpos,
      ); // Mutate in place
      return (node: this, didAdd: true);
    }
  }

  ChampAddResult<K, V> _addTransientDelegate(
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;
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

    content[contentIdx] = addResult.node; // Update content in place
    // Count doesn't change relative to this node, no transition check needed
    return (node: this, didAdd: addResult.didAdd);
  }

  ChampAddResult<K, V> _addTransientEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
    TransientOwner owner, // Added owner
  ) {
    assert(isTransient(owner)); // Use owner
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    // Use the extension method for mutation
    ChampArrayNodeMutationUtilsExtension(
      this,
    )._insertDataEntryInPlace(dataIndex, key, value, bitpos); // Mutate in place
    // ArrayNode never transitions back to Sparse on add
    return (node: this, didAdd: true);
  }

  // --- Immutable Add Helpers (ArrayNode) ---

  ChampAddResult<K, V> _addImmutableDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;
    final currentValue = content[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      // Create new content list with updated value (Manual Copy Optimization)
      final len = content.length;
      final newContent = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newContent[i] = content[i];
      }
      newContent[payloadIndex + 1] = value; // Update the specific value
      return (
        // Use ChampArrayNodeImpl constructor
        node: ChampArrayNodeImpl<K, V>(dataMap, nodeMap, newContent),
        didAdd: false,
      );
    } else {
      // Hash collision, different keys -> create sub-node
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hash, // Use existing hash for currentKey
        currentKey,
        currentValue,
        hash, // Hash of the new key
        key,
        value,
        null, // Immutable merge
      );
      // Create new node replacing data with sub-node
      // Call the method now located in the base class instance ('this')
      final newNode = _replaceDataWithNodeImmutable(dataIndex, subNode, bitpos);
      return (node: newNode, didAdd: true);
    }
  }

  ChampAddResult<K, V> _addImmutableDelegate(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    // Calculate index from the end
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;
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

    // Create new content list with updated sub-node
    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = addResult.node;
    // Create new node (type determined by helper in base class)
    final newNode = publicCreateImmutableNode(
      // Call public helper
      dataMap,
      nodeMap,
      newContent,
    );
    return (node: newNode, didAdd: addResult.didAdd);
  }

  ChampAddResult<K, V> _addImmutableEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = dataIndex * 2;
    // Create new content list with inserted entry
    final newContent = List<Object?>.of(content)
      ..insertAll(payloadIndex, [key, value]);
    final newDataMap = dataMap | bitpos;
    // Create new node (will remain ArrayNode as count increases)
    // Use the helper from the base class
    final newNode = publicCreateImmutableNode(
      // Call public helper
      newDataMap,
      nodeMap,
      newContent,
    );
    return (node: newNode, didAdd: true);
  }
}
