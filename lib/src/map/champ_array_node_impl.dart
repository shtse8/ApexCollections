/// Defines the concrete implementation [ChampArrayNodeImpl] extending [ChampArrayNode].
library;

import 'champ_array_node_base.dart';
import 'champ_node_base.dart'; // For result types
import 'champ_utils.dart'; // Import TransientOwner
import 'champ_array_node_get.dart'; // Import extensions
import 'champ_array_node_add.dart';
import 'champ_array_node_remove.dart';
import 'champ_array_node_update.dart';

/// Concrete implementation of ChampArrayNode.
class ChampArrayNodeImpl<K, V> extends ChampArrayNode<K, V> {
  /// Creates a concrete ArrayNode instance.
  ChampArrayNodeImpl(
    int dataMap,
    int nodeMap,
    List<Object?> content, [
    TransientOwner? owner,
  ]) : super(dataMap, nodeMap, content, owner);

  // Implement abstract methods by delegating to extension methods
  // (These will be defined in separate files later)

  @override
  V? get(K key, int hash, int shift) =>
      ChampArrayNodeGetExtension(this).get(key, hash, shift);

  @override
  bool containsKey(K key, int hash, int shift) =>
      ChampArrayNodeGetExtension(this).containsKey(key, hash, shift);

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) => ChampArrayNodeAddExtension(this).add(key, value, hash, shift, owner);

  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) => ChampArrayNodeRemoveExtension(this).remove(key, hash, shift, owner);

  @override
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) => ChampArrayNodeUpdateExtension(
    this,
  ).update(key, hash, shift, updateFn, ifAbsentFn: ifAbsentFn, owner: owner);
}

// Define placeholder extension types to satisfy the compiler for now.
// The actual implementations will be in separate files.
extension ChampArrayNodeGetExtension<K, V> on ChampArrayNode<K, V> {
  V? get(K key, int hash, int shift) => throw UnimplementedError();
  bool containsKey(K key, int hash, int shift) => throw UnimplementedError();
}

extension ChampArrayNodeAddExtension<K, V> on ChampArrayNode<K, V> {
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) => throw UnimplementedError();
}

extension ChampArrayNodeRemoveExtension<K, V> on ChampArrayNode<K, V> {
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) => throw UnimplementedError();
}

extension ChampArrayNodeUpdateExtension<K, V> on ChampArrayNode<K, V> {
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) => throw UnimplementedError();
}
