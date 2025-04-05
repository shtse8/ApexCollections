/// Defines the get and containsKey logic for [ChampArrayNode].
library;

import 'champ_array_node_base.dart';
import 'champ_node_base.dart';
import 'champ_utils.dart';

extension ChampArrayNodeGetExtension<K, V> on ChampArrayNode<K, V> {
  @override
  V? get(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final payloadIndex = contentIndexFromDataIndex(dataIndex);
      if (content[payloadIndex] == key) {
        // Use 'content'
        return content[payloadIndex + 1] as V; // Use 'content'
      }
      return null;
    } else if ((nodeMap & bitpos) != 0) {
      final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
      // Calculate index from the end
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
      final subNode = content[contentIdx] as ChampNode<K, V>; // Use 'content'
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
      return content[payloadIndex] == key; // Use 'content'
    } else if ((nodeMap & bitpos) != 0) {
      final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
      // Calculate index from the end
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, content.length);
      final subNode = content[contentIdx] as ChampNode<K, V>; // Use 'content'
      return subNode.containsKey(key, hash, shift + kBitPartitionSize);
    }
    return false;
  }
}
