/// Defines extension methods for in-place mutation helpers on [ChampSparseNode].
/// These methods assume the node is transient and owned by the caller.
library;

import 'champ_sparse_node.dart';
import 'champ_node_base.dart';
import 'champ_utils.dart';

extension ChampSparseNodeMutationUtils<K, V> on ChampSparseNode<K, V> {
  /// Inserts a data entry into the `children` list. Updates `dataMap`. Assumes transient.
  void insertDataEntryInPlace(int dataIndex, K key, V value, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    children.insertAll(dataPayloadIndex, [key, value]);
    dataMap |= bitpos;
  }

  /// Removes a data entry from the `children` list. Updates `dataMap`. Assumes transient.
  void removeDataEntryInPlace(int dataIndex, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    children.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    dataMap ^= bitpos;
  }

  /// Removes a child node entry from the `children` list. Updates `nodeMap`. Assumes transient.
  void removeNodeEntryInPlace(int nodeIndex, int bitpos) {
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
  void replaceDataWithNodeInPlace(
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
  void replaceNodeWithDataInPlace(int nodeIndex, K key, V value, int bitpos) {
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
}
