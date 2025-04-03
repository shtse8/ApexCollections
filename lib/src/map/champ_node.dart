import 'dart:math';
import 'package:collection/collection.dart'; // For ListEquality used in CollisionNode
import 'package:meta/meta.dart';

// --- Constants ---

const int kBitPartitionSize = 5;
const int kBitPartitionMask = (1 << kBitPartitionSize) - 1;
const int kMaxDepth = 7; // ceil(32 / 5) - Max depth based on 32-bit hash

// --- Helper Functions ---

/// Counts the number of set bits (1s) in an integer.
/// Used for calculating indices within the node's content array.
int bitCount(int n) {
  // Simple bit count implementation (can be optimized if needed)
  int count = 0;
  while (n > 0) {
    n &= (n - 1); // Clear the least significant bit set
    count++;
  }
  return count;
}

/// Extracts the relevant fragment of the hash code for a given shift level.
int indexFragment(int shift, int hash) => (hash >> shift) & kBitPartitionMask;

// --- Transient Ownership ---

/// A marker object to track transient (mutable) operations.
/// Nodes belonging to the same owner can be mutated in place.
class TransientOwner {
  const TransientOwner();
}

// --- Node Base Class ---

/// Abstract base class for CHAMP Trie nodes.
@immutable // Nodes are immutable by default unless transient
abstract class ChampNode<K, V> {
  /// Owner for transient mutation. Null if immutable.
  TransientOwner? _owner;

  ChampNode([this._owner]);

  /// Checks if the node is transient and belongs to the given owner.
  bool isTransient(TransientOwner? owner) => _owner != null && _owner == owner;

  /// Returns the value associated with the key, or null if not found.
  V? get(K key, int hash, int shift);

  /// Adds or updates a key-value pair. Returns the potentially modified node
  /// and a flag indicating if the size increased.
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Removes a key. Returns the potentially modified node and a flag
  /// indicating if a removal occurred.
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Updates a key's value. Returns the potentially modified node and a flag
  /// indicating if the size changed (due to insertion via ifAbsentFn).
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  });

  /// Returns an immutable version of this node. Freezes if transient and owned.
  ChampNode<K, V> freeze(TransientOwner? owner);

  /// Helper to get the hash code of a key (handles null if needed later).
  int hashOfKey(K key) => key.hashCode;

  /// Indicates if this is the canonical empty node.
  bool get isEmptyNode => false;
}

// --- Result Tuples (using Records for Dart 3+) ---

typedef ChampAddResult<K, V> = ({ChampNode<K, V> node, bool didAdd});
typedef ChampRemoveResult<K, V> = ({ChampNode<K, V> node, bool didRemove});
typedef ChampUpdateResult<K, V> = ({ChampNode<K, V> node, bool sizeChanged});

// --- Empty Node ---

/// Represents the single, canonical empty node.
class ChampEmptyNode<K, V> extends ChampNode<K, V> {
  // Private constructor for singleton pattern
  ChampEmptyNode._internal() : super(null); // Always immutable

  // Static instance (typed as Never to allow casting)
  static final ChampEmptyNode<Never, Never> _instance =
      ChampEmptyNode._internal();

  // Factory constructor to return the singleton instance, casting as needed
  factory ChampEmptyNode() => _instance as ChampEmptyNode<K, V>;

  @override
  bool get isEmptyNode => true;

  @override
  V? get(K key, int hash, int shift) => null;

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

/// Represents a node containing a single key-value pair.
class ChampDataNode<K, V> extends ChampNode<K, V> {
  final int dataHash;
  final K dataKey;
  final V dataValue;

  // Data nodes are always immutable (owner is null)
  ChampDataNode(this.dataHash, this.dataKey, this.dataValue) : super(null);

  @override
  V? get(K key, int hash, int shift) {
    return (key == dataKey) ? dataValue : null;
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
      // Update existing key
      if (value == dataValue) return (node: this, didAdd: false); // No change
      return (node: ChampDataNode(hash, key, value), didAdd: false);
    }

