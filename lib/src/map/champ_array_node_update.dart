/// Defines the update logic for [ChampArrayNode].
library;

import 'champ_array_node_base.dart';
import 'champ_array_node_impl.dart'; // Import the concrete implementation
import 'champ_array_node_mutation_utils.dart'; // Import mutation utils
import 'champ_node_base.dart';
import 'champ_utils.dart';
import 'champ_merging.dart'; // For mergeDataEntries

extension ChampArrayNodeUpdateExtension<K, V> on ChampArrayNode<K, V> {
  @override
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if (isTransient(owner)) {
      // --- Transient Path ---
      if ((dataMap & bitpos) != 0) {
        return _updateTransientData(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
          owner!,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _updateTransientDelegate(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
          owner!,
        );
      } else {
        // Pass owner to transient empty slot update
        return _updateTransientEmptySlot(key, frag, bitpos, ifAbsentFn, owner!);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _updateImmutableData(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _updateImmutableDelegate(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else {
        return _updateImmutableEmptySlot(key, frag, bitpos, ifAbsentFn);
      }
    }
  }

  // --- Transient Update Helpers (ArrayNode) ---

  ChampUpdateResult<K, V> _updateTransientData(
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
    final currentKey = content[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value in place
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      content[payloadIndex + 1] = updatedValue; // Mutate value in place
      return (node: this, sizeChanged: false);
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = content[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hash, // Use existing hash for currentKey
          currentKey,
          currentVal,
          hash, // Hash of the new key
          key,
          newValue,
          owner,
        );
        // Use the extension method for mutation
        ChampArrayNodeMutationUtilsExtension(this)._replaceDataWithNodeInPlace(
          dataIndex,
          subNode,
          bitpos,
        ); // Mutate in place
        return (node: this, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> _updateTransientDelegate(
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;

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

    // Update content array in place
    content[contentIdx] = updateResult.node;
    // Count doesn't change relative to this node, no transition check needed
    return (node: this, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> _updateTransientEmptySlot(
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
      // Use the extension method for mutation
      ChampArrayNodeMutationUtilsExtension(
        this,
      )._insertDataEntryInPlace(dataIndex, key, newValue, bitpos);
      // ArrayNode never transitions back to Sparse on add/update
      return (node: this, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // --- Immutable Update Helpers (ArrayNode) ---

  ChampUpdateResult<K, V> _updateImmutableData(
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
    final currentKey = content[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      // Create new node with updated value (Manual Copy Optimization)
      final len = content.length;
      final newContent = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newContent[i] = content[i];
      }
      newContent[payloadIndex + 1] = updatedValue; // Update the specific value
      // Count doesn't change, stays ArrayNode
      return (
        // Use ChampArrayNodeImpl constructor
        node: ChampArrayNodeImpl<K, V>(dataMap, nodeMap, newContent),
        sizeChanged: false,
      );
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = content[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hash, // Use existing hash for currentKey
          currentKey,
          currentVal,
          hash, // Hash of the new key
          key,
          newValue,
          null, // Immutable merge
        );
        // Create new node replacing data with sub-node
        // Call the method now located in the base class instance ('this')
        final newNode = _replaceDataWithNodeImmutable(
          // Call method moved back to base
          dataIndex,
          subNode,
          bitpos,
        );
        return (node: newNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> _updateImmutableDelegate(
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;

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
    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = updateResult.node;
    // Create new node (type determined by helper in base class)
    final newNode = publicCreateImmutableNode(
      dataMap,
      nodeMap,
      newContent,
    ); // Call public helper
    return (node: newNode, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> _updateImmutableEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
  ) {
    if (ifAbsentFn != null) {
      // Insert new data entry using ifAbsentFn
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final newContent = List<Object?>.of(content)
        ..insertAll(dataIndex * 2, [key, newValue]);
      // Create new node (will remain ArrayNode)
      final newNode = publicCreateImmutableNode(
        // Call public helper
        dataMap | bitpos,
        nodeMap,
        newContent,
      );
      return (node: newNode, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }
}
