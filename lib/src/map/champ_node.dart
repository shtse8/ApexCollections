/// Defines the core node structures for the Compressed Hash-Array Mapped Prefix Tree (CHAMP)
/// used internally by [ApexMap].
///
/// This library includes the abstract [ChampNode] base class and its concrete
/// implementations: [ChampEmptyNode], [ChampDataNode], [ChampCollisionNode],
/// [ChampSparseNode], and [ChampArrayNode]. It also defines constants related to the trie structure
/// (like [kBitPartitionSize]) and the [TransientOwner] mechanism for mutable operations.
library;

import 'dart:math';
import 'package:collection/collection.dart'; // For ListEquality used in CollisionNode
import 'package:meta/meta.dart';

// --- Constants ---

/// The number of bits used for each level (hash fragment) of the CHAMP trie.
/// A value of 5 means each node can have up to 2^5 = 32 children/data entries.
const int kBitPartitionSize = 5;

/// Bitmask used to extract the hash fragment for the current level.
/// Calculated as `(1 << kBitPartitionSize) - 1`.
const int kBitPartitionMask = (1 << kBitPartitionSize) - 1;

/// The maximum depth of the CHAMP trie, determined by the hash code size (32 bits)
/// and the partition size. `ceil(32 / 5) = 7`.
const int kMaxDepth = 7; // ceil(32 / 5) - Max depth based on 32-bit hash

/// Threshold for switching between Sparse and Array nodes.
const int kSparseNodeThreshold = 8;

// --- Top-Level Helper Functions for Index Calculation ---

/// Counts the number of set bits (1s) in an integer's binary representation.
/// Also known as the Hamming weight or population count (popcount).
/// Used for calculating indices within the node's content array based on bitmaps.
int bitCount(int i) {
  // Optimized bit count (popcount/Hamming weight) using SWAR for 32 bits.
  // Assumes input 'i' relevant bits fit within 32 (true for dataMap/nodeMap).
  i = i & 0xFFFFFFFF; // Ensure we operate on lower 32 bits
  i = i - ((i >> 1) & 0x55555555);
  i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
  i = (i + (i >> 4)) & 0x0F0F0F0F;
  i = i + (i >> 8);
  i = i + (i >> 16);
  return i & 0x3F; // Mask to get final count (0-32)
}

/// Extracts the relevant fragment (portion) of the [hash] code for a given [shift] level.
/// The [shift] determines which bits of the hash code are considered for this level.
int indexFragment(int shift, int hash) => (hash >> shift) & kBitPartitionMask;

/// Calculates the index within the data portion of the children/content list
/// corresponding to a given hash fragment [frag].
/// Requires the node's dataMap.
int dataIndexFromFragment(int frag, int dataMap) =>
    bitCount(dataMap & ((1 << frag) - 1));

/// Calculates the index within the node portion of the children/content list
/// corresponding to a given hash fragment [frag].
/// Requires the node's nodeMap.
int nodeIndexFromFragment(int frag, int nodeMap) =>
    bitCount(nodeMap & ((1 << frag) - 1));

/// Calculates the starting index in the children/content list for a data entry,
/// given its index within the conceptual data array ([dataIndex]).
int contentIndexFromDataIndex(int dataIndex) => dataIndex * 2;

/// Calculates the index in the children/content list for a child node,
/// given its index within the conceptual node array ([nodeIndex]).
/// Requires the node's dataMap to know where data entries end.
int contentIndexFromNodeIndex(int nodeIndex, int dataMap) =>
    (bitCount(dataMap) * 2) + nodeIndex; // Data entries come first

// --- Transient Ownership ---

/// A marker object used to track ownership during transient (mutable) operations
/// on CHAMP Trie nodes.
///
/// When performing bulk operations like `addAll` or `fromMap`, nodes can be
/// temporarily mutated in place if they share the same [TransientOwner]. This
/// avoids excessive copying and improves performance. Once the operation is
/// complete, the tree is "frozen" back into an immutable state using [ChampNode.freeze].
class TransientOwner {
  /// Creates a new unique owner instance.
  const TransientOwner();
}

// --- Node Base Class ---

/// Abstract base class for nodes in the Compressed Hash-Array Mapped Prefix Tree (CHAMP).
///
/// Nodes represent parts of the immutable map structure. They can be:
/// * [ChampEmptyNode]: Represents the canonical empty map.
/// * [ChampDataNode]: Represents a single key-value pair.
/// * [ChampCollisionNode]: Represents multiple entries with hash collisions at a certain depth.
/// * [ChampSparseNode] / [ChampArrayNode]: Represents a branch with multiple children (data or other nodes).
///
/// Nodes are immutable by default but support transient mutation via the
/// [TransientOwner] mechanism for performance optimization during bulk updates.
@immutable // Nodes are immutable by default unless transient
abstract class ChampNode<K, V> {
  /// Optional owner for transient nodes. If non-null, this node might be mutable
  /// by the holder of this specific [TransientOwner] instance.
  TransientOwner? _owner;

  /// Constructor for subclasses. Assigns an optional [owner] for transient state.
  ChampNode([this._owner]);

  /// Checks if the node is currently mutable and belongs to the given [owner].
  bool isTransient(TransientOwner? owner) => _owner != null && _owner == owner;

  /// Returns the value associated with the [key], or `null` if the key is not found
  /// within the subtree rooted at this node.
  ///
  /// - [hash]: The full hash code of the [key].
  /// - [shift]: The current bit shift level for hash fragment calculation.
  V? get(K key, int hash, int shift);

  /// Adds or updates a key-value pair within the subtree rooted at this node.
  ///
  /// - [key], [value]: The key-value pair to add/update.
  /// - [hash]: The full hash code of the [key].
  /// - [shift]: The current bit shift level.
  /// - [owner]: The [TransientOwner] if performing a mutable operation.
  ///
  /// Returns a [ChampAddResult] record containing:
  /// - `node`: The potentially new root node of the modified subtree.
  /// - `didAdd`: `true` if a new key was added, `false` if an existing key was updated.
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Removes a [key] from the subtree rooted at this node.
  ///
  /// - [key]: The key to remove.
  /// - [hash]: The full hash code of the [key].
  /// - [shift]: The current bit shift level.
  /// - [owner]: The [TransientOwner] if performing a mutable operation.
  ///
  /// Returns a [ChampRemoveResult] record containing:
  /// - `node`: The potentially new root node of the modified subtree (could be [ChampEmptyNode]).
  /// - `didRemove`: `true` if the key was found and removed, `false` otherwise.
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Updates the value associated with [key] in the subtree rooted at this node.
  ///
  /// - [key]: The key whose value to update.
  /// - [hash]: The full hash code of the [key].
  /// - [shift]: The current bit shift level.
  /// - [updateFn]: Function called with the current value if the key exists. Its return value becomes the new value.
  /// - [ifAbsentFn]: Optional function called if the key does *not* exist. Its return value is inserted as the new value.
  /// - [owner]: The [TransientOwner] if performing a mutable operation.
  ///
  /// Returns a [ChampUpdateResult] record containing:
  /// - `node`: The potentially new root node of the modified subtree.
  /// - `sizeChanged`: `true` if a new key was inserted via [ifAbsentFn], `false` otherwise.
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  });

  /// Checks if the [key] exists within the subtree rooted at this node.
  ///
  /// - [key]: The key to check for.
  /// - [hash]: The full hash code of the [key].
  /// - [shift]: The current bit shift level.
  ///
  /// Returns `true` if the key exists, `false` otherwise.
  bool containsKey(K key, int hash, int shift);

  /// Returns an immutable version of this node.
  ///
  /// If the node is transient and owned by the provided [owner], it recursively
  /// freezes its children (if any), clears its owner, makes its internal lists
  /// unmodifiable (if applicable), and returns itself. Otherwise, returns `this`.
  ChampNode<K, V> freeze(TransientOwner? owner);

  /// Helper to get the hash code of a key.
  /// Subclasses might override this if special key handling (like null) is needed.
  int hashOfKey(K key) => key.hashCode;

  /// Indicates if this is the canonical empty node.
  bool get isEmptyNode => false;
}