    // Collision: Create an internal node or collision node
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
      // Remove this node by returning the empty node
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
      // Key not found, add using ifAbsentFn
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

/// Represents a node containing multiple entries that have the same hash code
/// fragment up to a certain depth. Stores entries in a simple list.
class ChampCollisionNode<K, V> extends ChampNode<K, V> {
  final int collisionHash; // The hash code causing the collision
  List<MapEntry<K, V>> entries; // Made mutable

  // Constructor ensures the list is mutable if owned, otherwise unmodifiable
  ChampCollisionNode(
    this.collisionHash,
    List<MapEntry<K, V>> entries, [
    TransientOwner? owner,
  ]) : entries = (owner != null) ? entries : List.unmodifiable(entries),
       assert(entries.length >= 2), // Must have at least 2 entries
       super(owner);

  @override
  V? get(K key, int hash, int shift) {
    // Only search if the hash matches the collision hash
    if (hash == collisionHash) {
      for (final entry in entries) {
        if (entry.key == key) {
          return entry.value;
        }
      }
    }
    return null; // Hash doesn't match or key not found in list
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
      // Hash differs, need to create an internal node to split
      // Create a new internal node containing this collision node and the new data node
      final dataNode = ChampDataNode<K, V>(hash, key, value);
      final newNode = ChampInternalNode<K, V>.fromNodes(
        shift, // Create internal node at the current shift level
        collisionHash,
        this, // Existing collision node
        hash,
        dataNode, // New data node
        null, // Immutable operation
      );
      return (node: newNode, didAdd: true);
    }

    // Hash matches, add/update within the collision list
    final mutableNode = ensureMutable(owner); // Ensure mutable if owned
    final existingIndex = mutableNode.entries.indexWhere((e) => e.key == key);

    if (existingIndex != -1) {
      // Update existing key
      if (mutableNode.entries[existingIndex].value == value) {
        return (node: mutableNode, didAdd: false); // No change
      }
      // Mutate in place
      mutableNode.entries[existingIndex] = MapEntry(key, value);
      return (node: mutableNode, didAdd: false);
    } else {
      // Add new entry to the list (in place)
      mutableNode.entries.add(MapEntry(key, value));
      return (node: mutableNode, didAdd: true);
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
    mutableNode.entries.removeWhere((e) => e.key == key); // Mutate in place
    final removed = mutableNode.entries.length < initialLength;

    if (!removed) {
      // Key not found, return original (potentially mutable) node
      return (node: mutableNode, didRemove: false);
    }

    // If only one entry remains, convert back to DataNode
    if (mutableNode.entries.length == 1) {
      final lastEntry = mutableNode.entries.first;
      // Create immutable DataNode
      final dataNode = ChampDataNode<K, V>(
        collisionHash,
        lastEntry.key,
        lastEntry.value,
      );
      return (node: dataNode, didRemove: true);
    }

    // Otherwise, return the modified (mutable) collision node
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
        // Add as a new entry (will create an internal node)
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
    final mutableNode = ensureMutable(owner);
    final existingIndex = mutableNode.entries.indexWhere((e) => e.key == key);

    if (existingIndex != -1) {
      // Update existing key
      final currentValue = mutableNode.entries[existingIndex].value;
      final newValue = updateFn(currentValue);
      if (newValue == currentValue) {
        return (node: mutableNode, sizeChanged: false); // No change
      }
      // Mutate in place
      mutableNode.entries[existingIndex] = MapEntry(key, newValue);
      return (node: mutableNode, sizeChanged: false);
    } else if (ifAbsentFn != null) {
      // Key not found, add using ifAbsentFn
      final newValue = ifAbsentFn();
      // Mutate in place
      mutableNode.entries.add(MapEntry(key, newValue));
      return (node: mutableNode, sizeChanged: true);
    } else {
      // Key not found, no ifAbsentFn
      return (node: mutableNode, sizeChanged: false);
    }
  }

