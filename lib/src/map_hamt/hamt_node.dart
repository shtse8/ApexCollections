/// Defines the basic node structures for a potential HAMT implementation.
library apex_collections.src.map_hamt.hamt_node;

import 'dart:collection'; // For MapEntry
// Reuse TransientOwner and utils from CHAMP implementation for now
import '../map/champ_utils.dart';
import '../map/champ_node_base.dart'
    show
        ChampAddResult,
        ChampRemoveResult,
        ChampUpdateResult; // Reuse result types for now

// --- Base HAMT Node ---

/// Abstract base class for nodes in a Hash Array Mapped Trie (HAMT).
abstract class HamtNode<K, V> {
  /// Optional owner for transient nodes.
  TransientOwner? _owner;

  /// Constructor for subclasses.
  HamtNode([this._owner]);

  /// Checks if the node is currently mutable and belongs to the given [owner].
  bool isTransient(TransientOwner? owner) => _owner != null && _owner == owner;

  /// Returns an immutable version of this node.
  HamtNode<K, V> freeze(TransientOwner? owner);

  /// Indicates if this is the canonical empty node.
  bool get isEmptyNode => false;

  // --- Core Operations (Abstract) ---

  /// Returns the value associated with the [key], or `null` if not found.
  V? get(K key, int hash, int shift);

  /// Checks if the [key] exists within the subtree rooted at this node.
  bool containsKey(K key, int hash, int shift);

  /// Adds or updates a key-value pair. Returns the new node and status.
  /// Note: Return type might need adjustment from CHAMP's. Using placeholder.
  ({HamtNode<K, V> node, bool didAdd}) add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Removes a [key]. Returns the new node and status.
  /// Note: Return type might need adjustment from CHAMP's. Using placeholder.
  ({HamtNode<K, V> node, bool didRemove}) remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Updates the value associated with [key]. Returns the new node and status.
  /// Note: Return type might need adjustment from CHAMP's. Using placeholder.
  ({HamtNode<K, V> node, bool sizeChanged}) update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  });

  /// Helper to get the hash code of a key.
  int hashOfKey(K key) => key.hashCode;
}

// --- Empty Node ---

/// Represents the canonical empty HAMT node.
class HamtEmptyNode<K, V> extends HamtNode<K, V> {
  static final HamtEmptyNode<Never, Never> _instance =
      HamtEmptyNode._internal();
  HamtEmptyNode._internal() : super(null); // Always immutable
  factory HamtEmptyNode() => _instance as HamtEmptyNode<K, V>;

  @override
  bool get isEmptyNode => true;
  @override
  HamtNode<K, V> freeze(TransientOwner? owner) => this;
  @override
  V? get(K key, int hash, int shift) => null;
  @override
  bool containsKey(K key, int hash, int shift) => false;

  @override
  ({HamtNode<K, V> node, bool didAdd}) add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    // Adding to empty creates a DataNode
    return (node: HamtDataNode(hash, key, value), didAdd: true);
  }

  @override
  ({HamtNode<K, V> node, bool didRemove}) remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) => (node: this, didRemove: false);

  @override
  ({HamtNode<K, V> node, bool sizeChanged}) update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) {
    if (ifAbsentFn != null) {
      final newValue = ifAbsentFn();
      return (node: HamtDataNode(hash, key, newValue), sizeChanged: true);
    }
    return (node: this, sizeChanged: false);
  }
}

// --- Data Node (Leaf with single non-colliding entry) ---

/// Represents a HAMT node containing exactly one key-value pair. Immutable.
class HamtDataNode<K, V> extends HamtNode<K, V> {
  final int dataHash;
  final K dataKey;
  final V dataValue;

  HamtDataNode(this.dataHash, this.dataKey, this.dataValue)
    : super(null); // Always immutable

  @override
  HamtNode<K, V> freeze(TransientOwner? owner) => this;
  @override
  V? get(K key, int hash, int shift) => (key == dataKey) ? dataValue : null;
  @override
  bool containsKey(K key, int hash, int shift) => key == dataKey;

