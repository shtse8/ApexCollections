/// Defines the core node structures for the Compressed Hash-Array Mapped Prefix Tree (CHAMP)
/// used internally by [ApexMap].
///
/// This library includes the abstract [ChampNode] base class and its concrete
/// implementations: [ChampEmptyNode], [ChampDataNode], [ChampCollisionNode],
/// and [ChampInternalNode]. It also defines constants related to the trie structure
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

// --- Helper Functions ---

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
/// * [ChampInternalNode]: Represents a branch with multiple children (data or other nodes).
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

    // Collision: Create a new node (Internal or Collision) to merge the two entries.
    final newNode = mergeDataEntries(
      shift, // Start merging from the current shift level
      dataHash,
      dataKey,
      dataValue,
      hash,
      key,
      value,
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
      // Hash differs, need to create an internal node to split this collision node
      // and the new data node based on their differing hash fragments at this level.
      final dataNode = ChampDataNode<K, V>(hash, key, value);
      final newNode = ChampInternalNode<K, V>.fromNodes(
        shift, // Create internal node at the current shift level
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
        final newNode = ChampInternalNode<K, V>.fromNodes(
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

// --- Internal Node ---

/// Represents an internal node (branch) in the CHAMP Trie.
///
/// Uses two bitmaps, [dataMap] and [nodeMap], to efficiently track whether a
/// given hash fragment corresponds to a direct data entry (key-value pair) or
/// a child node stored in the [content] list.
///
/// The [content] list stores data entries interleaved (key, value, key, value...)
/// followed by child nodes ([ChampNode]). The indices are calculated based on the
/// population count ([bitCount]) of the bitmaps.
class ChampInternalNode<K, V> extends ChampNode<K, V> {
  /// Bitmap indicating which hash fragments correspond to data entries in [content].
  int dataMap; // Made mutable for transient ops

  /// Bitmap indicating which hash fragments correspond to child nodes in [content].
  int nodeMap; // Made mutable for transient ops

  /// Array storing data entries (key, value pairs) and sub-nodes.
  /// Data entries are stored first, ordered by their hash fragment index,
  /// followed by sub-nodes, also ordered by their hash fragment index.
  /// Data: `[k1, v1, k2, v2, ...]`
  /// Nodes: `[..., nodeA, nodeB, ...]`
  /// This list is mutable only if the node is transient.
  List<Object?> content; // Made mutable for transient ops

  /// Creates an internal CHAMP node.
  ///
  /// - [dataMap]: Bitmap for data entries.
  /// - [nodeMap]: Bitmap for child nodes.
  /// - [content]: The combined list of data payloads and child nodes, ordered correctly.
  /// - [owner]: Optional [TransientOwner] for mutability.
  ChampInternalNode(
    this.dataMap,
    this.nodeMap,
    List<Object?> content, [
    TransientOwner? owner,
  ])
    // Ensure content is mutable if node is transient, otherwise copy to unmodifiable
    : content = (owner != null) ? content : List.unmodifiable(content),
       super(owner);

  /// Factory constructor to create an internal node from two initial child nodes
  /// that have different hash fragments at the current [shift] level.
  /// Used when merging data entries or splitting collision nodes.
  factory ChampInternalNode.fromNodes(
    int shift,
    int hash1,
    ChampNode<K, V> node1,
    int hash2,
    ChampNode<K, V> node2,
    TransientOwner? owner, // Pass owner for potential transient creation
  ) {
    final frag1 = indexFragment(shift, hash1);
    final frag2 = indexFragment(shift, hash2);

    assert(frag1 != frag2, 'Hash fragments must differ for fromNodes');

    final bitpos1 = 1 << frag1;
    final bitpos2 = 1 << frag2;
    final newNodeMap = bitpos1 | bitpos2;

    // Order nodes based on fragment index for consistent content layout
    final List<Object?> newContent;
    if (frag1 < frag2) {
      newContent = [node1, node2];
    } else {
      newContent = [node2, node1];
    }

    // Create the new internal node (potentially transient if owner is provided)
    return ChampInternalNode<K, V>(
      0, // No data entries initially
      newNodeMap,
      newContent,
      owner, // Pass owner to constructor
    );
  }

  // --- Helper methods for index calculation ---

  /// Calculates the index within the data portion of the [content] list
  /// corresponding to a given hash fragment [frag].
  /// Requires the node's dataMap.
  static int dataIndexFromFragment(int frag, int dataMap) =>
      bitCount(dataMap & ((1 << frag) - 1));

  /// Calculates the index within the node portion of the [content] list
  /// corresponding to a given hash fragment [frag].
  /// Requires the node's nodeMap.
  static int nodeIndexFromFragment(int frag, int nodeMap) =>
      bitCount(nodeMap & ((1 << frag) - 1));

  /// Calculates the starting index in the [content] list for a data entry,
  /// given its index within the conceptual data array ([dataIndex]).
  static int contentIndexFromDataIndex(int dataIndex) => dataIndex * 2;

  /// Calculates the index in the [content] list for a child node,
  /// given its index within the conceptual node array ([nodeIndex]).
  /// Requires the node's dataMap to know where data entries end.
  static int contentIndexFromNodeIndex(int nodeIndex, int dataMap) =>
      (bitCount(dataMap) * 2) + nodeIndex; // Data entries come first

  // --- Core Methods ---

  @override
  V? get(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      // Check data entries first
      final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
      final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(
        dataIndex,
      );
      // Check if the key matches
      if (content[payloadIndex] == key) {
        return content[payloadIndex + 1] as V;
      }
      return null; // Hash fragment collision, but different key
    } else if ((nodeMap & bitpos) != 0) {
      // Check sub-nodes
      final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
      final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
        nodeIndex,
        dataMap,
      );
      final subNode = content[contentIdx] as ChampNode<K, V>;
      // Recursively search in the sub-node
      return subNode.get(key, hash, shift + kBitPartitionSize);
    }

    return null; // Not found in this branch
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      // Check data entries first
      final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
      final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(
        dataIndex,
      );
      // Check if the key matches
      return content[payloadIndex] == key;
    } else if ((nodeMap & bitpos) != 0) {
      // Check sub-nodes
      final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
      final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
        nodeIndex,
        dataMap,
      );
      final subNode = content[contentIdx] as ChampNode<K, V>;
      // Recursively search in the sub-node
      return subNode.containsKey(key, hash, shift + kBitPartitionSize);
    }

    return false; // Not found in this branch
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

    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner); // Ensure this node is mutable
      if ((mutableNode.dataMap & bitpos) != 0) {
        return mutableNode._addTransientDataCollision(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner,
        );
      } else if ((mutableNode.nodeMap & bitpos) != 0) {
        return mutableNode._addTransientDelegate(
          key,
          value,
          hash,
          shift,
          frag,
          bitpos,
          owner,
        );
      } else {
        return mutableNode._addTransientEmptySlot(key, value, frag, bitpos);
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

    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner);
      if ((mutableNode.dataMap & bitpos) != 0) {
        return mutableNode._removeTransientData(key, frag, bitpos, owner);
      } else if ((mutableNode.nodeMap & bitpos) != 0) {
        return mutableNode._removeTransientDelegate(
          key,
          hash,
          shift,
          frag,
          bitpos,
          owner,
        );
      } else {
        return (node: mutableNode, didRemove: false); // Not found
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        return _removeImmutableData(key, frag, bitpos);
      } else if ((nodeMap & bitpos) != 0) {
        return _removeImmutableDelegate(key, hash, shift, frag, bitpos);
      } else {
        return (node: this, didRemove: false); // Not found
      }
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

    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner);
      if ((mutableNode.dataMap & bitpos) != 0) {
        return mutableNode._updateTransientData(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
          owner,
        );
      } else if ((mutableNode.nodeMap & bitpos) != 0) {
        return mutableNode._updateTransientDelegate(
          key,
          hash,
          shift,
          frag,
          bitpos,
          updateFn,
          ifAbsentFn,
          owner,
        );
      } else {
        return mutableNode._updateTransientEmptySlot(
          key,
          frag,
          bitpos,
          ifAbsentFn,
        );
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

  // --- Transient Add Helpers ---

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
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;
    final currentValue = content[payloadIndex + 1] as V;

    if (currentKey == key) {
      // Update existing key
      if (currentValue == value) return (node: this, didAdd: false);
      content[payloadIndex + 1] = value; // Mutate in place
      return (node: this, didAdd: false);
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
    final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    );
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      owner,
    ); // Pass owner

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
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    _insertDataEntryInPlace(dataIndex, key, value, bitpos); // Mutate in place
    return (node: this, didAdd: true);
  }

  // --- Immutable Add Helpers ---

  ChampAddResult<K, V> _addImmutableDataCollision(
    K key,
    V value,
    int hash,
    int shift,
    int frag,
    int bitpos,
  ) {
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;
    final currentValue = content[payloadIndex + 1] as V;

    if (currentKey == key) {
      // Update existing key
      if (currentValue == value) {
        return (node: this, didAdd: false); // No change
      }
      // Create new content list with updated value
      final newContent = List<Object?>.of(content);
      newContent[payloadIndex + 1] = value;
      return (
        node: ChampInternalNode<K, V>(dataMap, nodeMap, newContent),
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
      );

      // Create new node replacing data with sub-node (Explicit list manipulation logic)
      final dataPayloadIndex = dataIndex * 2;
      final dataCount = bitCount(dataMap);
      final nodeCount = bitCount(nodeMap);
      final newNodeStartIndex =
          (dataCount - 1) * 2; // Start index for nodes in newContent

      // Create the new content list
      final newContent = List<Object?>.filled(
        newNodeStartIndex + (nodeCount + 1), // (data-1)*2 + (nodes+1)
        null,
        growable: false,
      );

      // Copy data before the replaced entry
      if (dataIndex > 0) {
        newContent.setRange(0, dataPayloadIndex, content, 0);
      }
      // Copy data after the replaced entry
      if (dataIndex < dataCount - 1) {
        newContent.setRange(
          dataPayloadIndex, // Start index in newContent
          newNodeStartIndex, // End index in newContent (end of data section)
          content,
          dataPayloadIndex +
              2, // Start index in old content (after removed entry)
        );
      }

      // Copy existing nodes before the insertion point for the new subNode
      final targetNodeMap =
          nodeMap | bitpos; // The final nodeMap after adding the bit
      // final frag = bitCount(bitpos - 1); // Get fragment index (0-31) from bitpos - Already have frag
      final targetNodeIndex = bitCount(
        targetNodeMap & (bitpos - 1),
      ); // Nodes before this one
      final nodeInsertPos =
          newNodeStartIndex + targetNodeIndex; // Actual index in newContent

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
            nodeInsertPos + 1, // Start after inserted node
            newContent.length, // Go to end
            content,
            oldNodeStartIndex +
                targetNodeIndex, // Start from original position of nodes after insertion point
          );
        }
      }

      // Insert the new subNode at the calculated position
      newContent[nodeInsertPos] = subNode;

      // Create and return the new immutable node
      final newNode = ChampInternalNode<K, V>(
        dataMap ^ bitpos, // Remove data bit
        nodeMap | bitpos, // Add node bit
        newContent,
        null, // owner is null for immutable result
      );
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
    final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    );
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final addResult = subNode.add(
      key,
      value,
      hash,
      shift + kBitPartitionSize,
      null, // Immutable operation
    );

    if (identical(addResult.node, subNode)) {
      return (node: this, didAdd: addResult.didAdd); // No change
    }

    // Create new content list with updated sub-node
    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = addResult.node;
    final newNode = ChampInternalNode<K, V>(dataMap, nodeMap, newContent);
    return (node: newNode, didAdd: addResult.didAdd);
  }

  ChampAddResult<K, V> _addImmutableEmptySlot(
    K key,
    V value,
    int frag,
    int bitpos,
  ) {
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    // Create new content list with inserted data
    final newContent = List<Object?>.of(content)
      ..insertAll(dataIndex * 2, [key, value]);
    final newNode = ChampInternalNode<K, V>(
      dataMap | bitpos,
      nodeMap,
      newContent,
    );
    return (node: newNode, didAdd: true);
  }

  // --- Transient Remove Helpers ---

  ChampRemoveResult<K, V> _removeTransientData(
    K key,
    int frag,
    int bitpos,
    TransientOwner owner,
  ) {
    assert(isTransient(owner));
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(dataIndex);
    if (content[payloadIndex] == key) {
      // Found the key to remove
      _removeDataEntryInPlace(dataIndex, bitpos);
      // Check if node needs shrinking/collapsing
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
    final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    );
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
      // Remove the empty sub-node entry
      _removeNodeEntryInPlace(nodeIndex, bitpos);
      // Check if this node needs shrinking
      final newNode = _shrinkIfNeeded(owner);
      return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // If sub-node collapsed to a data node, replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      _replaceNodeWithDataInPlace(
        nodeIndex,
        dataNode.dataKey,
        dataNode.dataValue,
        bitpos,
      );
      // No need to shrink here as content size didn't change
      return (node: this, didRemove: true);
    }
    // Sub-node modified but not removed/collapsed, return mutable node
    return (node: this, didRemove: true);
  }

  // --- Immutable Remove Helpers ---

  ChampRemoveResult<K, V> _removeImmutableData(K key, int frag, int bitpos) {
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(dataIndex);
    if (content[payloadIndex] == key) {
      // Found the key to remove
      // Create new node with data entry removed
      final newDataMap = dataMap ^ bitpos;
      if (newDataMap == 0 && nodeMap == 0)
        return (node: ChampEmptyNode<K, V>(), didRemove: true);

      final newContent = List<Object?>.of(content)
        ..removeRange(payloadIndex, payloadIndex + 2);
      // TODO: Immutable shrink?
      return (
        node: ChampInternalNode<K, V>(newDataMap, nodeMap, newContent),
        didRemove: true,
      );
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
    final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    );
    final subNode = content[contentIdx] as ChampNode<K, V>;
    final removeResult = subNode.remove(
      key,
      hash,
      shift + kBitPartitionSize,
      null,
    ); // No owner

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
      // TODO: Immutable shrink?
      return (
        node: ChampInternalNode<K, V>(dataMap, newNodeMap, newContent),
        didRemove: true,
      );
    } else if (removeResult.node is ChampDataNode<K, V>) {
      // Replace node entry with data entry
      final dataNode = removeResult.node as ChampDataNode<K, V>;
      final newDataMap = dataMap | bitpos;
      final newNodeMap = nodeMap ^ bitpos;
      final dataPayloadIndex =
          ChampInternalNode.dataIndexFromFragment(frag, newDataMap) *
          2; // Index where new data goes in the *new* map

      // Create new content list: copy old data, insert new data, copy old nodes (excluding replaced one)
      final newDataCount = bitCount(newDataMap);
      final newNodeCount = bitCount(newNodeMap);
      final newContentList = List<Object?>.filled(
        newDataCount * 2 + newNodeCount,
        null,
      );

      // Copy data before insertion point
      if (dataPayloadIndex > 0)
        newContentList.setRange(0, dataPayloadIndex, content, 0);
      // Insert new data
      newContentList[dataPayloadIndex] = dataNode.dataKey;
      newContentList[dataPayloadIndex + 1] = dataNode.dataValue;
      // Copy data after insertion point
      final oldDataEnd = bitCount(dataMap) * 2;
      if (dataPayloadIndex < oldDataEnd)
        newContentList.setRange(
          dataPayloadIndex + 2,
          newDataCount * 2,
          content,
          dataPayloadIndex,
        );

      // Copy nodes before removed node
      final oldNodeStartIndex =
          bitCount(dataMap) * 2; // Start of nodes in old content
      final newNodeStartIndex = newDataCount * 2;
      if (nodeIndex > 0)
        newContentList.setRange(
          newNodeStartIndex,
          newNodeStartIndex + nodeIndex,
          content,
          oldNodeStartIndex,
        );
      // Copy nodes after removed node
      if (nodeIndex < bitCount(nodeMap) - 1)
        newContentList.setRange(
          newNodeStartIndex + nodeIndex,
          newNodeStartIndex + newNodeCount,
          content,
          oldNodeStartIndex + nodeIndex + 1,
        );

      return (
        node: ChampInternalNode<K, V>(newDataMap, newNodeMap, newContentList),
        didRemove: true,
      );
    }
    // Sub-node modified but not removed/collapsed
    return (
      node: ChampInternalNode<K, V>(dataMap, nodeMap, newContent),
      didRemove: true,
    );
  }

  // --- Transient Update Helpers ---

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
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value in place
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue)) {
        return (node: this, sizeChanged: false); // Value didn't change
      }
      // Mutate value in place
      content[payloadIndex + 1] = updatedValue;
      return (
        node: this,
        sizeChanged: false,
      ); // Return potentially mutated node
    } else {
      // Hash collision at this level, but keys differ
      if (ifAbsentFn != null) {
        // Convert existing data entry + new entry into a sub-node (collision or internal)
        final newValue = ifAbsentFn();
        final currentVal = content[payloadIndex + 1] as V;
        // mergeDataEntries creates immutable nodes
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          hashOfKey(currentKey),
          currentKey,
          currentVal,
          hash,
          key,
          newValue,
        );
        // Replace data entry with the new sub-node in place
        _replaceDataWithNodeInPlace(dataIndex, subNode, bitpos);
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
    final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    );
    final subNode = content[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: owner, // Pass owner down
    );

    // If sub-node didn't change identity, return original node
    if (identical(updateResult.node, subNode)) {
      return (node: this, sizeChanged: updateResult.sizeChanged);
    }

    // Update content array in place with the updated sub-node
    content[contentIdx] = updateResult.node;
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
      final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
      _insertDataEntryInPlace(dataIndex, key, newValue, bitpos);
      return (node: this, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // --- Immutable Update Helpers ---

  ChampUpdateResult<K, V> _updateImmutableData(
    K key,
    int hash,
    int shift,
    int frag,
    int bitpos,
    V Function(V value) updateFn,
    V Function()? ifAbsentFn,
  ) {
    final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
    final payloadIndex = ChampInternalNode.contentIndexFromDataIndex(dataIndex);
    final currentKey = content[payloadIndex] as K;

    if (currentKey == key) {
      // Found key, update value
      final currentValue = content[payloadIndex + 1] as V;
      final updatedValue = updateFn(currentValue);
      if (identical(updatedValue, currentValue)) {
        return (node: this, sizeChanged: false); // Value didn't change
      }
      // Create new node with updated value
      final newContent = List<Object?>.of(content);
      newContent[payloadIndex + 1] = updatedValue;
      return (
        node: ChampInternalNode<K, V>(dataMap, nodeMap, newContent),
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
        );
        // Create new node replacing data with sub-node
        return (
          node: _replaceDataWithNodeImmutable(dataIndex, subNode, bitpos),
          sizeChanged: true,
        );
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
    final nodeIndex = ChampInternalNode.nodeIndexFromFragment(frag, nodeMap);
    final contentIdx = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    );
    final subNode = content[contentIdx] as ChampNode<K, V>;

    // Recursively update the sub-node
    final updateResult = subNode.update(
      key,
      hash,
      shift + kBitPartitionSize,
      updateFn,
      ifAbsentFn: ifAbsentFn,
      owner: null,
    ); // No owner

    // If sub-node didn't change identity, return original node
    if (identical(updateResult.node, subNode)) {
      return (node: this, sizeChanged: updateResult.sizeChanged);
    }

    // Create new node with updated sub-node
    final newContent = List<Object?>.of(content);
    newContent[contentIdx] = updateResult.node;
    return (
      node: ChampInternalNode<K, V>(dataMap, nodeMap, newContent),
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
      final dataIndex = ChampInternalNode.dataIndexFromFragment(frag, dataMap);
      final newContent = List<Object?>.of(content)
        ..insertAll(dataIndex * 2, [key, newValue]);
      return (
        node: ChampInternalNode<K, V>(dataMap | bitpos, nodeMap, newContent),
        sizeChanged: true,
      );
    } else {
      // Key not found, no ifAbsentFn
      return (node: this, sizeChanged: false);
    }
  }

  // --- Transient Helper Methods ---

  /// Returns this node if it's mutable and owned by [owner],
  /// otherwise returns a new mutable copy owned by [owner].
  /// Used for transient operations.
  ChampInternalNode<K, V> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy with the new owner
    return ChampInternalNode<K, V>(
      dataMap,
      nodeMap,
      List<Object?>.of(
        content,
        growable: true,
      ), // Create mutable GROWABLE list copy
      owner, // Assign the new owner
    );
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      // Freeze sub-nodes first
      final nodeCount = bitCount(nodeMap);
      final dataSlots = bitCount(dataMap) * 2;
      for (int i = 0; i < nodeCount; i++) {
        final nodeIndex = dataSlots + i;
        final subNode = content[nodeIndex] as ChampNode<K, V>;
        content[nodeIndex] = subNode.freeze(owner); // Freeze recursively
      }
      // If owned, become immutable by removing the owner
      this._owner = null; // Use 'this._owner' to modify the instance field
      // Content list reference remains the same, but node is now immutable.
      // No need to copy with List.unmodifiable.
      return this;
    }
    // If not owned or already immutable, return as is.
    return this;
  }

  /// Immutable version of _replaceDataWithNodeInPlace.
  /// Creates a new node with the data entry at dataIndex replaced by subNode.
  ChampInternalNode<K, V> _replaceDataWithNodeImmutable(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    final dataPayloadIndex = dataIndex * 2;
    final dataCount = bitCount(dataMap);
    final nodeCount = bitCount(nodeMap);

    // Create the new content list
    final newContent = List<Object?>.filled(
      (dataCount - 1) * 2 + (nodeCount + 1), // (data-1)*2 + (nodes+1)
      null,
      growable: false, // Immutable result can be fixed-length
    );

    // Copy data before the replaced entry
    if (dataIndex > 0) {
      newContent.setRange(0, dataPayloadIndex, content, 0);
    }
    // Copy data after the replaced entry
    if (dataIndex < dataCount - 1) {
      newContent.setRange(
        dataPayloadIndex, // Start index in newContent (after previous data)
        (dataCount - 1) * 2, // End index in newContent (end of data section)
        content,
        dataPayloadIndex +
            2, // Start index in old content (after removed entry)
      );
    }

    // Copy existing nodes
    if (nodeCount > 0) {
      final oldNodeStartIndex = dataCount * 2;
      final newNodeStartIndex = (dataCount - 1) * 2;
      newContent.setRange(
        newNodeStartIndex, // Start index in newContent (after all data)
        newNodeStartIndex + nodeCount, // End index in newContent
        content,
        oldNodeStartIndex, // Start index in old content (start of nodes)
      );
    }

    // Add the new subNode at the end of the node section
    newContent[newContent.length - 1] = subNode;

    // Create and return the new immutable node
    return ChampInternalNode<K, V>(
      dataMap ^ bitpos, // Remove data bit
      nodeMap | bitpos, // Add node bit
      newContent, // Pass the newly constructed list
      null, // owner is null for immutable result
    );
  }

  // --- In-place mutation helpers (only call when isTransient(owner) is true) ---

  /// Inserts a data entry (key/value pair) into the [content] list at the
  /// correct position based on its [dataIndex]. Updates the [dataMap].
  /// Assumes the node is transient and owned.
  void _insertDataEntryInPlace(int dataIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = ChampInternalNode.contentIndexFromDataIndex(
      dataIndex,
    );
    // Insert into the list directly
    content.insertAll(dataPayloadIndex, [key, value]);
    // Update bitmap
    dataMap |= bitpos;
  }

  /// Removes a data entry (key/value pair) from the [content] list based on
  /// its [dataIndex]. Updates the [dataMap].
  /// Assumes the node is transient and owned.
  void _removeDataEntryInPlace(int dataIndex, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = ChampInternalNode.contentIndexFromDataIndex(
      dataIndex,
    );
    // Remove from the list
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    // Update bitmap
    dataMap ^= bitpos;
  }

  /// Removes a child node entry from the [content] list based on its [nodeIndex].
  /// Updates the [nodeMap].
  /// Assumes the node is transient and owned.
  void _removeNodeEntryInPlace(int nodeIndex, int bitpos) {
    assert(isTransient(_owner));
    // Use static helper, passing current dataMap
    final contentNodeIndex = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    );
    // Remove from the list
    content.removeAt(contentNodeIndex);
    // Update bitmap
    nodeMap ^= bitpos;
  }

  /// Replaces a data entry with a sub-node (in place).
  /// Used when a hash collision occurs during a transient add/update.
  /// Assumes the node is transient and owned.
  void _replaceDataWithNodeInPlace(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    assert(isTransient(_owner));
    final dataPayloadIndex = ChampInternalNode.contentIndexFromDataIndex(
      dataIndex,
    );

    // --- Calculate node insertion index ---
    // This needs to be based on the fragment corresponding to the bitpos
    final frag = bitCount(
      bitpos - 1,
    ); // Get the index (0-31) from the bit position
    // Calculate where the new node *will* go based on the *final* nodeMap state
    final targetNodeMap =
        nodeMap | bitpos; // Node map *after* adding the new node bit
    final targetNodeIndex = bitCount(
      targetNodeMap & (bitpos - 1),
    ); // Nodes before the new one in the final map

    // --- Modify content list ---
    // 1. Remove the data entry (key, value)
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    // 2. Insert the sub-node at the correct position in the node section
    // The node section starts after the remaining data entries
    final nodeInsertPos =
        (bitCount(dataMap) - 1) * 2 +
        targetNodeIndex; // Index in content *after* data removal
    // Ensure insertion index is valid
    if (nodeInsertPos > content.length) {
      content.add(subNode); // Append if index is exactly at the end
    } else {
      content.insert(nodeInsertPos, subNode); // Insert otherwise
    }

    // --- Update bitmaps ---
    dataMap ^= bitpos; // Remove data bit
    nodeMap |= bitpos; // Add node bit
  }

  /// Replaces a node entry with a data entry (in place).
  /// Used when a child node collapses to a data node during a transient remove.
  /// Assumes the node is transient and owned.
  void _replaceNodeWithDataInPlace(int nodeIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    // Calculate where new data *will* go based on the *final* dataMap state
    final frag = indexFragment(0, hashOfKey(key)); // Fragment for the new data
    final targetDataMap =
        dataMap | bitpos; // dataMap *after* adding the new data bit
    final targetDataIndex = ChampInternalNode.dataIndexFromFragment(
      frag,
      targetDataMap,
    );
    final dataPayloadIndex = ChampInternalNode.contentIndexFromDataIndex(
      targetDataIndex,
    );
    final nodeContentIndex = ChampInternalNode.contentIndexFromNodeIndex(
      nodeIndex,
      dataMap,
    ); // Index of node to remove (uses *current* dataMap)

    // Remove the node entry
    content.removeAt(nodeContentIndex);
    // Insert the data entry (key, value) at the correct position
    content.insertAll(dataPayloadIndex, [key, value]);

    // Update bitmaps
    dataMap |= bitpos; // Add data bit
    nodeMap ^= bitpos; // Remove node bit
  }

  /// Checks if the node needs shrinking after a removal and performs it (in place).
  /// Returns the potentially new node (e.g., if collapsed to DataNode or EmptyNode).
  /// Assumes the node is transient and owned.
  ChampNode<K, V>? _shrinkIfNeeded(TransientOwner? owner) {
    assert(isTransient(owner)); // Should only be called transiently

    // Condition 1: Collapse to EmptyNode
    if (dataMap == 0 && nodeMap == 0) {
      return ChampEmptyNode<K, V>();
    }

    // Condition 2: Collapse to DataNode
    // Only one data entry left, no sub-nodes
    if (nodeMap == 0 && bitCount(dataMap) == 1) {
      final key = content[0] as K;
      final value = content[1] as V;
      // Return immutable DataNode
      return ChampDataNode<K, V>(hashOfKey(key), key, value);
    }

    // Condition 3: Merge single sub-node with single data entry if possible
    // (More complex CHAMP optimization, potentially skip for now)
    // if (bitCount(dataMap) == 1 && bitCount(nodeMap) == 1) { ... }

    // Condition 4: If only one sub-node remains, collapse this level
    if (dataMap == 0 && bitCount(nodeMap) == 1) {
      // The remaining sub-node might be mutable or immutable
      return content[0] as ChampNode<K, V>;
    }

    // No shrinking needed, return the current (mutable) node
    return this;
  }
} // End of ChampInternalNode