  /// Returns this node if mutable and owned, otherwise a mutable copy.
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

/// Represents an internal node in the CHAMP Trie.
/// Uses bitmaps (`dataMap`, `nodeMap`) to track the presence of data entries
/// and sub-nodes at each possible hash fragment index.
class ChampInternalNode<K, V> extends ChampNode<K, V> {
  /// Bitmap indicating which fragments correspond to data entries.
  int dataMap; // Made mutable

  /// Bitmap indicating which fragments correspond to sub-nodes.
  int nodeMap; // Made mutable

  /// Array storing data entries (key, value pairs) and sub-nodes.
  /// Data entries are stored first, followed by sub-nodes.
  /// Data: [k1, v1, k2, v2, ...]
  /// Nodes: [..., nodeA, nodeB, ...]
  List<Object?> content; // Made mutable

  // Constructor ensures content is mutable if owned, otherwise unmodifiable
  ChampInternalNode(
    this.dataMap,
    this.nodeMap,
    List<Object?> content, [
    TransientOwner? owner,
  ])
    // Ensure content is mutable if node is transient, otherwise copy to unmodifiable
    : content = (owner != null) ? content : List.unmodifiable(content),
       super(owner);

  /// Factory constructor to create an internal node from two initial nodes.
  /// Used when a data node collides or a collision node needs to split.
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

    return ChampInternalNode<K, V>(
      0, // No data entries initially
      newNodeMap,
      newContent,
      owner, // Pass owner to constructor
    );
  }

  // --- Helper methods for index calculation ---

  int dataIndexFromFragment(int frag) => bitCount(dataMap & ((1 << frag) - 1));
  int nodeIndexFromFragment(int frag) => bitCount(nodeMap & ((1 << frag) - 1));
  int contentIndexFromDataIndex(int dataIndex) => dataIndex * 2;
  int contentIndexFromNodeIndex(int nodeIndex) =>
      (bitCount(dataMap) * 2) + nodeIndex;

  // --- Core Methods ---

  @override
  V? get(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      // Check data entries first
      final dataIndex = dataIndexFromFragment(frag);
      final payloadIndex = contentIndexFromDataIndex(dataIndex);
      // Check if the key matches
      if (content[payloadIndex] == key) {
        return content[payloadIndex + 1] as V;
      }
      return null; // Hash fragment collision, but different key
    } else if ((nodeMap & bitpos) != 0) {
      // Check sub-nodes
      final nodeIndex = nodeIndexFromFragment(frag);
      final contentIdx = contentIndexFromNodeIndex(nodeIndex);
      final subNode = content[contentIdx] as ChampNode<K, V>;
      // Recursively search in the sub-node
      return subNode.get(key, hash, shift + kBitPartitionSize);
    }

    return null; // Not found in this branch
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
        // Collision with existing data entry
        final dataIndex = mutableNode.dataIndexFromFragment(frag);
        final payloadIndex = mutableNode.contentIndexFromDataIndex(dataIndex);
        final currentKey = mutableNode.content[payloadIndex] as K;
        final currentValue = mutableNode.content[payloadIndex + 1] as V;