// --- Result Tuples (using Records for Dart 3+) ---

/// Record type returned by the [ChampNode.add] method.
typedef ChampAddResult<K, V> = ({ChampNode<K, V> node, bool didAdd});

/// Record type returned by the [ChampNode.remove] method.
typedef ChampRemoveResult<K, V> = ({ChampNode<K, V> node, bool didRemove});

/// Record type returned by the [ChampNode.update] method.
typedef ChampUpdateResult<K, V> = ({ChampNode<K, V> node, bool sizeChanged});

// --- Empty Node ---

/// Represents the single, canonical empty CHAMP node.
/// This is used as the starting point for an empty [ApexMap].
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
      final newNode = ChampDataNode<K, V>(hash, key, newValue);
      return (node: newNode, sizeChanged: true);
    }
    // Otherwise, no change
    return (node: this, sizeChanged: false);
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) => this; // Already immutable
}

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
      return (node: ChampDataNode(hash, key, value), didAdd: false);
    }

    // Collision: Create a new node (Bitmap or Collision) to merge the two entries.
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
      return (node: ChampDataNode(hash, key, newValue), sizeChanged: false);
    } else if (ifAbsentFn != null) {
      // Key not found, add using ifAbsentFn (results in merging)
      final newValue = ifAbsentFn();
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
}

// --- Collision Node ---

/// Represents a CHAMP node containing multiple entries that have the same hash code
/// up to a certain depth (i.e., their hash fragments collide at multiple levels).
/// Stores entries in a simple list and performs linear search within that list.
class ChampCollisionNode<K, V> extends ChampNode<K, V> {
  /// The hash code shared by all entries in this node.
  final int collisionHash;

  /// The list of colliding entries. Mutable only if the node is transient.
  List<MapEntry<K, V>> entries;

  /// Creates a collision node.
  ///
  /// - [collisionHash]: The common hash code.
  /// - [entries]: The list of entries with the colliding hash. Must contain at least 2 entries.
  /// - [owner]: Optional [TransientOwner] for mutability.
  ChampCollisionNode(
    this.collisionHash,
    List<MapEntry<K, V>> entries, [
    TransientOwner? owner,
  ]) : entries =
           entries, // Assign directly; immutability handled by returning new nodes
       assert(entries.length >= 2), // Must have at least 2 entries
       super(owner);

  @override
  V? get(K key, int hash, int shift) {
    // Only search if the hash matches the collision hash
    if (hash == collisionHash) {
      // Linear search through the colliding entries
      for (final entry in entries) {
        if (entry.key == key) {
          return entry.value;
        }
      }
    }
    return null; // Hash doesn't match or key not found in list
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    // Only search if the hash matches the collision hash
    if (hash == collisionHash) {
      // Linear search through the colliding entries
      for (final entry in entries) {
        if (entry.key == key) {
          return true;
        }
      }
    }
    return false; // Hash doesn't match or key not found in list
  }

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (hash != collisionHash) {
      // Hash differs, need to create a bitmap node to split this collision node
      // and the new data node based on their differing hash fragments at this level.
      final dataNode = ChampDataNode<K, V>(hash, key, value);
      // Use the static factory on ChampBitmapNode
      final newNode = ChampBitmapNode.fromNodes<K, V>(
        // Use static factory
        shift, // Create bitmap node at the current shift level
        collisionHash,
        this, // Existing collision node
        hash,
        dataNode, // New data node
        null, // Immutable operation when splitting
      );
      return (node: newNode, didAdd: true);
    }

    // Hash matches, add/update within the collision list
    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner); // Ensure mutable if owned
      final existingIndex = mutableNode.entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        if (mutableNode.entries[existingIndex].value == value) {
          return (node: mutableNode, didAdd: false); // No change
        }
        mutableNode.entries[existingIndex] = MapEntry(
          key,
          value,
        ); // Mutate in place
        return (node: mutableNode, didAdd: false);
      } else {
        // Add new entry
        mutableNode.entries.add(MapEntry(key, value)); // Mutate in place
        return (node: mutableNode, didAdd: true);
      }
    } else {
      // --- Immutable Path ---
      final existingIndex = entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        if (entries[existingIndex].value == value) {
          return (node: this, didAdd: false); // No change
        }
        // Create new list with updated entry
        final newEntries = List<MapEntry<K, V>>.of(entries);
        newEntries[existingIndex] = MapEntry(key, value);
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          didAdd: false,
        );
      } else {
        // Add new entry
        // Create new list with added entry
        final newEntries = List<MapEntry<K, V>>.of(entries)
          ..add(MapEntry(key, value));
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          didAdd: true,
        );
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
    if (hash != collisionHash) {
      return (node: this, didRemove: false); // Hash doesn't match
    }

    final mutableNode = ensureMutable(owner);
    final initialLength = mutableNode.entries.length;
    mutableNode.entries.removeWhere(
      (e) => e.key == key,
    ); // Mutate in place if transient
    final removed = mutableNode.entries.length < initialLength;

    if (!removed) {
      // Key not found, return original (potentially mutable) node
      return (node: mutableNode, didRemove: false);
    }

    // If only one entry remains, convert back to an immutable DataNode
    if (mutableNode.entries.length == 1) {
      final lastEntry = mutableNode.entries.first;
      final dataNode = ChampDataNode<K, V>(
        collisionHash,
        lastEntry.key,
        lastEntry.value,
      );
      return (node: dataNode, didRemove: true);
    }

    // Otherwise, return the modified (potentially mutable) collision node
    return (node: mutableNode, didRemove: true);
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
    if (hash != collisionHash) {
      // Hash doesn't match this collision node
      if (ifAbsentFn != null) {
        // Add as a new entry (will create an internal node to split)
        final newValue = ifAbsentFn();
        final dataNode = ChampDataNode<K, V>(hash, key, newValue);
        // Use the static factory on ChampBitmapNode
        final newNode = ChampBitmapNode.fromNodes<K, V>(
          // Use static factory
          shift,
          collisionHash,
          this,
          hash,
          dataNode,
          null, // Immutable operation
        );
        return (node: newNode, sizeChanged: true);
      }
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }

    // Hash matches, operate on the list
    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner);
      final existingIndex = mutableNode.entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        final currentValue = mutableNode.entries[existingIndex].value;
        final newValue = updateFn(currentValue);
        if (newValue == currentValue) {
          return (node: mutableNode, sizeChanged: false); // No change
        }
        mutableNode.entries[existingIndex] = MapEntry(
          key,
          newValue,
        ); // Mutate in place
        return (node: mutableNode, sizeChanged: false);
      } else if (ifAbsentFn != null) {
        // Key not found, add using ifAbsentFn
        final newValue = ifAbsentFn();
        mutableNode.entries.add(MapEntry(key, newValue)); // Mutate in place
        return (node: mutableNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: mutableNode, sizeChanged: false);
      }
    } else {
      // --- Immutable Path ---
      final existingIndex = entries.indexWhere((e) => e.key == key);
      if (existingIndex != -1) {
        // Update existing key
        final currentValue = entries[existingIndex].value;
        final newValue = updateFn(currentValue);
        if (newValue == currentValue) {
          return (node: this, sizeChanged: false); // No change
        }
        // Create new list with updated entry
        final newEntries = List<MapEntry<K, V>>.of(entries);
        newEntries[existingIndex] = MapEntry(key, newValue);
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          sizeChanged: false,
        );
      } else if (ifAbsentFn != null) {
        // Key not found, add using ifAbsentFn
        final newValue = ifAbsentFn();
        // Create new list with added entry
        final newEntries = List<MapEntry<K, V>>.of(entries)
          ..add(MapEntry(key, newValue));
        return (
          node: ChampCollisionNode<K, V>(collisionHash, newEntries), // New node
          sizeChanged: true,
        );
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  /// Returns this node if mutable and owned, otherwise a mutable copy.
  /// Used for transient operations.
  ChampCollisionNode<K, V> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy with the new owner
    return ChampCollisionNode<K, V>(
      collisionHash,
      List<MapEntry<K, V>>.of(entries, growable: true), // Mutable copy
      owner, // Assign the new owner
    );
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // Become immutable
      this._owner = null;
      this.entries = List.unmodifiable(entries); // Make list unmodifiable
      return this;
    }
    return this; // Already immutable or not owned
  }
}

