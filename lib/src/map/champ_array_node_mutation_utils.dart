/// Defines transient mutation helper methods for [ChampArrayNode].
library;

import 'champ_array_node_base.dart';
import 'champ_node_base.dart';
import 'champ_utils.dart';

extension ChampArrayNodeMutationUtilsExtension<K, V> on ChampArrayNode<K, V> {
  /// Inserts a data entry into the `content` list. Updates `dataMap`. Assumes transient.
  void _insertDataEntryInPlace(int dataIndex, K key, V value, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    content.insertAll(dataPayloadIndex, [key, value]);
    dataMap |= bitpos;
  }

  /// Removes a data entry from the `content` list. Updates `dataMap`. Assumes transient.
  void _removeDataEntryInPlace(int dataIndex, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    dataMap ^= bitpos;
  }

  /// Removes a child node entry from the `content` list. Updates `nodeMap`. Assumes transient.
  void _removeNodeEntryInPlace(int nodeIndex, int bitpos) {
    // assert(_owner != null); // Removed: Helper called only in transient context
    // nodeIndex is the index within the conceptual *reversed* node array
    final contentNodeIndex = contentIndexFromNodeIndex(
      nodeIndex,
      content.length,
    );
    content.removeAt(contentNodeIndex);
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
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);

    // Calculate the actual insertion index from the end of the *modified* list
    final insertIndex = content.length - targetNodeIndexRev;
    content.insert(insertIndex, subNode); // Insert at correct position from end

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
      content.length,
    );

    // Remove the node entry first
    content.removeAt(nodeContentIndex);

    // Insert the data entry (key, value) at the correct position in the *modified* list
    content.insertAll(dataPayloadIndex, [key, value]);

    // Update bitmaps
    dataMap |= bitpos; // Add data bit
    nodeMap ^= bitpos; // Remove node bit
  }
}