        if (currentKey == key) {
          // Update existing key
          if (currentValue == value) return (node: mutableNode, didAdd: false);
          mutableNode.content[payloadIndex + 1] = value; // Mutate in place
          return (node: mutableNode, didAdd: false);
        } else {
          // Hash collision, different keys -> create sub-node
          final subNode = mergeDataEntries(
            shift + kBitPartitionSize,
            mutableNode.hashOfKey(currentKey),
            currentKey,
            currentValue,
            hash,
            key,
            value,
          );
          mutableNode._replaceDataWithNodeInPlace(
            dataIndex,
            subNode,
            bitpos,
          ); // Mutate in place
          return (node: mutableNode, didAdd: true);
        }
      } else if ((mutableNode.nodeMap & bitpos) != 0) {
        // Delegate to existing sub-node
        final nodeIndex = mutableNode.nodeIndexFromFragment(frag);
        final contentIdx = mutableNode.contentIndexFromNodeIndex(nodeIndex);
        final subNode = mutableNode.content[contentIdx] as ChampNode<K, V>;
        final addResult = subNode.add(
          key,
          value,
          hash,
          shift + kBitPartitionSize,
          owner,
        ); // Pass owner

        if (identical(addResult.node, subNode))
          return (node: mutableNode, didAdd: addResult.didAdd);

        mutableNode.content[contentIdx] =
            addResult.node; // Update content in place
        return (node: mutableNode, didAdd: addResult.didAdd);
      } else {
        // Empty slot, insert new data entry in place
        final dataIndex = mutableNode.dataIndexFromFragment(frag);
        mutableNode._insertDataEntryInPlace(
          dataIndex,
          key,
          value,
          bitpos,
        ); // Mutate in place
        return (node: mutableNode, didAdd: true);
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        // Collision with existing data entry
        final dataIndex = dataIndexFromFragment(frag);
        final payloadIndex = contentIndexFromDataIndex(dataIndex);
        final currentKey = content[payloadIndex] as K;
        final currentValue = content[payloadIndex + 1] as V;

        if (currentKey == key) {
          // Update existing key
          if (currentValue == value)
            return (node: this, didAdd: false); // No change
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
          // Create new node replacing data with sub-node
          return (
            node: _replaceDataWithNodeImmutable(dataIndex, subNode, bitpos),
            didAdd: true,
          );
        }
      } else if ((nodeMap & bitpos) != 0) {
        // Delegate to existing sub-node
        final nodeIndex = nodeIndexFromFragment(frag);
        final contentIdx = contentIndexFromNodeIndex(nodeIndex);
        final subNode = content[contentIdx] as ChampNode<K, V>;
        final addResult = subNode.add(
          key,
          value,
          hash,
          shift + kBitPartitionSize,
          null,
        ); // No owner

        if (identical(addResult.node, subNode))
          return (node: this, didAdd: addResult.didAdd); // No change

        // Create new content list with updated sub-node
        final newContent = List<Object?>.of(content);
        newContent[contentIdx] = addResult.node;
        return (
          node: ChampInternalNode<K, V>(dataMap, nodeMap, newContent),
          didAdd: addResult.didAdd,
        );
      } else {
        // Empty slot, insert new data entry
        final dataIndex = dataIndexFromFragment(frag);
        // Create new content list with inserted data
        final newContent = List<Object?>.of(content)
          ..insertAll(dataIndex * 2, [key, value]);
        return (
          node: ChampInternalNode<K, V>(dataMap | bitpos, nodeMap, newContent),
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
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if (owner != null) {
      // --- Transient Path ---
      final mutableNode = ensureMutable(owner);

      if ((mutableNode.dataMap & bitpos) != 0) {
        // Check data entries
        final dataIndex = mutableNode.dataIndexFromFragment(frag);
        final payloadIndex = mutableNode.contentIndexFromDataIndex(dataIndex);
        if (mutableNode.content[payloadIndex] == key) {
          // Found the key to remove
          mutableNode._removeDataEntryInPlace(dataIndex, bitpos);
          // Check if node needs shrinking/collapsing
          final newNode = mutableNode._shrinkIfNeeded(owner);
          return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
        }
        return (node: mutableNode, didRemove: false); // Key not found
      } else if ((mutableNode.nodeMap & bitpos) != 0) {
        // Delegate to sub-node
        final nodeIndex = mutableNode.nodeIndexFromFragment(frag);
        final contentIdx = mutableNode.contentIndexFromNodeIndex(nodeIndex);
        final subNode = mutableNode.content[contentIdx] as ChampNode<K, V>;
        final removeResult = subNode.remove(
          key,
          hash,
          shift + kBitPartitionSize,
          owner,
        );

        if (!removeResult.didRemove)
          return (node: mutableNode, didRemove: false);

        // Sub-node changed, update content in place
        mutableNode.content[contentIdx] = removeResult.node;

        // Check if the sub-node became empty or needs merging
        if (removeResult.node.isEmptyNode) {
          // Remove the empty sub-node entry
          mutableNode._removeNodeEntryInPlace(nodeIndex, bitpos);
          // Check if this node needs shrinking
          final newNode = mutableNode._shrinkIfNeeded(owner);
          return (node: newNode ?? ChampEmptyNode<K, V>(), didRemove: true);
        } else if (removeResult.node is ChampDataNode<K, V>) {
          // If sub-node collapsed to a data node, replace node entry with data entry
          final dataNode = removeResult.node as ChampDataNode<K, V>;
          mutableNode._replaceNodeWithDataInPlace(
            nodeIndex,
            dataNode.dataKey,
            dataNode.dataValue,
            bitpos,
          );
          // No need to shrink here as content size didn't change
          return (node: mutableNode, didRemove: true);
        }
        // Sub-node modified but not removed/collapsed, return mutable node
        return (node: mutableNode, didRemove: true);
      }
      return (node: mutableNode, didRemove: false); // Not found
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        // Check data entries
        final dataIndex = dataIndexFromFragment(frag);
        final payloadIndex = contentIndexFromDataIndex(dataIndex);
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
      } else if ((nodeMap & bitpos) != 0) {
        // Delegate to sub-node
        final nodeIndex = nodeIndexFromFragment(frag);
        final contentIdx = contentIndexFromNodeIndex(nodeIndex);
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
              dataIndexFromFragment(frag) * 2; // Index where new data goes

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
          final oldNodeStartIndex = oldDataEnd;
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
            node: ChampInternalNode<K, V>(
              newDataMap,
              newNodeMap,
              newContentList,
            ),
            didRemove: true,
          );
        }
        // Sub-node modified but not removed/collapsed
        return (
          node: ChampInternalNode<K, V>(dataMap, nodeMap, newContent),
          didRemove: true,
        );
      }
      return (node: this, didRemove: false); // Not found
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
        // Check data entries
        final dataIndex = mutableNode.dataIndexFromFragment(frag);
        final payloadIndex = mutableNode.contentIndexFromDataIndex(dataIndex);
        final currentKey = mutableNode.content[payloadIndex] as K;