// --- Bitmap Node Base Class ---

/// Abstract base class for CHAMP nodes that use bitmaps ([dataMap], [nodeMap])
/// to manage children (data entries or sub-nodes).
abstract class ChampBitmapNode<K, V> extends ChampNode<K, V> {
  /// Bitmap indicating which hash fragments correspond to data entries.
  int dataMap;

  /// Bitmap indicating which hash fragments correspond to child nodes.
  int nodeMap;

  /// Constructor for bitmap nodes.
  ChampBitmapNode(this.dataMap, this.nodeMap, [TransientOwner? owner])
    : super(owner);

  /// Calculates the total number of children (data entries + nodes).
  int get childCount => bitCount(dataMap) + bitCount(nodeMap);

  /// Factory constructor to create a suitable BitmapNode (Sparse or Array) from two initial child nodes
  /// that have different hash fragments at the current [shift] level.
  /// Used when merging data entries or splitting collision nodes.
  /// Creates a transient node if an [owner] is provided.
  static ChampBitmapNode<K, V> fromNodes<K, V>(
    // Add type parameters here
    int shift,
    int hash1,
    ChampNode<K, V> node1,
    int hash2,
    ChampNode<K, V> node2,
    TransientOwner? owner,
  ) {
    final frag1 = indexFragment(shift, hash1);
    final frag2 = indexFragment(shift, hash2);

    assert(frag1 != frag2, 'Hash fragments must differ for fromNodes');

    final bitpos1 = 1 << frag1;
    final bitpos2 = 1 << frag2;
    final newNodeMap = bitpos1 | bitpos2;
    final dataMap = 0; // Starts with only nodes

    // Order nodes based on fragment index for consistent content layout
    final List<Object?> children;
    if (frag1 < frag2) {
      children = [node1, node2];
    } else {
      children = [node2, node1];
    }

    // Decide whether to create Sparse or Array node based on initial count (which is 2)
    if (2 <= kSparseNodeThreshold) {
      return ChampSparseNode<K, V>(dataMap, newNodeMap, children, owner);
    } else {
      // This case shouldn't happen if threshold > 2, but included for completeness
      return ChampArrayNode<K, V>(dataMap, newNodeMap, children, owner);
    }
  }

  // --- Core Methods ---
  // Implement abstract methods from ChampNode
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
  @override
  ChampNode<K, V> freeze(TransientOwner? owner);

