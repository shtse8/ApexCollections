/// Defines the [ChampSparseNode] class, a bitmap node optimized for low child counts.
library;

import 'package:collection/collection.dart'; // For ListEquality

import 'champ_node_base.dart';
import 'champ_bitmap_node.dart';
import 'champ_utils.dart';
import 'champ_empty_node.dart';
import 'champ_data_node.dart';
import 'champ_array_node.dart'; // Needed for transitions
import 'champ_merging.dart'; // Needed for collisions

// --- Sparse Node Implementation ---
class ChampSparseNode<K, V> extends ChampBitmapNode<K, V> {
  List<Object?> children;

  ChampSparseNode(
    int dataMap,
    int nodeMap,
    List<Object?> children, [
    TransientOwner? owner,
  ]) : children = (owner != null) ? children : List.unmodifiable(children),
       assert(bitCount(dataMap) + bitCount(nodeMap) <= kSparseNodeThreshold),
       assert(children.length == bitCount(dataMap) * 2 + bitCount(nodeMap)),
       super(dataMap, nodeMap, owner);

  // --- In-place mutation helpers (SparseNode) ---

  /// Inserts a data entry into the `children` list. Updates `dataMap`. Assumes transient.
  void _insertDataEntryInPlace(int dataIndex, K key, V value, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    children.insertAll(dataPayloadIndex, [key, value]);
    dataMap |= bitpos;
  }

  /// Removes a data entry from the `children` list. Updates `dataMap`. Assumes transient.
  void _removeDataEntryInPlace(int dataIndex, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    children.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    dataMap ^= bitpos;
  }

  /// Removes a child node entry from the `children` list. Updates `nodeMap`. Assumes transient.
  void _removeNodeEntryInPlace(int nodeIndex, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    // nodeIndex is the index within the conceptual *reversed* node array
    final contentNodeIndex = contentIndexFromNodeIndex(
      nodeIndex,
      children.length,
    );
    children.removeAt(contentNodeIndex);
    nodeMap ^= bitpos;
  }

  /// Replaces a data entry with a sub-node in place. Updates bitmaps. Assumes transient.
  void _replaceDataWithNodeInPlace(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    final frag = bitCount(bitpos - 1); // Fragment index of the new node
    final targetNodeMap =
        nodeMap | bitpos; // Node map *after* adding the new node bit
    // Calculate the index within the conceptual *reversed* node array
    final targetNodeIndexRev = nodeIndexFromFragment(frag, targetNodeMap);

    // Remove the data entry first
    children.removeRange(dataPayloadIndex, dataPayloadIndex + 2);

    // Calculate the actual insertion index from the end of the *modified* list
    final insertIndex = children.length - targetNodeIndexRev;
    children.insert(
      insertIndex,
      subNode,
    ); // Insert at correct position from end

    // Update bitmaps
    dataMap ^= bitpos; // Remove data bit
    nodeMap |= bitpos; // Add node bit
  }

  /// Replaces a node entry with a data entry in place. Updates bitmaps. Assumes transient.
  void _replaceNodeWithDataInPlace(int nodeIndex, K key, V value, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    // nodeIndex is the index within the conceptual *reversed* node array
    final frag = bitCount(bitpos - 1); // Fragment for the new data
    final targetDataMap =
        dataMap | bitpos; // dataMap *after* adding the new data bit
    final targetDataIndex = dataIndexFromFragment(frag, targetDataMap);
    final dataPayloadIndex = contentIndexFromDataIndex(targetDataIndex);

    // Calculate the index of the node to remove (from the end)
    final nodeContentIndex = contentIndexFromNodeIndex(
      nodeIndex,
      children.length,
    );

    // Remove the node entry first
    children.removeAt(nodeContentIndex);

    // Insert the data entry (key, value) at the correct position in the *modified* list
    children.insertAll(dataPayloadIndex, [key, value]);

    // Update bitmaps
    dataMap |= bitpos; // Add data bit
    nodeMap ^= bitpos; // Remove node bit
  }

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