        if (currentKey == key) {
          // Found key, update value in place
          final currentValue = mutableNode.content[payloadIndex + 1] as V;
          final updatedValue = updateFn(currentValue);
          if (identical(updatedValue, currentValue)) {
            return (
              node: mutableNode,
              sizeChanged: false,
            ); // Value didn't change
          }
          // Mutate value in place
          mutableNode.content[payloadIndex + 1] = updatedValue;
          return (
            node: mutableNode,
            sizeChanged: false,
          ); // Return potentially mutated node
        } else {
          // Hash collision at this level, but keys differ
          if (ifAbsentFn != null) {
            // Convert existing data entry + new entry into a sub-node (collision or internal)
            final newValue = ifAbsentFn();
            final currentVal = mutableNode.content[payloadIndex + 1] as V;
            // mergeDataEntries creates immutable nodes
            final subNode = mergeDataEntries(
              shift + kBitPartitionSize,
              mutableNode.hashOfKey(currentKey),
              currentKey,
              currentVal,
              hash,
              key,
              newValue,
            );
            // Replace data entry with the new sub-node in place
            mutableNode._replaceDataWithNodeInPlace(dataIndex, subNode, bitpos);
            return (node: mutableNode, sizeChanged: true);
          } else {
            // Key not found, no ifAbsentFn
            return (node: mutableNode, sizeChanged: false);
          }
        }
      } else if ((mutableNode.nodeMap & bitpos) != 0) {
        // Check sub-nodes
        final nodeIndex = mutableNode.nodeIndexFromFragment(frag);
        final contentIdx = mutableNode.contentIndexFromNodeIndex(nodeIndex);
        final subNode = mutableNode.content[contentIdx] as ChampNode<K, V>;

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
          return (node: mutableNode, sizeChanged: updateResult.sizeChanged);
        }

