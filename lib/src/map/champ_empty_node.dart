/// Defines the [ChampEmptyNode] class, representing the canonical empty CHAMP node.
library;

import 'champ_node_base.dart';
import 'champ_data_node.dart'; // Needed for add/update
import 'champ_utils.dart'; // For TransientOwner

// --- Empty Node ---

/// Represents the single, canonical empty CHAMP node.
/// This is used as the starting point for an empty map.
class ChampEmptyNode<K, V> extends ChampNode<K, V> {
  // Private constructor for singleton pattern
  ChampEmptyNode._internal() : super(null); // Always immutable

  // Static instance (typed as Never to allow casting)
  static final ChampEmptyNode<Never, Never> _instance =
      ChampEmptyNode._internal();

  /// Factory constructor to return the singleton empty node instance.
  factory ChampEmptyNode() => _instance as ChampEmptyNode<K, V>;

  @override
  bool get isEmptyNode => true;

  @override
  V? get(K key, int hash, int shift) => null;

  @override
  bool containsKey(K key, int hash, int shift) => false;

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    // Adding to empty creates a DataNode
    // DataNode is always immutable, no owner needed
    final newNode = ChampDataNode<K, V>(hash, key, value);
    return (node: newNode, didAdd: true);
  }

  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    return (node: this, didRemove: false); // Cannot remove from empty
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
    if (ifAbsentFn != null) {
      // Add new entry if ifAbsentFn is provided
      final newValue = ifAbsentFn();
      // DataNode is always immutable
      final newNode = ChampDataNode<K, V>(hash, key, newValue);
      return (node: newNode, sizeChanged: true);
    }
    // Otherwise, no change
    return (node: this, sizeChanged: false);
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) => this; // Already immutable
}