  // --- Immutable Helper (SparseNode) ---

  /// Creates a new node replacing a data entry with a sub-node immutably.
  /// Handles potential transition to ArrayNode.
  ChampNode<K, V> _replaceDataWithNodeImmutable(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    final dataPayloadIndex = dataIndex * 2;
    final dataCount = bitCount(dataMap);
    final nodeCount = bitCount(nodeMap);
    final newDataCount = dataCount - 1;
    final newNodeCount = nodeCount + 1;
    // final newChildCount = newDataCount + newNodeCount; // Not needed directly

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

    // Decide node type based on the *new* count
    return _createImmutableNode(newDataMap, newNodeMap, newChildren);
  }

  /// Helper to create the correct immutable node type (Sparse, Array, Data, Empty)
  /// based on the final child count after an immutable operation.
  /// Assumes the caller has already calculated the final bitmaps and content.
  ChampNode<K, V> _createImmutableNode(
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
      return ChampArrayNode<K, V>(newDataMap, newNodeMap, newContent);
    }
  }

  // --- Transient Add Helpers (SparseNode) ---

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
    final currentKey = children[payloadIndex] as K;
    final currentValue = children[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      children[payloadIndex + 1] = value; // Mutate in place
      return (node: this, didAdd: false);
    } else {
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hash, // Use existing hash for currentKey
        currentKey,
        currentValue,
        hash, // Hash of the new key (can be different if keys differ but collide at this level)
        key,
        value,
        owner,
      );
      _replaceDataWithNodeInPlace(
        dataIndex,
        subNode,
        bitpos,
      ); // Mutate in place
      // Count doesn't change, but type might (Array->Sparse not possible here)
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

  ChampAddResult<K, V> _addTransientEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
    TransientOwner owner, // Added owner
  ) {
    assert(isTransient(owner)); // Use owner
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    _insertDataEntryInPlace(dataIndex, key, value, bitpos); // Mutate in place

    // Check for transition Sparse -> Array
    if (childCount > kSparseNodeThreshold) {
      // Create ArrayNode, passing the current mutable children list and owner
      return (
        node: ChampArrayNode<K, V>(dataMap, nodeMap, children, owner),
        didAdd: true,
      );
    }
    // Remain SparseNode
    return (node: this, didAdd: true);
  }

  // --- Immutable Add Helpers (SparseNode) ---

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
        hash, // Use existing hash for currentKey
        currentKey,
        currentValue,
        hash, // Hash of the new key
        key,
        value,
        null, // Immutable merge
      );
      // Create new node replacing data with sub-node
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
    return (
      node: _createImmutableNode(dataMap, nodeMap, newChildren), // Use helper
      didAdd: addResult.didAdd,
    );
  }

  ChampAddResult<K, V> _addImmutableEmptySlot(
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
        node: ChampArrayNode<K, V>(newDataMap, nodeMap, newChildren),
        didAdd: true,
      );
    } else {
      return (
        node: ChampSparseNode<K, V>(newDataMap, nodeMap, newChildren),
        didAdd: true,
      );
    }
  }

  // --- Transient Remove Helpers (SparseNode) ---

  ChampRemoveResult<K, V> _removeTransientData(
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
      _removeDataEntryInPlace(dataIndex, bitpos); // Mutate in place
      // Check if node needs shrinking/collapsing (Sparse version)
      final newNode = _shrinkIfNeeded(owner);
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
      _removeNodeEntryInPlace(
        nodeIndex,
        bitpos,
      ); // Mutate in place (uses correct index)
      final newNode = _shrinkIfNeeded(owner); // Check for collapse
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // If sub-node collapsed to a data node, replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      _replaceNodeWithDataInPlace(
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

  ChampRemoveResult<K, V> _removeImmutableData(K key, int frag, int bitpos) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (children[payloadIndex] == key) {
      // Found the key to remove
      final newDataMap = dataMap ^ bitpos;
      if (newDataMap == 0 && nodeMap == 0)
        return (node: ChampEmptyNode<K, V>(), didRemove: true);

      // Create new list with data entry removed
      final newChildren = List<Object?>.of(children)
        ..removeRange(payloadIndex, payloadIndex + 2);
      // Create new node (will be Sparse or simpler)
      final newNode = _createImmutableNode(newDataMap, nodeMap, newChildren);
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
      final newNode = _createImmutableNode(dataMap, newNodeMap, newChildren);
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
      final newNode = _createImmutableNode(
        newDataMap,
        newNodeMap,
        newChildrenList,
      );
      return (node: newNode, didRemove: true);
    } else {
      // Sub-node modified but not removed/collapsed
      // Create new children list with updated sub-node
      final newChildren = List<Object?>.of(children);
      newChildren[contentIdx] = removeResult.node;
      // Create new node (type determined by helper)
      final newNode = _createImmutableNode(dataMap, nodeMap, newChildren);
      return (node: newNode, didRemove: true);
    }
  }

  // --- Transient Update Helpers (SparseNode) ---

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
    final currentKey = children[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value in place
      final currentValue = children[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
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
          hash, // Use existing hash for currentKey
          currentKey,
          currentVal,
          hash, // Hash of the new key
          key,
          newValue,
          owner,
        );
        _replaceDataWithNodeInPlace(
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
      _insertDataEntryInPlace(
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
    final currentKey = children[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value
      final currentValue = children[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
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
          hash, // Use existing hash for currentKey
          currentKey,
          currentVal,
          hash, // Hash of the new key
          key,
          newValue,
          null, // Immutable merge
        );
        // Create new node replacing data with sub-node
        final newNode = _replaceDataWithNodeImmutable(
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
    final newNode = _createImmutableNode(dataMap, nodeMap, newChildren);
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

  // Implement abstract methods from ChampNode/ChampBitmapNode
  @override
  V? get(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final payloadIndex = contentIndexFromDataIndex(dataIndex);
      if (children[payloadIndex] == key) {
        return children[payloadIndex + 1] as V;
      }
      return null;
    } else if ((nodeMap & bitpos) != 0) {
      final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
      // Calculate index from the end
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, children.length);
      final subNode = children[contentIdx] as ChampNode<K, V>;
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
      return children[payloadIndex] == key;
    } else if ((nodeMap & bitpos) != 0) {
      final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
      // Calculate index from the end
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, children.length);
      final subNode = children[contentIdx] as ChampNode<K, V>;
      return subNode.containsKey(key, hash, shift + kBitPartitionSize);
    }
    return false;
  }

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

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      final nodeCount = bitCount(nodeMap);
      // Freeze child nodes recursively (iterate from the end)
      for (int i = 0; i < nodeCount; i++) {
        // Calculate index from the end
        final contentIdx = contentIndexFromNodeIndex(i, children.length);
        final subNode = children[contentIdx] as ChampNode<K, V>;
        // Freeze recursively and update in place (safe as we own it)
        children[contentIdx] = subNode.freeze(owner);
      }
      this.children = List.unmodifiable(children); // Make list unmodifiable
      // Call super.freeze() AFTER handling subclass state
      return super.freeze(owner);
    }
    return this; // Already immutable or not owned
  }

  @override
  ChampBitmapNode<K, V> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy with the new owner
    return ChampSparseNode<K, V>(
      dataMap,
      nodeMap,
      List.of(children, growable: true), // Create mutable copy
      owner,
    );
  }

  // Equality for bitmap nodes depends on the bitmaps and the content list.
  static const _equality = ListEquality();

  @override
  int get hashCode => Object.hash(dataMap, nodeMap, _equality.hash(children));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Check type and bitmaps first for short-circuiting (as per CHAMP paper)
    return other is ChampSparseNode<K, V> &&
        dataMap == other.dataMap &&
        nodeMap == other.nodeMap &&
        _equality.equals(children, other.children);
  }
} // End of ChampSparseNode