  @override
  ({HamtNode<K, V> node, bool didAdd}) add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (key == dataKey) {
      return (value == dataValue)
          ? (node: this, didAdd: false)
          : (node: HamtDataNode(hash, key, value), didAdd: false);
    }
    // Collision or different fragment: delegate to merge function
    return (
      node: _mergeDataEntriesHamt(
        shift,
        dataHash,
        dataKey,
        dataValue,
        hash,
        key,
        value,
        owner,
      ),
      didAdd: true,
    );
  }

  @override
  ({HamtNode<K, V> node, bool didRemove}) remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) =>
      (key == dataKey)
          ? (node: HamtEmptyNode<K, V>(), didRemove: true)
          : (node: this, didRemove: false);

  @override
  ({HamtNode<K, V> node, bool sizeChanged}) update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) {
    if (key == dataKey) {
      final newValue = updateFn(dataValue);
      return (newValue == dataValue)
          ? (node: this, sizeChanged: false)
          : (node: HamtDataNode(hash, key, newValue), sizeChanged: false);
    } else if (ifAbsentFn != null) {
      final newValue = ifAbsentFn();
      return (
        node: _mergeDataEntriesHamt(
          shift,
          dataHash,
          dataKey,
          dataValue,
          hash,
          key,
          newValue,
          owner,
        ),
        sizeChanged: true,
      );
    }
    return (node: this, sizeChanged: false);
  }
}

// --- Collision Node (Leaf with multiple colliding entries) ---

/// Represents a HAMT node containing multiple entries with the same hash up to a certain depth.
class HamtCollisionNode<K, V> extends HamtNode<K, V> {
  final int collisionHash;
  List<MapEntry<K, V>> entries; // Mutable if transient

  HamtCollisionNode(
    this.collisionHash,
    List<MapEntry<K, V>> entries, [
    TransientOwner? owner,
  ]) : entries =
           entries, // Direct assignment, mutability handled by ensureMutable/freeze
       assert(entries.length >= 2),
       super(owner);

  @override
  HamtNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      entries = List.unmodifiable(entries);
      _owner = null;
    }
    return this;
  }

  // Placeholder implementations - logic similar to ChampCollisionNode
  @override
  V? get(K key, int hash, int shift) {
    /* ... linear search ... */
    return null;
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    /* ... linear search ... */
    return false;
  }

  @override
  ({HamtNode<K, V> node, bool didAdd}) add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    // If hash differs, split using HamtBitmapNode.fromNodesHamt
    // If hash matches, add/update in entries list (handle transient/immutable)
    return (node: this, didAdd: false); // Placeholder
  }

  @override
  ({HamtNode<K, V> node, bool didRemove}) remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    // If hash matches, remove from entries list (handle transient/immutable)
    // If list size becomes 1, return HamtDataNode
    // If list size becomes 0, return HamtEmptyNode (Needs check)
    return (node: this, didRemove: false); // Placeholder
  }

  @override
  ({HamtNode<K, V> node, bool sizeChanged}) update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) {
    // Similar logic to add, handling updateFn and ifAbsentFn
    return (node: this, sizeChanged: false); // Placeholder
  }
}

// --- Bitmap Node (Internal node) ---

/// Abstract base class for HAMT nodes using a single bitmap.
abstract class HamtBitmapNode<K, V> extends HamtNode<K, V> {
  int bitmap; // Single bitmap indicating populated slots
  List<Object?> content; // Stores alternating K, V or HamtNode

  HamtBitmapNode(this.bitmap, this.content, [TransientOwner? owner])
    : super(owner);

  /// Calculates the sparse index for a given bit position.
  int sparseIndex(int bitpos) => bitCount(bitmap & (bitpos - 1));

  /// Calculates the index for a data key (K) in the content list.
  /// Assumes alternating K, V storage.
  int dataKeyIndex(int sparseIdx) => sparseIdx * 2;