        // Update content array in place with the updated sub-node
        mutableNode.content[contentIdx] = updateResult.node;
        return (node: mutableNode, sizeChanged: updateResult.sizeChanged);
      } else {
        // Empty slot
        if (ifAbsentFn != null) {
          // Insert new data entry using ifAbsentFn (in place)
          final newValue = ifAbsentFn();
          final dataIndex = mutableNode.dataIndexFromFragment(frag);
          mutableNode._insertDataEntryInPlace(dataIndex, key, newValue, bitpos);
          return (node: mutableNode, sizeChanged: true);
        } else {
          // Key not found, no ifAbsentFn
          return (node: mutableNode, sizeChanged: false);
        }
      }
    } else {
      // --- Immutable Path ---
      if ((dataMap & bitpos) != 0) {
        // Check data entries
        final dataIndex = dataIndexFromFragment(frag);
        final payloadIndex = contentIndexFromDataIndex(dataIndex);
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
      } else if ((nodeMap & bitpos) != 0) {
        // Check sub-nodes
        final nodeIndex = nodeIndexFromFragment(frag);
        final contentIdx = contentIndexFromNodeIndex(nodeIndex);
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
      } else {
        // Empty slot
        if (ifAbsentFn != null) {
          // Insert new data entry using ifAbsentFn
          final newValue = ifAbsentFn();
          final dataIndex = dataIndexFromFragment(frag);
          final newContent = List<Object?>.of(content)
            ..insertAll(dataIndex * 2, [key, newValue]);
          return (
            node: ChampInternalNode<K, V>(
              dataMap | bitpos,
              nodeMap,
              newContent,
            ),
            sizeChanged: true,
          );
        } else {
          // Key not found, no ifAbsentFn
          return (node: this, sizeChanged: false);
        }
      }
    }
  }

  // --- Transient Helper Methods ---

  /// Returns this node if it's mutable and owned by [owner],
  /// otherwise returns a new mutable copy owned by [owner].
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
      // Make content list unmodifiable
      this.content = List.unmodifiable(content);
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

  void _insertDataEntryInPlace(int dataIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = dataIndex * 2;
    // Insert into the list directly
    content.insertAll(dataPayloadIndex, [key, value]);
    // Update bitmap
    dataMap |= bitpos;
  }

  void _removeDataEntryInPlace(int dataIndex, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex = dataIndex * 2;
    // Remove from the list
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    // Update bitmap
    dataMap ^= bitpos;
  }

  void _removeNodeEntryInPlace(int nodeIndex, int bitpos) {
    assert(isTransient(_owner));
    final dataEndIndex = bitCount(dataMap) * 2;
    final contentNodeIndex = dataEndIndex + nodeIndex;
    // Remove from the list
    content.removeAt(contentNodeIndex);
    // Update bitmap
    nodeMap ^= bitpos;
  }

  /// Replaces a data entry with a sub-node (in place).
  void _replaceDataWithNodeInPlace(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    assert(isTransient(_owner));
    final dataPayloadIndex = dataIndex * 2;

    // --- Calculate node insertion index ---
    // This needs to be based on the fragment corresponding to the bitpos
    final frag = bitCount(
      bitpos - 1,
    ); // Get the index (0-31) from the bit position
    // Calculate where the new node *will* go based on the *final* nodeMap
    final targetNodeMap = nodeMap | bitpos;
    final targetNodeIndex = bitCount(
      targetNodeMap & (bitpos - 1),
    ); // Nodes before the new one

    // --- Modify content list ---
    // 1. Remove the data entry (key, value)
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    // 2. Insert the sub-node at the correct position in the node section
    // The node section starts after the remaining data entries
    final nodeInsertPos = (bitCount(dataMap) - 1) * 2 + targetNodeIndex;
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
  void _replaceNodeWithDataInPlace(int nodeIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final dataPayloadIndex =
        dataIndexFromFragment(indexFragment(0, hashOfKey(key))) *
        2; // Index where new data goes
    final nodeContentIndex = contentIndexFromNodeIndex(nodeIndex);

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
