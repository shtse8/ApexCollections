/// Defines the concrete implementation [ChampArrayNodeImpl] extending [ChampArrayNode].
library;

import 'champ_array_node_base.dart';
import 'champ_node_base.dart'; // For result types
import 'champ_utils.dart'; // Import TransientOwner
// Removed imports for deleted extension files
import 'champ_merging.dart';
import 'champ_array_node_mutation_utils.dart';
import 'champ_empty_node.dart';
import 'champ_sparse_node.dart';
import 'champ_data_node.dart'; // Import ChampDataNode

/// Concrete implementation of ChampArrayNode.
class ChampArrayNodeImpl<K, V> extends ChampArrayNode<K, V> {
  /// Creates a concrete ArrayNode instance.
  ChampArrayNodeImpl(
    int dataMap,
    int nodeMap,
    List<Object?> content, [
    TransientOwner? owner,
  ]) : super(dataMap, nodeMap, content, owner);

  // --- Method Implementations (Moved from Extensions) ---

  // From champ_array_node_get.dart
  @override
  V? get(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final payloadIndex = contentIndexFromDataIndex(dataIndex);
      if (content[payloadIndex] == key) {
        return content[payloadIndex + 1] as V;
      }
      return null;
    } else if ((nodeMap & bitpos) != 0) {
      final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
      final subNode = content[contentIdx] as ChampNode<K, V>;
      return subNode.get(key, hash, shift + kBitPartitionSize);
    }
    return null;
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final payloadIndex = contentIndexFromDataIndex(dataIndex);
      return content[payloadIndex] == key;
    } else if ((nodeMap & bitpos) != 0) {
      final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
      final subNode = content[contentIdx] as ChampNode<K, V>;
      return subNode.containsKey(key, hash, shift + kBitPartitionSize);
    }
    return false;
  }

  // From champ_array_node_add.dart
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
      final subNode = mergeDataEntries<K, V>(
        // Call function directly
        shift + kBitPartitionSize,
        hash, // Use existing hash for currentKey
        currentKey,
        currentValue,
        hash, // Hash of the new key
        key,
        value,
        owner,
      );
      replaceDataWithNodeInPlace(
        dataIndex,
        subNode,
        bitpos,
      ); // Call function directly
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
    return (node: this, didAdd: addResult.didAdd);
  }

  ChampAddResult<K, V> _addTransientEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    insertDataEntryInPlace(
      dataIndex,
      key,
      value,
      bitpos,
    ); // Call function directly
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
      final len = content.length;
      final newContent = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newContent[i] = content[i];
      }
      newContent[payloadIndex + 1] = value;
      return (
        node: ChampArrayNodeImpl<K, V>(dataMap, nodeMap, newContent),
        didAdd: false,
      );
    } else {
      final subNode = mergeDataEntries<K, V>(
        // Call function directly
        shift + kBitPartitionSize,
        hash,
        currentKey,
        currentValue,
        hash,
        key,
        value,
        null,
      );
      final newNode = ChampArrayNodeImpl<K, V>(
        dataMap ^ bitpos | (1 << frag),
        nodeMap,
        [], // Placeholder - content needs correct construction
      );
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      null,
    );

    if (identical(addResult.node, subNode)) {
      return (node: this, didAdd: addResult.didAdd);
    }

    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = addResult.node;
    final newNode = publicCreateImmutableNode(
      dataMap,
      nodeMap,
      newContent,
    ); // Call function directly
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
    final newContent = List<Object?>.of(content)
      ..insertAll(payloadIndex, [key, value]);
    final newDataMap = dataMap | bitpos;
    final newNode = publicCreateImmutableNode(
      newDataMap,
      nodeMap,
      newContent,
    ); // Call function directly
    return (node: newNode, didAdd: true);
  }

  // From champ_array_node_remove.dart
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
      return (node: this, didRemove: false);
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _removeImmutableData(key, frag, bitpos);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeImmutableDelegate(key, hash, shift, frag, bitpos);
      }
      return (node: this, didRemove: false);
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
      removeDataEntryInPlace(dataIndex, bitpos); // Call function directly
      final newNode = _shrinkOrTransitionIfNeeded(owner);
      return (
        node: newNode ?? ChampEmptyNode<K, V>(),
        didRemove: true,
      ); // Use constructor
    }
    return (node: this, didRemove: false);
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    content[contentIdx] = removeResult.node;

    if (removeResult.node.isEmptyNode) {
      removeNodeEntryInPlace(nodeIndex, bitpos); // Call function directly
      final newNode = _shrinkOrTransitionIfNeeded(owner);
      return (
        node: newNode ?? ChampEmptyNode<K, V>(),
        didRemove: true,
      ); // Use constructor
    } else if (removeResult.node is ChampDataNode<K, V>) {
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      replaceNodeWithDataInPlace(
        // Call function directly
        nodeIndex,
        dataNode.dataKey,
        dataNode.dataValue,
        bitpos,
      );
      final newNode = _shrinkOrTransitionIfNeeded(owner);
      return (node: newNode ?? this, didRemove: true);
    }
    return (node: this, didRemove: true);
  }

  ChampNode<K, V>? _shrinkOrTransitionIfNeeded(TransientOwner? owner) {
    assert(isTransient(owner));
    final currentChildCount = childCount;

    if (currentChildCount == 0) {
      assert(dataMap == 0 && nodeMap == 0);
      return ChampEmptyNode<K, V>(); // Use constructor
    }

    if (currentChildCount == 1 && nodeMap == 0) {
      assert(bitCount(dataMap) == 1);
      final key = content[0] as K;
      final value = content[1] as V;
      return ChampDataNode<K, V>(hashOfKey(key), key, value); // Use constructor
    }

    if (currentChildCount == 1 && dataMap == 0) {
      assert(bitCount(nodeMap) == 1);
      return content[0] as ChampNode<K, V>;
    }

    if (currentChildCount <= kSparseNodeThreshold) {
      return ChampSparseNode<K, V>(
        dataMap,
        nodeMap,
        content,
        owner,
      ); // Use constructor
    }

    return this;
  }

  // --- Immutable Remove Helpers (ArrayNode) ---
  ChampRemoveResult<K, V> _removeImmutableData(K key, int frag, int bitpos) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (content[payloadIndex] == key) {
      final newDataMap = dataMap ^ bitpos;
      if (newDataMap == 0 && nodeMap == 0)
        return (
          node: ChampEmptyNode<K, V>(),
          didRemove: true,
        ); // Use constructor

      final newContent = List<Object?>.of(content)
        ..removeRange(payloadIndex, payloadIndex + 2);
      final newNode = ChampArrayNodeImpl<K, V>(newDataMap, nodeMap, newContent);
      return (node: newNode, didRemove: true);
    }
    return (node: this, didRemove: false);
  }

  ChampRemoveResult<K, V> _removeImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      null,
    );

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    if (removeResult.node.isEmptyNode) {
      final newNodeMap = nodeMap ^ bitpos;
      if (dataMap == 0 && newNodeMap == 0) {
        return (
          node: ChampEmptyNode<K, V>(),
          didRemove: true,
        ); // Use constructor
      }
      final newContent = List<Object?>.of(content)..removeAt(contentIdx);
      final newNode = ChampArrayNodeImpl<K, V>(dataMap, newNodeMap, newContent);
      return (node: newNode, didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      final newDataMap = dataMap | bitpos;
      final newNodeMap = nodeMap ^ bitpos;
      final dataPayloadIndex = dataIndexFromFragment(frag, newDataMap) * 2;

      final dataCount = bitCount(dataMap);
      final nodeCount = bitCount(nodeMap);
      final newDataCount = bitCount(newDataMap);
      final newNodeCount = bitCount(newNodeMap);
      final newChildrenList = List<Object?>.filled(
        newDataCount * 2 + newNodeCount,
        null,
      );

      if (dataPayloadIndex > 0) {
        newChildrenList.setRange(0, dataPayloadIndex, content, 0);
      }
      newChildrenList[dataPayloadIndex] = dataNode.dataKey;
      newChildrenList[dataPayloadIndex + 1] = dataNode.dataValue;
      final oldDataEnd = dataCount * 2;
      if (dataPayloadIndex < oldDataEnd) {
        newChildrenList.setRange(
          dataPayloadIndex + 2,
          newDataCount * 2,
          content,
          dataPayloadIndex,
        );
      }

      final newNodeDataEnd = newDataCount * 2;
      int targetIdx = newNodeDataEnd;
      for (int i = 0; i < nodeCount; i++) {
        if (i != nodeIndex) {
          final oldContentIdx = contentIndexFromNodeIndex(i, content.length);
          newChildrenList[targetIdx++] = content[oldContentIdx];
        }
      }

      final newNode = ChampArrayNodeImpl<K, V>(
        newDataMap,
        newNodeMap,
        newChildrenList,
      );
      return (node: newNode, didRemove: true);
    } else {
      final newContent = List<Object?>.of(content);
      newContent[contentIdx] = removeResult.node;
      final newNode = ChampArrayNodeImpl<K, V>(dataMap, nodeMap, newContent);
      return (node: newNode, didRemove: true);
    }
  }

  // From champ_array_node_update.dart
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
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      content[payloadIndex + 1] = updatedValue;
      return (node: this, sizeChanged: false);
    } else {
      if (ifAbsentFn != null) {
        final newValue = ifAbsentFn();
        final currentVal = content[payloadIndex + 1] as V;
        final subNode = mergeDataEntries<K, V>(
          // Call function directly
          shift + kBitPartitionSize,
          hash,
          currentKey,
          currentVal,
          hash,
          key,
          newValue,
          owner,
        );
        replaceDataWithNodeInPlace(
          dataIndex,
          subNode,
          bitpos,
        ); // Call function directly
        return (node: this, sizeChanged: true);
      } else {
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;

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

    content[contentIdx] = updateResult.node;
    return (node: this, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> _updateTransientEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    if (ifAbsentFn != null) {
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      insertDataEntryInPlace(
        dataIndex,
        key,
        newValue,
        bitpos,
      ); // Call function directly
      return (node: this, sizeChanged: true);
    } else {
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
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      final len = content.length;
      final newContent = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newContent[i] = content[i];
      }
      newContent[payloadIndex + 1] = updatedValue;
      return (
        node: ChampArrayNodeImpl<K, V>(dataMap, nodeMap, newContent),
        sizeChanged: false,
      );
    } else {
      if (ifAbsentFn != null) {
        final newValue = ifAbsentFn();
        final currentVal = content[payloadIndex + 1] as V;
        final subNode = mergeDataEntries<K, V>(
          // Call function directly
          shift + kBitPartitionSize,
          hash,
          currentKey,
          currentVal,
          hash,
          key,
          newValue,
          null,
        );
        final newNode = ChampArrayNodeImpl<K, V>(
          dataMap ^ bitpos | (1 << frag),
          nodeMap,
          [], // Placeholder - content needs correct construction
        );
        return (node: newNode, sizeChanged: true);
      } else {
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
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
    final subNode = content[contentIdx] as ChampNode<K, V>;

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

    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = updateResult.node;
    final newNode = publicCreateImmutableNode(
      dataMap,
      nodeMap,
      newContent,
    ); // Call function directly
    return (node: newNode, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> _updateImmutableEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
  ) {
    if (ifAbsentFn != null) {
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final newContent = List<Object?>.of(content)
        ..insertAll(dataIndex * 2, [key, newValue]);
      final newNode = publicCreateImmutableNode(
        // Call function directly
        dataMap | bitpos,
        nodeMap,
        newContent,
      );
      return (node: newNode, sizeChanged: true);
    }
    return (node: this, sizeChanged: false);
  }

  // Helper for immutable creation (placeholder, needs proper implementation)
  // This helper seems misplaced now, logic should be inline or in a separate utility
  // For now, keep it but acknowledge it might need refactoring.
  ChampNode<K, V> publicCreateImmutableNode(
    int dataMap,
    int nodeMap,
    List<Object?> content,
  ) {
    // TODO: Implement logic to potentially return SparseNode or ArrayNode
    return ChampArrayNodeImpl<K, V>(dataMap, nodeMap, content);
  }
}

// Implementations moved into class body.