  /// Calculates the index for a data value (V) in the content list.
  int dataValueIndex(int sparseIdx) => sparseIdx * 2 + 1;

  /// Calculates the index for a child node (HamtNode) in the content list.
  /// This depends on the storage strategy (e.g., all nodes after all data).
  /// Placeholder - needs concrete strategy.
  int nodeIndex(int sparseIdx, int dataCount) => dataCount * 2 + sparseIdx;

  // Factory needed to create initial bitmap node when merging/splitting
  // static HamtNode<K, V> fromEntriesHamt<K, V>(...) { ... }
}

// --- Concrete Bitmap Node Implementation ---
// For simplicity, using a single implementation that handles resizing internally.
// Could be split into Sparse/Array later if needed for optimization.
class HamtBitmapNodeImpl<K, V> extends HamtBitmapNode<K, V> {
  HamtBitmapNodeImpl(int bitmap, List<Object?> content, [TransientOwner? owner])
    : super(bitmap, content, owner);

  @override
  HamtNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // Freeze child nodes recursively
      for (int i = 0; i < content.length; i++) {
        final item = content[i];
        // Need logic to determine if item is a node based on bitmap and index
        // Placeholder: Assuming nodes are stored directly for now
        if (item is HamtNode<K, V>) {
          content[i] = item.freeze(owner);
        }
      }
      content = List.unmodifiable(content);
      _owner = null;
    }
    return this;
  }

  // Placeholder implementations for core operations
  @override
  V? get(K key, int hash, int shift) {
    /* ... HAMT lookup logic ... */
    return null;
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    /* ... HAMT lookup logic ... */
    return false;
  }

  @override
  ({HamtNode<K, V> node, bool didAdd}) add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    /* ... HAMT add logic ... */
    return (node: this, didAdd: false);
  }

  @override
  ({HamtNode<K, V> node, bool didRemove}) remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    /* ... HAMT remove logic ... */
    return (node: this, didRemove: false);
  }

  @override
  ({HamtNode<K, V> node, bool sizeChanged}) update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  }) {
    /* ... HAMT update logic ... */
    return (node: this, sizeChanged: false);
  }
}

// --- Helper for merging (HAMT version) ---
// Needs to be implemented based on the chosen HAMT storage strategy
HamtNode<K, V> _mergeDataEntriesHamt<K, V>(
  int shift,
  int hash1,
  K key1,
  V value1,
  int hash2,
  K key2,
  V value2,
  TransientOwner? owner,
) {
  if (shift >= kMaxDepth * kBitPartitionSize) {
    return HamtCollisionNode<K, V>(hash1, [
      MapEntry(key1, value1),
      MapEntry(key2, value2),
    ], owner);
  }

  final frag1 = indexFragment(shift, hash1);
  final frag2 = indexFragment(shift, hash2);

  if (frag1 == frag2) {
    final subNode = _mergeDataEntriesHamt(
      shift + kBitPartitionSize,
      hash1,
      key1,
      value1,
      hash2,
      key2,
      value2,
      owner,
    );
    final bitpos = 1 << frag1;
    // Create bitmap node with single child node
    // Storage strategy: Node stored directly at sparseIndex
    final content = [subNode];
    return HamtBitmapNodeImpl<K, V>(
      // Use renamed class
      bitpos,
      content,
      owner,
    );
  } else {
    final bitpos1 = 1 << frag1;
    final bitpos2 = 1 << frag2;
    final bitmap = bitpos1 | bitpos2;
    // Create bitmap node with two data entries
    // Storage strategy: Store [K, V] list directly at sparseIndex
    final List<Object?> content;
    if (frag1 < frag2) {
      // Store as lists within the content list
      content = [
        [key1, value1],
        [key2, value2],
      ];
    } else {
      // Store as lists within the content list
      content = [
        [key2, value2],
        [key1, value1],
      ];
    }
    return HamtBitmapNodeImpl<K, V>(
      bitmap,
      content,
      owner,
    ); // Use renamed class
  }
}
