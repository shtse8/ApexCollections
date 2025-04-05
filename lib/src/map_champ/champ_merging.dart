/// Defines the merging logic for CHAMP Trie nodes, specifically the [mergeDataEntries] function.
library;

// Remove unused: import 'dart:collection'; // MapEntry is part of dart:core

import 'champ_node_base.dart';
import 'champ_utils.dart';
import 'champ_collision_node.dart';
import 'champ_bitmap_node.dart'; // Needed for return type hint
import 'champ_sparse_node.dart';
import 'champ_array_node_base.dart'; // Import base for type
import 'champ_array_node_impl.dart'; // Import concrete implementation

// --- Merging Logic ---

/// Merges two data entries into a new node (Bitmap or Collision).
/// This is used when adding a new entry results in a collision with an existing
/// `ChampDataNode` or when splitting nodes during bulk loading.
///
/// - [shift]: The current bit shift level where the collision/merge occurs.
/// - [hash1], [key1], [value1]: Details of the first entry.
/// - [hash2], [key2], [value2]: Details of the second entry.
/// - [owner]: Optional owner for creating transient nodes during the merge.
///
/// Returns a potentially transient [ChampBitmapNode] or [ChampCollisionNode].
ChampNode<K, V> mergeDataEntries<K, V>(
  int shift,
  int hash1,
  K key1,
  V value1,
  int hash2,
  K key2,
  V value2,
  TransientOwner? owner, // Added owner parameter
) {
  assert(key1 != key2); // Keys must be different

  if (shift >= kMaxDepth * kBitPartitionSize) {
    // Max depth reached, create a collision node
    return ChampCollisionNode<K, V>(
      hash1, // Use one of the hashes
      [MapEntry(key1, value1), MapEntry(key2, value2)],
      owner, // Pass owner for potential transient collision node
    );
  }

  final frag1 = indexFragment(shift, hash1);
  final frag2 = indexFragment(shift, hash2);

  if (frag1 == frag2) {
    // Fragments match, recurse deeper
    final subNode = mergeDataEntries(
      shift + kBitPartitionSize,
      hash1,
      key1,
      value1,
      hash2,
      key2,
      value2,
      owner, // Pass owner down recursively
    );
    // Create a bitmap node with the single sub-node
    final bitpos = 1 << frag1;
    final dataMap = 0;
    final nodeMap = bitpos;
    // Node is stored at the end (index 0 from end)
    final children = [subNode];
    // Create directly based on count (which is 1)
    if (kSparseNodeThreshold >= 1) {
      return ChampSparseNode<K, V>(dataMap, nodeMap, children, owner);
    } else {
      // Should not happen if threshold >= 1
      return ChampArrayNodeImpl<K, V>(dataMap, nodeMap, children, owner);
    }
  } else {
    // Fragments differ, create a bitmap node with two data entries
    final bitpos1 = 1 << frag1;
    final bitpos2 = 1 << frag2;
    final newDataMap = bitpos1 | bitpos2;
    final newNodeMap = 0;

    // Order entries based on fragment index for consistent content layout
    final List<Object?> newContent;
    if (frag1 < frag2) {
      newContent = [key1, value1, key2, value2];
    } else {
      newContent = [key2, value2, key1, value1];
    }
    // Create directly based on count (which is 2)
    if (kSparseNodeThreshold >= 2) {
      return ChampSparseNode<K, V>(newDataMap, newNodeMap, newContent, owner);
    } else {
      return ChampArrayNodeImpl<K, V>(
        newDataMap,
        newNodeMap,
        newContent,
        owner,
      );
    }
  }
}
