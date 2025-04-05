/// Defines the base [ChampArrayNode] class structure, constructors, and core properties.
library;

import 'package:collection/collection.dart'; // For ListEquality

import 'champ_node_base.dart';
import 'champ_bitmap_node.dart';
import 'champ_utils.dart';
import 'champ_empty_node.dart';
import 'champ_data_node.dart';
import 'champ_sparse_node.dart'; // Needed for transitions
import 'champ_array_node_impl.dart'; // Import the implementation

// --- Array Node Implementation ---
abstract class ChampArrayNode<K, V> extends ChampBitmapNode<K, V> {
  List<Object?> content; // Use 'content' for ArrayNode

  ChampArrayNode(
    int dataMap,
    int nodeMap,
    List<Object?> content, [
    TransientOwner? owner,
  ]) : content = (owner != null) ? content : List.unmodifiable(content),
       assert(bitCount(dataMap) + bitCount(nodeMap) > kSparseNodeThreshold),
       assert(content.length == bitCount(dataMap) * 2 + bitCount(nodeMap)),
       super(dataMap, nodeMap, owner);

  /// Helper to create the correct immutable node type (Sparse, Array, Data, Empty)
  /// based on the final child count after an immutable operation.
  /// Assumes the caller has already calculated the final bitmaps and content.
  ChampNode<K, V> _createImmutableNode(
    // Keep as private instance method
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
        return ChampDataNode<K, V>(
          hashOfKey(key),
          key,
          value,
        ); // Now can access hashOfKey
      } else {
        // Collapse to single sub-node (return the sub-node directly)
        // The single node is at the end (index 0 from end)
        return newContent[0] as ChampNode<K, V>;
      }
    }

    // Check threshold *before* creating node
    if (childCount <= kSparseNodeThreshold) {
      // Transition to SparseNode
      return ChampSparseNode<K, V>(newDataMap, newNodeMap, newContent);
    } else {
      // Stay ArrayNode
      return ChampArrayNodeImpl<K, V>(
        newDataMap,
        newNodeMap,
        newContent,
      ); // Use Impl
    }
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      final nodeCount = bitCount(nodeMap);
      // Freeze child nodes recursively (iterate from the end)
      for (int i = 0; i < nodeCount; i++) {
        // Calculate index from the end
        final contentIdx = contentIndexFromNodeIndex(i, content.length);
        final subNode = content[contentIdx] as ChampNode<K, V>;
        // Freeze recursively and update in place (safe as we own it)
        content[contentIdx] = subNode.freeze(owner);
      }
      this.content = List.unmodifiable(content); // Make list unmodifiable
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
    return ChampArrayNodeImpl<K, V>(
      // Use Impl
      dataMap,
      nodeMap,
      List.of(content, growable: true), // Create mutable copy of 'content'
      owner,
    );
  }

  // Equality for bitmap nodes depends on the bitmaps and the content list.
  static const _equality = ListEquality();

  @override
  int get hashCode => Object.hash(dataMap, nodeMap, _equality.hash(content));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Check type and bitmaps first for short-circuiting (as per CHAMP paper)
    return other is ChampArrayNode<K, V> &&
        dataMap == other.dataMap &&
        nodeMap == other.nodeMap &&
        _equality.equals(content, other.content);
  }

  /// Public helper to call the private _createImmutableNode method.
  /// This is needed because extensions cannot call private methods of the base class.
  ChampNode<K, V> publicCreateImmutableNode(
    int newDataMap,
    int newNodeMap,
    List<Object?> newContent,
  ) {
    return _createImmutableNode(newDataMap, newNodeMap, newContent);
  }

  // --- Abstract methods to be implemented in separate files ---

  @override
  V? get(K key, int hash, int shift);

  @override
  bool containsKey(K key, int hash, int shift);

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  @override
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  });

  // --- Immutable Helper Method (Moved back from utils) ---

  /// Creates a new node replacing a data entry with a sub-node immutably.
  /// Handles potential transition to SparseNode.
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

    // Create the new content list
    final newContent = List<Object?>.filled(
      newDataCount * 2 + newNodeCount, // Correct size calculation
      null,
      growable: false,
    );

    // --- Copy elements into newContent ---
    // Copy data entries (excluding the one being replaced)
    if (dataIndex > 0) {
      newContent.setRange(0, dataPayloadIndex, content, 0);
    }
    if (dataIndex < dataCount - 1) {
      newContent.setRange(
        dataPayloadIndex, // Start index in new list
        newDataCount * 2, // End index for data in new list
        content, // Source list
        dataPayloadIndex + 2, // Start index in old list (skip replaced)
      );
    }

    // Calculate insertion position for the new subNode (index from the end)
    final frag = bitCount(bitpos - 1);
    final targetNodeMap = nodeMap | bitpos;
    final targetNodeIndexRev = nodeIndexFromFragment(frag, targetNodeMap);
    final nodeInsertPos = newContent.length - 1 - targetNodeIndexRev;

    // Copy existing nodes into the end of the new list, leaving space for the new node
    final oldNodeStartIndex =
        dataCount * 2; // Start of nodes in old list (original order)
    final newNodeDataEnd = newDataCount * 2; // End of data in new list

    // Copy nodes that come *after* the new node in the reversed order
    // (These correspond to indices *smaller* than targetNodeIndexRev in the conceptual reversed array)
    // In the original list, these are the first targetNodeIndexRev nodes.
    if (targetNodeIndexRev > 0) {
      newContent.setRange(
        newNodeDataEnd, // Start writing nodes after data in new list
        nodeInsertPos, // Write up to the insertion point
        content.getRange(
          oldNodeStartIndex,
          oldNodeStartIndex + targetNodeIndexRev,
        ), // Get the correct range from old list
      );
    }
    // Copy nodes that come *before* the new node in the reversed order
    // (These correspond to indices *greater than or equal to* targetNodeIndexRev in the conceptual reversed array)
    // In the original list, these are the nodes from targetNodeIndexRev onwards.
    if (targetNodeIndexRev < nodeCount) {
      newContent.setRange(
        nodeInsertPos + 1, // Start writing after the inserted node
        newContent.length, // Write to the end
        content.getRange(
          oldNodeStartIndex + targetNodeIndexRev,
          oldNodeStartIndex + nodeCount,
        ), // Get the correct range from old list
      );
    }

    // Insert the new subNode at the calculated position
    newContent[nodeInsertPos] = subNode;
    // --- End Copy ---

    final newDataMap = dataMap ^ bitpos; // Remove data bit
    final newNodeMap = nodeMap | bitpos; // Add node bit

    // Decide node type based on the *new* count
    // Use the _createImmutableNode method from the base class
    return _createImmutableNode(newDataMap, newNodeMap, newContent);
  }
}