  // --- Transient Helper Methods ---
  /// Returns this node if it's mutable and owned by [owner],
  /// otherwise returns a new mutable copy owned by [owner].
  /// Used for transient operations.
  ChampBitmapNode<K, V> ensureMutable(TransientOwner? owner);
} // End of ChampBitmapNode

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

  // --- In-place mutation helpers (SparseNode) ---

  /// Inserts a data entry into the `children` list. Updates `dataMap`. Assumes transient.
  void _insertDataEntryInPlace(int dataIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    children.insertAll(dataPayloadIndex, [key, value]);
    dataMap |= bitpos;
  }

  /// Removes a data entry from the `children` list. Updates `dataMap`. Assumes transient.
  void _removeDataEntryInPlace(int dataIndex, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    children.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    dataMap ^= bitpos;
  }

  /// Removes a child node entry from the `children` list. Updates `nodeMap`. Assumes transient.
  void _removeNodeEntryInPlace(int nodeIndex, int bitpos) {
    assert(isTransient(_owner));
    final contentNodeIndex = contentIndexFromNodeIndex(nodeIndex, dataMap);
    children.removeAt(contentNodeIndex);
    nodeMap ^= bitpos;
  }

  /// Replaces a data entry with a sub-node in place. Updates bitmaps. Assumes transient.
  void _replaceDataWithNodeInPlace(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    assert(isTransient(_owner));
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    final frag = bitCount(bitpos - 1); // Fragment index of the new node
    final targetNodeMap =
        nodeMap | bitpos; // Node map *after* adding the new node bit
    final targetNodeIndex = bitCount(
      targetNodeMap & (bitpos - 1),
    ); // Nodes before the new one
    // Node section starts after remaining data entries
    final nodeInsertPos = (bitCount(dataMap) - 1) * 2 + targetNodeIndex;

    // Modify children list
    children.removeRange(
      dataPayloadIndex,
      dataPayloadIndex + 2,
    ); // Remove old data
    if (nodeInsertPos > children.length) {
      children.add(subNode); // Append if at the end
    } else {
      children.insert(nodeInsertPos, subNode); // Insert in the middle
    }

    // Update bitmaps
    dataMap ^= bitpos; // Remove data bit
    nodeMap |= bitpos; // Add node bit
  }

  /// Replaces a node entry with a data entry in place. Updates bitmaps. Assumes transient.
  void _replaceNodeWithDataInPlace(int nodeIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final frag = bitCount(bitpos - 1); // Fragment for the new data
    final targetDataMap =
        dataMap | bitpos; // dataMap *after* adding the new data bit
    final targetDataIndex = dataIndexFromFragment(frag, targetDataMap);
    final dataPayloadIndex = contentIndexFromDataIndex(targetDataIndex);
    final nodeContentIndex = contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    ); // Index of node to remove

    // Remove the node entry
    children.removeAt(nodeContentIndex);
    // Insert the data entry (key, value) at the correct position
    children.insertAll(dataPayloadIndex, [key, value]);

    // Update bitmaps
    dataMap |= bitpos; // Add data bit
    nodeMap ^= bitpos; // Remove node bit
  }

  /// Checks if the node needs shrinking/collapsing after a removal and performs it (in place).
  /// Returns the potentially new node (e.g., if collapsed).
  /// Assumes the node is transient and owned.
  ChampNode<K, V>? _shrinkIfNeeded(TransientOwner? owner) {
    assert(isTransient(owner));
    final currentChildCount = childCount;

    // Condition 1: Collapse to EmptyNode
    if (currentChildCount == 0) {
      assert(dataMap == 0 && nodeMap == 0);
      return ChampEmptyNode<K, V>();
    }

    // Condition 2: Collapse to DataNode
    if (currentChildCount == 1 && nodeMap == 0) {
      assert(bitCount(dataMap) == 1);
      final key = children[0] as K;
      final value = children[1] as V;
      return ChampDataNode<K, V>(
        hashOfKey(key),
        key,
        value,
      ); // Return immutable DataNode
    }

    // Condition 3: Collapse to single sub-node
    if (currentChildCount == 1 && dataMap == 0) {
      assert(bitCount(nodeMap) == 1);
      return children[0] as ChampNode<K, V>; // Return the sub-node
    }

    // No shrinking/collapsing needed, return this (mutable) SparseNode
    return this;
  }

  // --- Immutable Helper (SparseNode) ---

  /// Creates a new node replacing a data entry with a sub-node immutably.
  /// Handles potential transition to ArrayNode.
  ChampNode<K, V> _replaceDataWithNodeImmutable(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    final dataPayloadIndex = dataIndex * 2;
    final dataCount = bitCount(dataMap);
    final nodeCount = bitCount(nodeMap);
    final newChildCount =
        (dataCount - 1) + (nodeCount + 1); // Calculate new count
    final newNodeStartIndex =
        (dataCount - 1) * 2; // Start index for nodes in new list

    // Create the new children list
    final newChildren = List<Object?>.filled(
      newNodeStartIndex + (nodeCount + 1),
      null,
      growable: false,
    );

    // --- Copy elements into newChildren ---
    // Copy data before the replaced entry
    if (dataIndex > 0) newChildren.setRange(0, dataPayloadIndex, children, 0);
    // Copy data after the replaced entry
    if (dataIndex < dataCount - 1) {
      newChildren.setRange(
        dataPayloadIndex,
        newNodeStartIndex,
        children,
        dataPayloadIndex + 2,
      );
    }

    // Calculate insertion position for the new subNode
    final frag = bitCount(bitpos - 1);
    final targetNodeMap = nodeMap | bitpos;
    final targetNodeIndex = bitCount(targetNodeMap & (bitpos - 1));
    final nodeInsertPos = newNodeStartIndex + targetNodeIndex;

    // Copy existing nodes around the insertion point
    if (nodeCount > 0) {
      final oldNodeStartIndex = dataCount * 2;
      // Copy nodes before insertion point
      if (targetNodeIndex > 0) {
        newChildren.setRange(
          newNodeStartIndex,
          nodeInsertPos,
          children,
          oldNodeStartIndex,
        );
      }
      // Copy nodes after insertion point
      if (targetNodeIndex < nodeCount) {
        newChildren.setRange(
          nodeInsertPos + 1,
          newChildren.length,
          children,
          oldNodeStartIndex + targetNodeIndex,
        );
      }
    }
    // Insert the new subNode
    newChildren[nodeInsertPos] = subNode;
    // --- End Copy ---

    final newDataMap = dataMap ^ bitpos; // Remove data bit
    final newNodeMap = nodeMap | bitpos; // Add node bit

    // Decide if new node should be Sparse or Array based on the *new* count
    if (newChildCount > kSparseNodeThreshold) {
      return ChampArrayNode<K, V>(newDataMap, newNodeMap, newChildren);
    } else {
      // Use _createImmutableNode logic for potential collapse (already handles sparse case)
      return _createImmutableNode(newDataMap, newNodeMap, newChildren);
    }
  }

  /// Helper to create the correct immutable node type (Sparse, Array, Data, Empty)
  /// based on the final child count after an immutable operation.
  /// Assumes the caller has already calculated the final bitmaps and content.
  ChampNode<K, V> _createImmutableNode(
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
        return ChampDataNode<K, V>(hashOfKey(key), key, value);
      } else {
        // Collapse to single sub-node (return the sub-node directly)
        return newContent[0] as ChampNode<K, V>;
      }
    }

    // Check threshold *before* creating node
    if (childCount <= kSparseNodeThreshold) {
      // Stay or become SparseNode
      return ChampSparseNode<K, V>(newDataMap, newNodeMap, newContent);
    } else {
      // Transition to ArrayNode
      return ChampArrayNode<K, V>(newDataMap, newNodeMap, newContent);
    }
  }

  // --- Transient Add Helpers (SparseNode) ---

  ChampAddResult<K, V> _addTransientDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;
    final currentValue = children[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      children[payloadIndex + 1] = value; // Mutate in place
      return (node: this, didAdd: false);
    } else {
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hashOfKey(currentKey),
        currentKey,
        currentValue,
        hash,
        key,
        value,
        owner,
      );
      _replaceDataWithNodeInPlace(
        dataIndex,
        subNode,
        bitpos,
      ); // Mutate in place
      // No transition check needed here, count doesn't change
      return (node: this, didAdd: true);
    }
  }

  ChampAddResult<K, V> _addTransientDelegate(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = children[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (identical(addResult.node, subNode))
      return (node: this, didAdd: addResult.didAdd);

    children[contentIdx] = addResult.node; // Update content in place
    // No transition check needed here, count doesn't change relative to this node
    return (node: this, didAdd: addResult.didAdd);
  }

  ChampAddResult<K, V> _addTransientEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
    TransientOwner owner, // Added owner
  ) {
    assert(isTransient(owner)); // Use owner
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    _insertDataEntryInPlace(dataIndex, key, value, bitpos); // Mutate in place

    // Check for transition Sparse -> Array
    if (childCount > kSparseNodeThreshold) {
      // Create ArrayNode, passing the current mutable children list and owner
      return (
        node: ChampArrayNode<K, V>(dataMap, nodeMap, children, owner),
        didAdd: true,
      );
    }
    // Remain SparseNode
    return (node: this, didAdd: true);
  }

  // --- Immutable Add Helpers (SparseNode) ---

  ChampAddResult<K, V> _addImmutableDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;
    final currentValue = children[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      // Create new children list with updated value (Manual Copy Optimization)
      final len = children.length;
      final newChildren = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newChildren[i] = children[i];
      }
      newChildren[payloadIndex + 1] = value; // Update the specific value
      // Count doesn't change, stays SparseNode
      return (
        node: ChampSparseNode<K, V>(dataMap, nodeMap, newChildren),
        didAdd: false,
      );
    } else {
      // Hash collision, different keys -> create sub-node
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hashOfKey(currentKey),
        currentKey,
        currentValue,
        hash,
        key,
        value,
        null, // Immutable merge
      );
      // Create new node replacing data with sub-node
      final newNode = _replaceDataWithNodeImmutable(dataIndex, subNode, bitpos);
      return (node: newNode, didAdd: true);
    }
  }

  ChampAddResult<K, V> _addImmutableDelegate(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = children[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      null,
    ); // Immutable add

    if (identical(addResult.node, subNode))
      return (node: this, didAdd: addResult.didAdd); // No change

    // Create new children list with updated sub-node
    final newChildren = List<Object?>.of(children);
    newChildren[contentIdx] = addResult.node;
    // Count doesn't change, stays SparseNode (no transition check needed)
    return (
      node: ChampSparseNode<K, V>(dataMap, nodeMap, newChildren),
      didAdd: addResult.didAdd,
    );
  }

  ChampAddResult<K, V> _addImmutableEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = dataIndex * 2;
    // Create new children list with inserted entry
    final newChildren = List<Object?>.of(children)
      ..insertAll(payloadIndex, [key, value]);
    final newDataMap = dataMap | bitpos;
    final newChildCount = childCount + 1; // Calculate new count

    // Check for transition Sparse -> Array
    if (newChildCount > kSparseNodeThreshold) {
      return (
        node: ChampArrayNode<K, V>(newDataMap, nodeMap, newChildren),
        didAdd: true,
      );
    } else {
      return (
        node: ChampSparseNode<K, V>(newDataMap, nodeMap, newChildren),
        didAdd: true,
      );
    }
  }

  // --- Transient Remove Helpers (SparseNode) ---

  ChampRemoveResult<K, V> _removeTransientData(
    K key,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (children[payloadIndex] == key) {
      // Found the key to remove
      _removeDataEntryInPlace(dataIndex, bitpos); // Mutate in place
      // Check if node needs shrinking/collapsing (Sparse version)
      final newNode = _shrinkIfNeeded(owner);
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> _removeTransientDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = children[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    // Sub-node changed, update content in place
    children[contentIdx] = removeResult.node;

    // Check if the sub-node became empty or needs merging
    if (removeResult.node.isEmptyNode) {
      _removeNodeEntryInPlace(nodeIndex, bitpos); // Mutate in place
      final newNode = _shrinkIfNeeded(owner); // Check for collapse
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // If sub-node collapsed to a data node, replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      _replaceNodeWithDataInPlace(
        nodeIndex,
        dataNode.dataKey,
        dataNode.dataValue,
        bitpos,
      ); // Mutate in place
      // No need to shrink here as count didn't change, stays Sparse
      return (node: this, didRemove: true);
    }
    // Sub-node modified but not removed/collapsed, return mutable node
    return (node: this, didRemove: true);
  }

  // --- Immutable Remove Helpers (SparseNode) ---

  ChampRemoveResult<K, V> _removeImmutableData(K key, int frag, int bitpos) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (children[payloadIndex] == key) {
      // Found the key to remove
      final newDataMap = dataMap ^ bitpos;
      if (newDataMap == 0 && nodeMap == 0)
        return (node: ChampEmptyNode<K, V>(), didRemove: true);

      // Create new list with data entry removed
      final newChildren = List<Object?>.of(children)
        ..removeRange(payloadIndex, payloadIndex + 2);
      // Create new node (will be Sparse or simpler)
      final newNode = _createImmutableNode(newDataMap, nodeMap, newChildren);
      return (node: newNode, didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> _removeImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = children[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      null,
    ); // Immutable remove

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    // Sub-node changed, create new node with updated sub-node
    final newChildren = List<Object?>.of(children);
    newChildren[contentIdx] = removeResult.node;

    if (removeResult.node.isEmptyNode) {
      // Remove the empty sub-node entry
      final newNodeMap = nodeMap ^ bitpos;
      newChildren.removeAt(contentIdx); // Remove from the copied list
      if (dataMap == 0 && newNodeMap == 0)
        return (node: ChampEmptyNode<K, V>(), didRemove: true);
      // Create new node (will be Sparse or simpler)
      final newNode = _createImmutableNode(dataMap, newNodeMap, newChildren);
      return (node: newNode, didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // Replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      final newDataMap = dataMap | bitpos;
      final newNodeMap = nodeMap ^ bitpos;
      final dataPayloadIndex = dataIndexFromFragment(frag, newDataMap) * 2;

      // Create new content list: copy old data, insert new data, copy old nodes (excluding replaced one)
      final newDataCount = bitCount(newDataMap);
      final newNodeCount = bitCount(newNodeMap);
      final newChildrenList = List<Object?>.filled(
        newDataCount * 2 + newNodeCount,
        null,
      );

      // Copy data before insertion point
      if (dataPayloadIndex > 0)
        newChildrenList.setRange(0, dataPayloadIndex, children, 0);
      // Insert new data
      newChildrenList[dataPayloadIndex] = dataNode.dataKey;
      newChildrenList[dataPayloadIndex + 1] = dataNode.dataValue;
      // Copy data after insertion point
      final oldDataEnd = bitCount(dataMap) * 2;
      if (dataPayloadIndex < oldDataEnd) {
        newChildrenList.setRange(
          dataPayloadIndex + 2,
          newDataCount * 2,
          children,
          dataPayloadIndex,
        );
      }

      // Copy nodes before removed node
      final oldNodeStartIndex = bitCount(dataMap) * 2;
      final newNodeStartIndex = newDataCount * 2;
      if (nodeIndex > 0) {
        newChildrenList.setRange(
          newNodeStartIndex,
          newNodeStartIndex + nodeIndex,
          children,
          oldNodeStartIndex,
        );
      }
      // Copy nodes after removed node
      if (nodeIndex < bitCount(nodeMap) - 1) {
        newChildrenList.setRange(
          newNodeStartIndex + nodeIndex,
          newNodeStartIndex + newNodeCount,
          children,
          oldNodeStartIndex + nodeIndex + 1,
        );
      }

      // Create new node (will be Sparse or simpler)
      final newNode = _createImmutableNode(
        newDataMap,
        newNodeMap,
        newChildrenList,
      );
      return (node: newNode, didRemove: true);
    }
    // Sub-node modified but not removed/collapsed, stays Sparse
    return (
      node: ChampSparseNode<K, V>(dataMap, nodeMap, newChildren),
      didRemove: true,
    );
  }

  // --- Transient Update Helpers (SparseNode) ---

  ChampUpdateResult<K, V> _updateTransientData(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value in place
      final currentValue = children[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      children[payloadIndex + 1] = updatedValue; // Mutate value in place
      return (node: this, sizeChanged: false);
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = children[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hashOfKey(currentKey),
          currentKey,
          currentVal,
          hash,
          key,
          newValue,
          owner,
        );
        _replaceDataWithNodeInPlace(
          dataIndex,
          subNode,
          bitpos,
        ); // Mutate in place
        // No transition check needed here, count doesn't change
        return (node: this, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> _updateTransientDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = children[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: owner,
    );

    if (identical(updateResult.node, subNode))
      return (node: this, sizeChanged: updateResult.sizeChanged);

    // Update children array in place
    children[contentIdx] = updateResult.node;
    // No transition check needed here, count doesn't change relative to this node
    return (node: this, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> _updateTransientEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
    TransientOwner owner, // Added owner
  ) {
    assert(isTransient(owner)); // Use owner
    if (ifAbsentFn != null) {
      // Insert new data entry using ifAbsentFn (in place)
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      _insertDataEntryInPlace(
        dataIndex,
        key,
        newValue,
        bitpos,
      ); // Mutate in place

      // Check for transition Sparse -> Array
      if (childCount > kSparseNodeThreshold) {
        // Create ArrayNode, passing the current mutable children list and owner
        return (
          node: ChampArrayNode<K, V>(dataMap, nodeMap, children, owner),
          sizeChanged: true,
        );
      }
      // Remain SparseNode
      return (node: this, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // --- Immutable Update Helpers (SparseNode) ---

  ChampUpdateResult<K, V> _updateImmutableData(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = children[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value
      final currentValue = children[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      // Create new node with updated value (Manual Copy Optimization)
      final len = children.length;
      final newChildren = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newChildren[i] = children[i];
      }
      newChildren[payloadIndex + 1] = updatedValue; // Update the specific value
      // Count doesn't change, stays SparseNode
      return (
        node: ChampSparseNode<K, V>(dataMap, nodeMap, newChildren),
        sizeChanged: false,
      );
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = children[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hashOfKey(currentKey),
          currentKey,
          currentVal,
          hash,
          key,
          newValue,
          null, // Immutable merge
        );
        // Create new node replacing data with sub-node
        final newNode = _replaceDataWithNodeImmutable(
          dataIndex,
          subNode,
          bitpos,
        );
        return (node: newNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> _updateImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = children[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: null,
    );

    if (identical(updateResult.node, subNode))
      return (node: this, sizeChanged: updateResult.sizeChanged);

    // Create new node with updated sub-node
    final newChildren = List<Object?>.of(children);
    newChildren[contentIdx] = updateResult.node;
    // Count doesn't change, stays SparseNode
    return (
      node: ChampSparseNode<K, V>(dataMap, nodeMap, newChildren),
      sizeChanged: updateResult.sizeChanged,
    );
  }

  ChampUpdateResult<K, V> _updateImmutableEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
  ) {
    if (ifAbsentFn != null) {
      // Insert new data entry using ifAbsentFn
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final payloadIndex = dataIndex * 2;
      // Create new children list with inserted entry
      final newChildren = List<Object?>.of(children)
        ..insertAll(payloadIndex, [key, newValue]);
      final newDataMap = dataMap | bitpos;
      final newChildCount = childCount + 1; // Calculate new count

      // Check for transition Sparse -> Array
      if (newChildCount > kSparseNodeThreshold) {
        return (
          node: ChampArrayNode<K, V>(newDataMap, nodeMap, newChildren),
          sizeChanged: true,
        );
      } else {
        return (
          node: ChampSparseNode<K, V>(newDataMap, nodeMap, newChildren),
          sizeChanged: true,
        );
      }
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // Implement abstract methods from ChampNode/ChampBitmapNode
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
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
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
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
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
        return _addTransientDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _addTransientDelegate(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else {
        return _addTransientEmptySlot(key, value, frag, bitpos, owner!);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _addImmutableDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _addImmutableDelegate(key, value, hash, shift, frag, bitpos);
      } else {
        return _addImmutableEmptySlot(key, value, frag, bitpos);
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
        return _removeTransientData(key, frag, bitpos, owner!);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeTransientDelegate(key, hash, shift, frag, bitpos, owner!);
      }
      return (node: this, didRemove: false); // Key not found
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _removeImmutableData(key, frag, bitpos);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeImmutableDelegate(key, hash, shift, frag, bitpos);
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
        return _updateTransientData(
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
        return _updateTransientDelegate(
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
        return _updateTransientEmptySlot(key, frag, bitpos, ifAbsentFn, owner!);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _updateImmutableData(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _updateImmutableDelegate(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else {
        return _updateImmutableEmptySlot(key, frag, bitpos, ifAbsentFn);
      }
    }
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      final nodeCount = bitCount(nodeMap);
      final dataSlots = bitCount(dataMap) * 2;
      // Freeze child nodes recursively
      for (int i = 0; i < nodeCount; i++) {
        final nodeIndex = dataSlots + i;
        final subNode =
            children[nodeIndex] as ChampNode<K, V>; // Use 'children'
        children[nodeIndex] = subNode.freeze(owner); // Freeze recursively
      }
      this._owner = null; // Clear owner
      this.children = List.unmodifiable(children); // Make list unmodifiable
      return this;
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
} // End of ChampSparseNode

// --- Array Node Implementation ---
// (This was missing and caused the errors)
class ChampArrayNode<K, V> extends ChampBitmapNode<K, V> {
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

  // --- In-place mutation helpers (ArrayNode) ---

  /// Inserts a data entry into the `content` list. Updates `dataMap`. Assumes transient.
  void _insertDataEntryInPlace(int dataIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    content.insertAll(dataPayloadIndex, [key, value]);
    dataMap |= bitpos;
  }

  /// Removes a data entry from the `content` list. Updates `dataMap`. Assumes transient.
  void _removeDataEntryInPlace(int dataIndex, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    dataMap ^= bitpos;
  }

  /// Removes a child node entry from the `content` list. Updates `nodeMap`. Assumes transient.
  void _removeNodeEntryInPlace(int nodeIndex, int bitpos) {
    assert(isTransient(_owner));
    final contentNodeIndex = contentIndexFromNodeIndex(nodeIndex, dataMap);
    content.removeAt(contentNodeIndex);
    nodeMap ^= bitpos;
  }

  /// Replaces a data entry with a sub-node in place. Updates bitmaps. Assumes transient.
  void _replaceDataWithNodeInPlace(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    assert(isTransient(_owner));
    final dataPayloadIndex = contentIndexFromDataIndex(dataIndex);
    final frag = bitCount(bitpos - 1); // Fragment index of the new node
    final targetNodeMap =
        nodeMap | bitpos; // Node map *after* adding the new node bit
    final targetNodeIndex = bitCount(
      targetNodeMap & (bitpos - 1),
    ); // Nodes before the new one
    // Node section starts after remaining data entries
    final nodeInsertPos = (bitCount(dataMap) - 1) * 2 + targetNodeIndex;

    // Modify content list
    content.removeRange(
      dataPayloadIndex,
      dataPayloadIndex + 2,
    ); // Remove old data
    if (nodeInsertPos > content.length) {
      content.add(subNode); // Append if at the end
    } else {
      content.insert(nodeInsertPos, subNode); // Insert in the middle
    }

    // Update bitmaps
    dataMap ^= bitpos; // Remove data bit
    nodeMap |= bitpos; // Add node bit
  }

  /// Replaces a node entry with a data entry in place. Updates bitmaps. Assumes transient.
  void _replaceNodeWithDataInPlace(int nodeIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final frag = bitCount(bitpos - 1); // Fragment for the new data
    final targetDataMap =
        dataMap | bitpos; // dataMap *after* adding the new data bit
    final targetDataIndex = dataIndexFromFragment(frag, targetDataMap);
    final dataPayloadIndex = contentIndexFromDataIndex(targetDataIndex);
    final nodeContentIndex = contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    ); // Index of node to remove

    // Remove the node entry
    content.removeAt(nodeContentIndex);
    // Insert the data entry (key, value) at the correct position
    content.insertAll(dataPayloadIndex, [key, value]);

    // Update bitmaps
    dataMap |= bitpos; // Add data bit
    nodeMap ^= bitpos; // Remove node bit
  }

  /// Checks if the node needs shrinking or transitioning after a removal and performs it (in place).
  /// Returns the potentially new node (e.g., if collapsed or transitioned).
  /// Assumes the node is transient and owned.
  ChampNode<K, V>? _shrinkOrTransitionIfNeeded(TransientOwner? owner) {
    assert(isTransient(owner)); // Should only be called transiently

    final currentChildCount = childCount;

    // Condition 1: Collapse to EmptyNode
    if (currentChildCount == 0) {
      assert(dataMap == 0 && nodeMap == 0);
      return ChampEmptyNode<K, V>();
    }

    // Condition 2: Collapse to DataNode
    if (currentChildCount == 1 && nodeMap == 0) {
      assert(bitCount(dataMap) == 1);
      final key = content[0] as K; // Use 'content'
      final value = content[1] as V; // Use 'content'
      return ChampDataNode<K, V>(
        hashOfKey(key),
        key,
        value,
      ); // Return immutable DataNode
    }

    // Condition 3: Collapse to single sub-node
    if (currentChildCount == 1 && dataMap == 0) {
      assert(bitCount(nodeMap) == 1);
      return content[0]
          as ChampNode<K, V>; // Return the sub-node from 'content'
    }

    // Condition 4: Transition from ArrayNode to SparseNode
    if (currentChildCount <= kSparseNodeThreshold) {
      // Convert this ArrayNode content to a SparseNode
      return ChampSparseNode<K, V>(
        dataMap,
        nodeMap,
        content, // Pass the existing (mutable) list
        owner, // Keep the owner
      );
    }

    // No shrinking or transition needed, return this (mutable) ArrayNode
    return this;
  }

  // --- Immutable Helper (ArrayNode) ---

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
    final newChildCount =
        (dataCount - 1) + (nodeCount + 1); // Calculate new count
    final newNodeStartIndex =
        (dataCount - 1) * 2; // Start index for nodes in new list

    // Create the new content list
    final newContent = List<Object?>.filled(
      newNodeStartIndex + (nodeCount + 1),
      null,
      growable: false,
    );

    // --- Copy elements into newContent ---
    // Copy data before the replaced entry
    if (dataIndex > 0) newContent.setRange(0, dataPayloadIndex, content, 0);
    // Copy data after the replaced entry
    if (dataIndex < dataCount - 1) {
      newContent.setRange(
        dataPayloadIndex,
        newNodeStartIndex,
        content,
        dataPayloadIndex + 2,
      );
    }

    // Calculate insertion position for the new subNode
    final frag = bitCount(bitpos - 1);
    final targetNodeMap = nodeMap | bitpos;
    final targetNodeIndex = bitCount(targetNodeMap & (bitpos - 1));
    final nodeInsertPos = newNodeStartIndex + targetNodeIndex;

    // Copy existing nodes around the insertion point
    if (nodeCount > 0) {
      final oldNodeStartIndex = dataCount * 2;
      // Copy nodes before insertion point
      if (targetNodeIndex > 0) {
        newContent.setRange(
          newNodeStartIndex,
          nodeInsertPos,
          content,
          oldNodeStartIndex,
        );
      }
      // Copy nodes after insertion point
      if (targetNodeIndex < nodeCount) {
        newContent.setRange(
          nodeInsertPos + 1,
          newContent.length,
          content,
          oldNodeStartIndex + targetNodeIndex,
        );
      }
    }
    // Insert the new subNode
    newContent[nodeInsertPos] = subNode;
    // --- End Copy ---

    final newDataMap = dataMap ^ bitpos; // Remove data bit
    final newNodeMap = nodeMap | bitpos; // Add node bit

    // Decide if new node should be Sparse or Array based on the *new* count
    return _createImmutableNode(newDataMap, newNodeMap, newContent);
  }

  /// Helper to create the correct immutable node type (Sparse, Array, Data, Empty)
  /// based on the final child count after an immutable operation.
  /// Assumes the caller has already calculated the final bitmaps and content.
  ChampNode<K, V> _createImmutableNode(
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
        return ChampDataNode<K, V>(hashOfKey(key), key, value);
      } else {
        // Collapse to single sub-node (return the sub-node directly)
        return newContent[0] as ChampNode<K, V>;
      }
    }

    // Check threshold *before* creating node
    if (childCount <= kSparseNodeThreshold) {
      // Transition to SparseNode
      return ChampSparseNode<K, V>(newDataMap, newNodeMap, newContent);
    } else {
      // Stay ArrayNode
      return ChampArrayNode<K, V>(newDataMap, newNodeMap, newContent);
    }
  }

  // --- Implement abstract methods from ChampNode/ChampBitmapNode ---
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
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
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
      final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
      final subNode = content[contentIdx] as ChampNode<K, V>; // Use 'content'
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
        return _addTransientDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _addTransientDelegate(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner!,
        );
      } else {
        return _addTransientEmptySlot(key, value, frag, bitpos);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _addImmutableDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _addImmutableDelegate(key, value, hash, shift, frag, bitpos);
      } else {
        return _addImmutableEmptySlot(key, value, frag, bitpos);
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
        return _removeTransientData(key, frag, bitpos, owner!);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeTransientDelegate(key, hash, shift, frag, bitpos, owner!);
      }
      return (node: this, didRemove: false); // Key not found
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _removeImmutableData(key, frag, bitpos);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeImmutableDelegate(key, hash, shift, frag, bitpos);
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
        return _updateTransientData(
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
        return _updateTransientDelegate(
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
        return _updateTransientEmptySlot(key, frag, bitpos, ifAbsentFn);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _updateImmutableData(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else if ((nodeMap & bitpos) != 0) {
        return _updateImmutableDelegate(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
        );
      } else {
        return _updateImmutableEmptySlot(key, frag, bitpos, ifAbsentFn);
      }
    }
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      final nodeCount = bitCount(nodeMap);
      final dataSlots = bitCount(dataMap) * 2;
      // Freeze child nodes recursively
      for (int i = 0; i < nodeCount; i++) {
        final nodeIndex = dataSlots + i;
        final subNode = content[nodeIndex] as ChampNode<K, V>; // Use 'content'
        content[nodeIndex] = subNode.freeze(owner); // Freeze recursively
      }
      this._owner = null; // Clear owner
      this.content = List.unmodifiable(content); // Make list unmodifiable
      return this;
    }
    return this; // Already immutable or not owned
  }

  @override
  ChampBitmapNode<K, V> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy with the new owner
    return ChampArrayNode<K, V>(
      dataMap,
      nodeMap,
      List.of(content, growable: true), // Create mutable copy of 'content'
      owner,
    );
  }

  // --- Transient Add Helpers (ArrayNode) ---
  // (These were previously misplaced inside SparseNode)
  ChampAddResult<K, V> _addTransientDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;
    final currentValue = content[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      content[payloadIndex + 1] = value; // Mutate in place
      return (node: this, didAdd: false);
    } else {
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hashOfKey(currentKey),
        currentKey,
        currentValue,
        hash,
        key,
        value,
        owner,
      );
      _replaceDataWithNodeInPlace(
        dataIndex,
        subNode,
        bitpos,
      ); // Mutate in place
      return (node: this, didAdd: true);
    }
  }

  ChampAddResult<K, V> _addTransientDelegate(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (identical(addResult.node, subNode))
      return (node: this, didAdd: addResult.didAdd);

    content[contentIdx] = addResult.node; // Update content in place
    return (node: this, didAdd: addResult.didAdd);
  }

  ChampAddResult<K, V> _addTransientEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
  ) {
    assert(isTransient(_owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    _insertDataEntryInPlace(dataIndex, key, value, bitpos); // Mutate in place
    // ArrayNode never transitions back to Sparse on add
    return (node: this, didAdd: true);
  }

  // --- Immutable Add Helpers (ArrayNode) ---

  ChampAddResult<K, V> _addImmutableDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;
    final currentValue = content[payloadIndex + 1] as V;

    if (currentKey == key) {
      if (currentValue == value) return (node: this, didAdd: false);
      // Create new content list with updated value (Manual Copy Optimization)
      final len = content.length;
      final newContent = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newContent[i] = content[i];
      }
      newContent[payloadIndex + 1] = value; // Update the specific value
      return (
        node: ChampArrayNode<K, V>(dataMap, nodeMap, newContent),
        didAdd: false,
      );
    } else {
      // Hash collision, different keys -> create sub-node
      final subNode = mergeDataEntries(
        shift + kBitPartitionSize,
        hashOfKey(currentKey),
        currentKey,
        currentValue,
        hash,
        key,
        value,
        null, // Immutable merge
      );
      // Create new node replacing data with sub-node
      final newNode = _replaceDataWithNodeImmutable(dataIndex, subNode, bitpos);
      return (node: newNode, didAdd: true);
    }
  }

  ChampAddResult<K, V> _addImmutableDelegate(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      null,
    ); // Immutable add

    if (identical(addResult.node, subNode))
      return (node: this, didAdd: addResult.didAdd); // No change

    // Create new content list with updated sub-node
    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = addResult.node;
    // Count doesn't change, stays ArrayNode
    return (
      node: ChampArrayNode<K, V>(dataMap, nodeMap, newContent),
      didAdd: addResult.didAdd,
    );
  }

  ChampAddResult<K, V> _addImmutableEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = dataIndex * 2;
    // Create new content list with inserted entry
    final newContent = List<Object?>.of(content)
      ..insertAll(payloadIndex, [key, value]);
    final newDataMap = dataMap | bitpos;
    // Create new node (will remain ArrayNode as count increases)
    final newNode = _createImmutableNode(newDataMap, nodeMap, newContent);
    return (node: newNode, didAdd: true);
  }

  // --- Transient Remove Helpers (ArrayNode) ---

  ChampRemoveResult<K, V> _removeTransientData(
    K key,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (content[payloadIndex] == key) {
      // Found the key to remove
      _removeDataEntryInPlace(dataIndex, bitpos); // Mutate in place
      // Check if node needs shrinking or transition Array -> Sparse
      final newNode = _shrinkOrTransitionIfNeeded(owner);
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> _removeTransientDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      owner,
    );

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    // Sub-node changed, update content in place
    content[contentIdx] = removeResult.node;

    // Check if the sub-node became empty or needs merging
    if (removeResult.node.isEmptyNode) {
      _removeNodeEntryInPlace(nodeIndex, bitpos); // Mutate in place
      final newNode = _shrinkOrTransitionIfNeeded(
        owner,
      ); // Check for collapse/transition
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // If sub-node collapsed to a data node, replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      _replaceNodeWithDataInPlace(
        nodeIndex,
        dataNode.dataKey,
        dataNode.dataValue,
        bitpos,
      ); // Mutate in place
      // Check if node needs shrinking or transition Array -> Sparse
      final newNode = _shrinkOrTransitionIfNeeded(owner);
      return (
        node: newNode ?? this,
        didRemove: true,
      ); // Return potentially transitioned node
    }
    // Sub-node modified but not removed/collapsed, return mutable node
    return (node: this, didRemove: true);
  }

  // --- Immutable Remove Helpers (ArrayNode) ---

  ChampRemoveResult<K, V> _removeImmutableData(K key, int frag, int bitpos) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    if (content[payloadIndex] == key) {
      // Found the key to remove
      final newDataMap = dataMap ^ bitpos;
      if (newDataMap == 0 && nodeMap == 0)
        return (node: ChampEmptyNode<K, V>(), didRemove: true);

      // Create new list with data entry removed
      final newContent = List<Object?>.of(content)
        ..removeRange(payloadIndex, payloadIndex + 2);
      // Check for immutable shrink / transition
      final newNode = _createImmutableNode(newDataMap, nodeMap, newContent);
      return (node: newNode, didRemove: true);
    }
    return (node: this, didRemove: false); // Key not found
  }

  ChampRemoveResult<K, V> _removeImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      null,
    ); // Immutable remove

    if (!removeResult.didRemove) return (node: this, didRemove: false);

    // Sub-node changed, create new node with updated sub-node
    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = removeResult.node;

    if (removeResult.node.isEmptyNode) {
      // Remove the empty sub-node entry
      final newNodeMap = nodeMap ^ bitpos;
      newContent.removeAt(contentIdx); // Remove from the copied list
      if (dataMap == 0 && newNodeMap == 0)
        return (node: ChampEmptyNode<K, V>(), didRemove: true);
      // Check for immutable shrink / transition
      final newNode = _createImmutableNode(dataMap, newNodeMap, newContent);
      return (node: newNode, didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // Replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      final newDataMap = dataMap | bitpos;
      final newNodeMap = nodeMap ^ bitpos;
      final dataPayloadIndex = dataIndexFromFragment(frag, newDataMap) * 2;

      // Create new content list: copy old data, insert new data, copy old nodes (excluding replaced one)
      final newDataCount = bitCount(newDataMap);
      final newNodeCount = bitCount(newNodeMap);
      final newChildrenList = List<Object?>.filled(
        newDataCount * 2 + newNodeCount,
        null,
      );

      // Copy data before insertion point
      if (dataPayloadIndex > 0)
        newChildrenList.setRange(0, dataPayloadIndex, content, 0);
      // Insert new data
      newChildrenList[dataPayloadIndex] = dataNode.dataKey;
      newChildrenList[dataPayloadIndex + 1] = dataNode.dataValue;
      // Copy data after insertion point
      final oldDataEnd = bitCount(dataMap) * 2;
      if (dataPayloadIndex < oldDataEnd) {
        newChildrenList.setRange(
          dataPayloadIndex + 2,
          newDataCount * 2,
          content,
          dataPayloadIndex,
        );
      }

      // Copy nodes before removed node
      final oldNodeStartIndex = bitCount(dataMap) * 2;
      final newNodeStartIndex = newDataCount * 2;
      if (nodeIndex > 0) {
        newChildrenList.setRange(
          newNodeStartIndex,
          newNodeStartIndex + nodeIndex,
          content,
          oldNodeStartIndex,
        );
      }
      // Copy nodes after removed node
      if (nodeIndex < bitCount(nodeMap) - 1) {
        newChildrenList.setRange(
          newNodeStartIndex + nodeIndex,
          newNodeStartIndex + newNodeCount,
          content,
          oldNodeStartIndex + nodeIndex + 1,
        );
      }

      // Check for immutable shrink / transition
      final newNode = _createImmutableNode(
        newDataMap,
        newNodeMap,
        newChildrenList,
      );
      return (node: newNode, didRemove: true);
    }
    // Sub-node modified but not removed/collapsed
    // Check for immutable shrink / transition (count didn't change, but type might)
    final newNode = _createImmutableNode(dataMap, nodeMap, newContent);
    return (node: newNode, didRemove: true);
  }

  // --- Transient Update Helpers (ArrayNode) ---

  ChampUpdateResult<K, V> _updateTransientData(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value in place
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      content[payloadIndex + 1] = updatedValue; // Mutate value in place
      return (node: this, sizeChanged: false);
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = content[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hashOfKey(currentKey),
          currentKey,
          currentVal,
          hash,
          key,
          newValue,
          owner,
        );
        _replaceDataWithNodeInPlace(
          dataIndex,
          subNode,
          bitpos,
        ); // Mutate in place
        return (node: this, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> _updateTransientDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = content[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: owner,
    );

    if (identical(updateResult.node, subNode))
      return (node: this, sizeChanged: updateResult.sizeChanged);

    // Update content array in place
    content[contentIdx] = updateResult.node;
    // No transition check needed as count doesn't change relative to this node
    return (node: this, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> _updateTransientEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
  ) {
    assert(isTransient(_owner));
    if (ifAbsentFn != null) {
      // Insert new data entry using ifAbsentFn (in place)
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      _insertDataEntryInPlace(dataIndex, key, newValue, bitpos);
      // ArrayNode never transitions back to Sparse on add/update
      return (node: this, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // --- Immutable Update Helpers (ArrayNode) ---

  ChampUpdateResult<K, V> _updateImmutableData(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
  ) {
    final dataIndex = dataIndexFromFragment(frag, dataMap);
    final payloadIndex = contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue))
        return (node: this, sizeChanged: false);
      // Create new node with updated value (Manual Copy Optimization)
      final len = content.length;
      final newContent = List<Object?>.filled(len, null);
      for (int i = 0; i < len; i++) {
        newContent[i] = content[i];
      }
      newContent[payloadIndex + 1] = updatedValue; // Update the specific value
      // Count doesn't change, stays ArrayNode
      return (
        node: ChampArrayNode<K, V>(dataMap, nodeMap, newContent),
        sizeChanged: false,
      );
    } else {
      // Hash collision, different keys
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node
        final newValue = ifAbsentFn();
        final currentVal = content[payloadIndex + 1] as V;
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hashOfKey(currentKey),
          currentKey,
          currentVal,
          hash,
          key,
          newValue,
          null, // Immutable merge
        );
        // Create new node replacing data with sub-node
        final newNode = _replaceDataWithNodeImmutable(
          dataIndex,
          subNode,
          bitpos,
        );
        return (node: newNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  ChampUpdateResult<K, V> _updateImmutableDelegate(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
  ) {
    final nodeIndex = nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = contentIndexFromNodeIndex(nodeIndex, dataMap);
    final subNode = content[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: null,
    );

    if (identical(updateResult.node, subNode))
      return (node: this, sizeChanged: updateResult.sizeChanged);

    // Create new node with updated sub-node
    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = updateResult.node;
    // Create new node (will remain ArrayNode as count doesn't change)
    final newNode = _createImmutableNode(dataMap, nodeMap, newContent);
    return (node: newNode, sizeChanged: updateResult.sizeChanged);
  }

  ChampUpdateResult<K, V> _updateImmutableEmptySlot(
    K key,
    int frag,
    int bitpos,
    V Function()? ifAbsentFn,
  ) {
    if (ifAbsentFn != null) {
      // Insert new data entry using ifAbsentFn
      final newValue = ifAbsentFn();
      final dataIndex = dataIndexFromFragment(frag, dataMap);
      final newContent = List<Object?>.of(content)
        ..insertAll(dataIndex * 2, [key, newValue]);
      // Create new node (will remain ArrayNode)
      final newNode = _createImmutableNode(
        dataMap | bitpos,
        nodeMap,
        newContent,
      );
      return (node: newNode, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }
} // End of ChampArrayNode

// --- Merging Logic ---

/// Merges two data entries into a new node (Bitmap or Collision).
/// This is used when adding a new entry results in a collision with an existing
/// [ChampDataNode] or when splitting nodes during bulk loading.
///
/// - [shift]: The current bit shift level where the collision/merge occurs.
/// - [hash1], [key1], [value1]: Details of the first entry.
/// - [hash2], [key2], [value2]: Details of the second entry.
///
/// Returns an immutable [ChampBitmapNode] or [ChampCollisionNode].
/// - [owner]: Optional owner for creating transient nodes during the merge.
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
    final children = [subNode];
    // Create directly based on count
    if (1 <= kSparseNodeThreshold) {
      return ChampSparseNode<K, V>(dataMap, nodeMap, children, owner);
    } else {
      return ChampArrayNode<K, V>(dataMap, nodeMap, children, owner);
    }
  } else {
    // Fragments differ, create a bitmap node with two data entries
    final bitpos1 = 1 << frag1;
    final bitpos2 = 1 << frag2;
    final newDataMap = bitpos1 | bitpos2;
    final newNodeMap = 0;

    // Order entries based on fragment index
    final List<Object?> newContent;
    if (frag1 < frag2) {
      newContent = [key1, value1, key2, value2];
    } else {
      newContent = [key2, value2, key1, value1];
    }
    // Create directly based on count
    if (2 <= kSparseNodeThreshold) {
      return ChampSparseNode<K, V>(newDataMap, newNodeMap, newContent, owner);
    } else {
      return ChampArrayNode<K, V>(newDataMap, newNodeMap, newContent, owner);
    }
  }
}
