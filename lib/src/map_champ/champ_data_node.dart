/// Defines the [ChampDataNode] class, representing a CHAMP node with a single entry.
library;

import 'champ_node_base.dart';
import 'champ_empty_node.dart'; // Needed for remove
import 'champ_merging.dart'; // Needed for add/update collision
import 'champ_utils.dart'; // For TransientOwner
// Remove unused imports (types are handled by champ_merging.dart)
// import 'champ_collision_node.dart';
// import 'champ_bitmap_node.dart';
// import 'champ_sparse_node.dart';
// import 'champ_array_node.dart';

// --- Data Node ---

/// Represents a CHAMP node containing exactly one key-value pair.
/// These nodes are always immutable.
class ChampDataNode<K, V> extends ChampNode<K, V> {
  /// The full hash code of the stored key.
  final int dataHash;

  /// The stored key.
  final K dataKey;

  /// The stored value.
  final V dataValue;

  /// Creates an immutable data node.
  ChampDataNode(this.dataHash, this.dataKey, this.dataValue) : super(null);

  @override
  V? get(K key, int hash, int shift) {
    // Check if the requested key matches the stored key.
    return (key == dataKey) ? dataValue : null;
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    // Check if the requested key matches the stored key.
    return key == dataKey;
  }

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (key == dataKey) {
      // Update existing key if value differs
      if (value == dataValue) return (node: this, didAdd: false); // No change
      // Create new immutable DataNode
      return (node: ChampDataNode(hash, key, value), didAdd: false);
    }

    // Collision: Create a new node (Bitmap or Collision) to merge the two entries.
    // Merging always creates immutable nodes initially.
    final newNode = mergeDataEntries(
      shift, // Start merging from the current shift level
      dataHash,
      dataKey,
      dataValue,
      hash,
      key,
      value,
      null, // Pass null owner for immutable merge
    );
    return (node: newNode, didAdd: true);
  }

  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (key == dataKey) {
      // Remove this node by returning the canonical empty node.
      return (node: ChampEmptyNode<K, V>(), didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
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
    if (key == dataKey) {
      // Update existing key
      final newValue = updateFn(dataValue);
      if (newValue == dataValue) return (node: this, sizeChanged: false);
      // Create new immutable DataNode
      return (node: ChampDataNode(hash, key, newValue), sizeChanged: false);
    } else if (ifAbsentFn != null) {
      // Key not found, add using ifAbsentFn (results in merging)
      final newValue = ifAbsentFn();
      // Merging always creates immutable nodes initially.
      final newNode = mergeDataEntries(
        shift,
        dataHash,
        dataKey,
        dataValue,
        hash,
        key,
        newValue,
        null, // Pass null owner for immutable merge
      );
      return (node: newNode, sizeChanged: true);
    }
    // Key not found, no ifAbsentFn
    return (node: this, sizeChanged: false);
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) => this; // Already immutable

  @override
  int get hashCode => Object.hash(dataHash, dataKey, dataValue);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChampDataNode<K, V> &&
        dataHash == other.dataHash && // Check hash first for quick exit
        dataKey == other.dataKey &&
        dataValue == other.dataValue;
  }
}
