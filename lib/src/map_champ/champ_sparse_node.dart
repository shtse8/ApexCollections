/// Defines the [ChampSparseNode] class, a bitmap node optimized for low child counts.
library;

import 'package:collection/collection.dart'; // For ListEquality

import 'champ_node_base.dart';
import 'champ_bitmap_node.dart';
import 'champ_utils.dart';
// Remove unused imports (now handled by extensions or immutable utils)
// import 'champ_empty_node.dart';
// import 'champ_data_node.dart';
// import 'champ_array_node.dart';
// Import the extensions containing the helper methods
import 'champ_sparse_node_add.dart';
import 'champ_sparse_node_remove.dart';
import 'champ_sparse_node_update.dart';
// Mutation utils are used internally by the add/remove/update extensions

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

  // --- Core Methods (Implement abstract methods from ChampNode/ChampBitmapNode) ---

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
        // Call extension method
        return addTransientDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else if ((nodeMap & bitpos) != 0) {
        // Call extension method
        return addTransientDelegate(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else {
        // Call extension method
        return addTransientEmptySlot(key, value, frag, bitpos, owner!);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        // Call extension method
        return addImmutableDataCollision(key, value, hash, shift, frag, bitpos);
      } else if ((nodeMap & bitpos) != 0) {
        // Call extension method
        return addImmutableDelegate(key, value, hash, shift, frag, bitpos);
      } else {
        // Call extension method
        return addImmutableEmptySlot(key, value, frag, bitpos);
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
        // Call extension method
        return removeTransientData(key, frag, bitpos, owner!);
      } else if ((nodeMap & bitpos) != 0) {
        // Call extension method
        return removeTransientDelegate(key, hash, shift, frag, bitpos, owner!);
      }
      return (node: this, didRemove: false); // Key not found
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        // Call extension method
        return removeImmutableData(key, frag, bitpos);
      } else if ((nodeMap & bitpos) != 0) {
        // Call extension method
        return removeImmutableDelegate(key, hash, shift, frag, bitpos);
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
        // Call extension method
        return updateTransientData(
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
        // Call extension method
        return updateTransientDelegate(
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
        // Call extension method
        return updateTransientEmptySlot(key, frag, bitpos, ifAbsentFn, owner!);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        // Call extension method
        return updateImmutableData(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else if ((nodeMap & bitpos) != 0) {
        // Call extension method
        return updateImmutableDelegate(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else {
        // Call extension method
        return updateImmutableEmptySlot(key, frag, bitpos, ifAbsentFn);
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