// --- Merging Logic ---

/// Merges two data entries into a new node (Internal or Collision).
/// This is used when adding a new entry results in a collision with an existing
/// [ChampDataNode] or when splitting nodes during bulk loading.
///
/// - [shift]: The current bit shift level where the collision/merge occurs.
/// - [hash1], [key1], [value1]: Details of the first entry.
/// - [hash2], [key2], [value2]: Details of the second entry.
///
/// Returns an immutable [ChampInternalNode] or [ChampCollisionNode].
ChampNode<K, V> mergeDataEntries<K, V>(
  int shift,
  int hash1,
  K key1,
  V value1,
  int hash2,
  K key2,
  V value2,
) {
  assert(key1 != key2); // Keys must be different

  if (shift >= kMaxDepth * kBitPartitionSize) {
    // Max depth reached, create a collision node
    return ChampCollisionNode<K, V>(
      hash1, // Use one of the hashes (they should be equal up to this depth)
      [MapEntry(key1, value1), MapEntry(key2, value2)],
      null, // Immutable result
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
    );
    // Create an internal node with the single sub-node
    final bitpos = 1 << frag1;
    return ChampInternalNode<K, V>(
      0, // No data map
      bitpos, // Node map with single bit set
      [subNode],
      null, // Immutable result
    );
  } else {
    // Fragments differ, create an internal node with two data entries
    final bitpos1 = 1 << frag1;
    final bitpos2 = 1 << frag2;
    final newDataMap = bitpos1 | bitpos2;

    // Order entries based on fragment index
    final List<Object?> newContent;
    if (frag1 < frag2) {
      newContent = [key1, value1, key2, value2];
    } else {
      newContent = [key2, value2, key1, value1];
    }
    return ChampInternalNode<K, V>(
      newDataMap,
      0, // No node map
      newContent,
      null, // Immutable result
    );
  }
}
