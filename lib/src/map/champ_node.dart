/// Defines the core structures for CHAMP Trie nodes used by ApexMap.
library;

import 'dart:collection'; // For HashMap equality check
import 'package:collection/collection.dart'; // For bitCount

// --- Transient Ownership ---

/// A marker object to track ownership for transient mutations.
/// Operations using the same owner can mutate nodes in place.
class TransientOwner {
  const TransientOwner();
}

// --- Constants ---

const int kBitPartitionSize =
    5; // Number of bits processed per level (e.g., 5 for 32 branches)
const int kBranchingFactor = 1 << kBitPartitionSize; // 32
const int kBitPartitionMask = kBranchingFactor - 1; // 0x1f

// --- Helper Functions ---

/// Counts the number of set bits (1s) in an integer.
/// Assumes non-negative integer input.
int bitCount(int n) {
  // Simple Kernighan's algorithm
  int count = 0;
  while (n > 0) {
    n &= (n - 1); // Clear the least significant bit set
    count++;
  }
  return count;
}

/// Extracts the fragment of the hash code for the current level.
int indexFragment(int shift, int hash) => (hash >> shift) & kBitPartitionMask;

// --- Result Types ---

/// Result of an add/update operation.
typedef ChampAddResult<K, V> = ({ChampNode<K, V> node, bool didAdd});

/// Result of a remove operation.
typedef ChampRemoveResult<K, V> = ({ChampNode<K, V> node, bool didRemove});

/// Result of an update operation.
typedef ChampUpdateResult<K, V> = ({ChampNode<K, V> node, bool sizeChanged});

// --- Node Base Class ---

/// Base class for CHAMP Trie nodes.
abstract class ChampNode<K, V> {
  /// Optional owner for transient nodes. If non-null, this node might be mutable.
  TransientOwner? _owner; // Made mutable for freezing

  /// Constructor for subclasses.
  ChampNode([this._owner]); // Changed to non-const

  /// Retrieves the value associated with [key], or null if not found.
  V? get(K key, int hash, int shift);

  /// Adds or updates a key-value pair. Returns the new node and whether the size increased.
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Removes a key. Returns the new node and whether an element was actually removed.
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Updates the value associated with [key].
  ///
  /// If the key exists, applies [updateFn] to the existing value.
  /// If the key doesn't exist and [ifAbsentFn] is provided, inserts the result of [ifAbsentFn].
  /// Returns a [ChampUpdateResult] indicating the new node and if the map size changed.
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
    TransientOwner? owner,
  });

  /// Returns true if this node represents the canonical empty node.
  bool get isEmptyNode => false;

  /// Returns true if this node is marked as transient and owned by [owner].
  bool isTransient(TransientOwner? owner) => owner != null && _owner == owner;

  /// Returns an immutable version of this node.
  ChampNode<K, V> freeze(TransientOwner? owner);
}

// --- Node Implementations ---

/// Represents an empty CHAMP Trie node.
class ChampEmptyNode<K, V> extends ChampNode<K, V> {
  ChampEmptyNode() : super(null); // Always immutable

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
    // Adding to empty creates a new data node. Owner is irrelevant.
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
    // Removing from empty does nothing.
    return (node: this, didRemove: false);
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
      // Key doesn't exist, insert if ifAbsentFn is provided
      final newValue = ifAbsentFn();
      final newNode = ChampDataNode<K, V>(hash, key, newValue);
      return (node: newNode, sizeChanged: true);
    } else {
      // Key doesn't exist, no ifAbsentFn, return empty node, no size change
      return (node: this, sizeChanged: false);
    }
  }

  @override
  bool get isEmptyNode => true;

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) => this; // Already immutable
}

/// Represents a node containing a single key-value pair.
class ChampDataNode<K, V> extends ChampNode<K, V> {
  final int hash; // Full hash code of the key
  final K key;
  final V value;

  ChampDataNode(this.hash, this.key, this.value)
    : super(null); // Always immutable

  @override
  V? get(K key, int hash, int shift) {
    return (this.hash == hash && this.key == key) ? value : null;
  }

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    // DataNodes are always immutable, owner is ignored.
    if (key == this.key) {
      // Update existing key if value is different
      if (value == this.value) {
        return (node: this, didAdd: false); // No change
      }
      return (
        node: ChampDataNode(hash, key, value), // Create new immutable node
        didAdd: false,
      ); // Updated value
    }

    // Collision: create an internal node or collision node (always immutable from here)
    final newNode = mergeDataEntries(
      shift,
      this.hash,
      this.key,
      this.value,
      hash,
      key,
      value,
    );
    return (node: newNode, didAdd: true); // Added a new distinct entry
  }

  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (this.hash == hash && this.key == key) {
      // Found the key, remove it by returning a new empty node.
      return (node: ChampEmptyNode<K, V>(), didRemove: true);
    }
    // Key not found.
    return (node: this, didRemove: false);
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
    if (key == this.key) {
      // Key found, apply updateFn
      final updatedValue = updateFn(this.value);
      // If value is identical, return original node
      if (identical(updatedValue, this.value)) {
        return (node: this, sizeChanged: false);
      }
      // Return new data node with updated value
      return (
        node: ChampDataNode(this.hash, this.key, updatedValue),
        sizeChanged: false,
      );
    } else {
      // Key not found at this node (hash collision occurred earlier or different key)
      if (ifAbsentFn != null) {
        // Treat as adding a new key which causes a collision at this level
        final newValue = ifAbsentFn();
        // Let's use mergeDataEntries which handles this logic
        final newNode = mergeDataEntries(
          shift, // Use current shift level for merging decision
          this.hash,
          this.key,
          this.value,
          hash,
          key,
          newValue,
        );
        return (node: newNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn, return original node
        return (node: this, sizeChanged: false);
      }
    }
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) => this; // Already immutable
}

/// Represents a node containing multiple entries that have the same hash fragment
/// up to a certain level, but different full hash codes or different keys.
class ChampCollisionNode<K, V> extends ChampNode<K, V> {
  final int hash; // The hash code common to all entries in this node
  // Entries list is mutable only if the node is transient
  List<MapEntry<K, V>> entries;

  ChampCollisionNode(
    this.hash,
    List<MapEntry<K, V>> entries, [
    TransientOwner? owner,
  ])
    // Ensure entries list is mutable if node is transient, otherwise copy to unmodifiable
    : entries = (owner != null) ? entries : List.unmodifiable(entries),
       assert(entries.length >= 2),
       super(owner);

  ChampCollisionNode<K, V> ensureMutable(TransientOwner? owner) {
    if (isTransient(owner)) {
      return this;
    }
    // Create a mutable copy with the new owner
    return ChampCollisionNode<K, V>(
      hash,
      List<MapEntry<K, V>>.of(entries), // Create mutable list copy
      owner, // Assign the new owner
    );
  }

  @override
  V? get(K key, int hash, int shift) {
    if (this.hash != hash) return null; // Hash must match
    for (final entry in entries) {
      if (entry.key == key) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  ChampAddResult<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    assert(hash == this.hash); // Hash must match

    final mutableNode = ensureMutable(owner);

    for (int i = 0; i < mutableNode.entries.length; i++) {
      if (mutableNode.entries[i].key == key) {
        // Key exists, update value if different
        if (mutableNode.entries[i].value == value) {
          // Return original node if immutable, or mutated node if transient
          return (node: mutableNode, didAdd: false);
        }
        // Mutate in place
        mutableNode.entries[i] = MapEntry(key, value);
        return (node: mutableNode, didAdd: false); // Updated
      }
    }

    // Key doesn't exist, add new entry (mutate in place)
    mutableNode.entries.add(MapEntry(key, value));
    return (node: mutableNode, didAdd: true); // Added
  }

  @override
  ChampRemoveResult<K, V> remove(
    K key,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    assert(hash == this.hash); // Hash must match

    int foundIndex = -1;
    for (int i = 0; i < entries.length; i++) {
      if (entries[i].key == key) {
        foundIndex = i;
        break;
      }
    }

    if (foundIndex == -1) {
      return (node: this, didRemove: false); // Key not found
    }

    final mutableNode = ensureMutable(owner);

    if (mutableNode.entries.length == 2) {
      // Removing one leaves only one entry, convert back to DataNode
      final remainingEntry =
          mutableNode.entries[1 - foundIndex]; // Get the other entry
      // Create a new immutable DataNode
      final newNode = ChampDataNode<K, V>(
        hash, // Hash is the same
        remainingEntry.key,
        remainingEntry.value,
      );
      return (node: newNode, didRemove: true);
    } else {
      // More than 2 entries remain, remove from list (mutate in place)
      mutableNode.entries.removeAt(foundIndex);
      return (node: mutableNode, didRemove: true);
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
    assert(hash == this.hash); // Hash must match for collision node

    final mutableNode = ensureMutable(owner);

    int foundIndex = -1;
    V? oldValue;
    for (int i = 0; i < mutableNode.entries.length; i++) {
      if (mutableNode.entries[i].key == key) {
        foundIndex = i;
        oldValue = mutableNode.entries[i].value;
        break;
      }
    }

    if (foundIndex != -1) {
      // Key found, apply updateFn
      final updatedValue = updateFn(oldValue!);
      if (identical(updatedValue, oldValue)) {
        return (node: mutableNode, sizeChanged: false); // Value didn't change
      }
      // Mutate list in place
      mutableNode.entries[foundIndex] = MapEntry(key, updatedValue);
      return (node: mutableNode, sizeChanged: false);
    } else {
      // Key not found in collision list
      if (ifAbsentFn != null) {
        // Add new entry using ifAbsentFn (mutate in place)
        final newValue = ifAbsentFn();
        mutableNode.entries.add(MapEntry(key, newValue));
        return (node: mutableNode, sizeChanged: true);
      } else {
        // Key not found, no ifAbsentFn, return original node
        return (node: mutableNode, sizeChanged: false);
      }
    }
  }

  @override
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      this._owner = null; // Remove owner
      this.entries = List.unmodifiable(entries); // Make list unmodifiable
      return this;
    }
    return this; // Already immutable or not owned
  }
}

/// Represents an internal node containing references to sub-nodes and/or data entries.
class ChampInternalNode<K, V> extends ChampNode<K, V> {
  /// Bitmap indicating the presence of data entries.
  int dataMap; // Made mutable

  /// Bitmap indicating the presence of sub-nodes.
  int nodeMap; // Made mutable

  /// Array storing data entries (key, value pairs) and sub-nodes.
  /// Data entries are stored first, followed by sub-nodes.
  /// Data: [k1, v1, k2, v2, ...]
  /// Nodes: [..., nodeA, nodeB, ...]
  List<Object?> content; // Made mutable

  // Content list is mutable only if the node is transient
  ChampInternalNode(
    this.dataMap,
    this.nodeMap,
    List<Object?> content, [
    TransientOwner? owner,
  ])
    // Ensure content is mutable if node is transient, otherwise copy to unmodifiable
    : content = (owner != null) ? content : List.unmodifiable(content),
       super(owner);

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
    // Ensure node is mutable if we have the correct owner
    final mutableNode = ensureMutable(owner);

    // Use mutableNode fields directly now
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((mutableNode.dataMap & bitpos) != 0) {
      // Collision with existing data entry
      final dataIndex = mutableNode.dataIndexFromFragment(frag);
      final payloadIndex = mutableNode.contentIndexFromDataIndex(dataIndex);
      final currentKey = mutableNode.content[payloadIndex] as K;
      final currentValue = mutableNode.content[payloadIndex + 1] as V;

      if (currentKey == key) {
        // Update existing key
        if (currentValue == value)
          return (node: mutableNode, didAdd: false); // No change

        // Mutate in place
        mutableNode.content[payloadIndex + 1] = value;
        return (node: mutableNode, didAdd: false);
      } else {
        // Hash collision, different keys - need to create a sub-node
        // mergeDataEntries creates immutable nodes, which is fine here
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          mutableNode.hashOfKey(currentKey), // Use helper on mutable node
          currentKey,
          currentValue,
          hash,
          key,
          value,
        );
        // Replace data entry with the new sub-node in place
        mutableNode._replaceDataWithNodeInPlace(dataIndex, subNode, bitpos);
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
        owner, // Pass owner down for potential transient mutation
      );

      // If sub-node didn't change identity, we don't need to update content
      if (identical(addResult.node, subNode)) {
        // Pass back the original mutable node, but use the didAdd result from below
        return (node: mutableNode, didAdd: addResult.didAdd);
      }

      // Update the content array in place with the new sub-node
      mutableNode.content[contentIdx] = addResult.node;
      return (node: mutableNode, didAdd: addResult.didAdd);
    } else {
      // Empty slot, insert new data entry in place
      final dataIndex = mutableNode.dataIndexFromFragment(frag);
      mutableNode._insertDataEntryInPlace(dataIndex, key, value, bitpos);
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
    final mutableNode = ensureMutable(owner);
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((mutableNode.dataMap & bitpos) != 0) {
      // Check data entries
      final dataIndex = mutableNode.dataIndexFromFragment(frag);
      final payloadIndex = mutableNode.contentIndexFromDataIndex(dataIndex);
      if (mutableNode.content[payloadIndex] == key) {
        // Found the key to remove
        mutableNode._removeDataEntryInPlace(dataIndex, bitpos);

        // Check if node needs shrinking/collapsing
        if (mutableNode.nodeMap == 0 && bitCount(mutableNode.dataMap) == 1) {
          // Only one data entry left, collapse to DataNode
          // Find the remaining entry (must be at index 0 of content now)
          final lastKey = mutableNode.content[0] as K;
          final lastValue = mutableNode.content[1] as V;
          final lastHash = hashOfKey(lastKey);
          return (
            node: ChampDataNode(
              lastHash,
              lastKey,
              lastValue,
            ), // Return immutable DataNode
            didRemove: true,
          );
        }
        // If node became empty after removal
        if (mutableNode.dataMap == 0 && mutableNode.nodeMap == 0) {
          return (node: ChampEmptyNode<K, V>(), didRemove: true);
        }

        return (node: mutableNode, didRemove: true);
      }
      // Hash fragment collision, but different key
      // Key not found in this branch, return potentially mutated node
      return (node: mutableNode, didRemove: false);
    } else if ((mutableNode.nodeMap & bitpos) != 0) {
      // Check sub-nodes
      final nodeIndex = mutableNode.nodeIndexFromFragment(frag);
      final contentIdx = mutableNode.contentIndexFromNodeIndex(nodeIndex);
      final subNode = mutableNode.content[contentIdx] as ChampNode<K, V>;
      final removeResult = subNode.remove(
        key,
        hash,
        shift + kBitPartitionSize,
        owner,
      );

      if (identical(removeResult.node, subNode)) {
        return (node: mutableNode, didRemove: false); // Not found in sub-tree
      }

      final newNode = removeResult.node;

      // Check if the sub-node became empty or needs collapsing
      if (newNode.isEmptyNode) {
        // Remove the sub-node entry entirely in place
        mutableNode._removeNodeEntryInPlace(nodeIndex, bitpos);

        // If only one data entry remains, collapse to DataNode
        if (mutableNode.nodeMap == 0 && bitCount(mutableNode.dataMap) == 1) {
          final lastKey = mutableNode.content[0] as K;
          final lastValue = mutableNode.content[1] as V;
          final lastHash = hashOfKey(lastKey);
          return (
            node: ChampDataNode(
              lastHash,
              lastKey,
              lastValue,
            ), // Return immutable DataNode
            didRemove: true,
          );
        }
        // If node became empty after removal
        if (mutableNode.dataMap == 0 && mutableNode.nodeMap == 0) {
          return (node: ChampEmptyNode<K, V>(), didRemove: true);
        }
        return (node: mutableNode, didRemove: true);
      } else if (newNode is ChampDataNode<K, V>) {
        // Sub-node collapsed into a DataNode, replace node entry with data entry in place
        mutableNode._replaceNodeWithDataInPlace(
          nodeIndex,
          newNode.key,
          newNode.value,
          bitpos,
        );
        return (node: mutableNode, didRemove: true);
      } else {
        // Sub-node changed but didn't collapse/empty, update in place
        mutableNode.content[contentIdx] = newNode;
        return (node: mutableNode, didRemove: true);
      }
    }

    // Key not found in this branch
    return (node: mutableNode, didRemove: false);
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
    final mutableNode = ensureMutable(owner);
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((mutableNode.dataMap & bitpos) != 0) {
      // Check data entries
      final dataIndex = mutableNode.dataIndexFromFragment(frag);
      final payloadIndex = mutableNode.contentIndexFromDataIndex(dataIndex);
      final currentKey = mutableNode.content[payloadIndex] as K;

      if (currentKey == key) {
        // Key found in data payload
        final currentValue = mutableNode.content[payloadIndex + 1] as V;
        final updatedValue = updateFn(currentValue);
        if (identical(updatedValue, currentValue)) {
          return (node: mutableNode, sizeChanged: false); // Value didn't change
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
      List<Object?>.of(content), // Create mutable list copy
      owner, // Assign the new owner
    );
  }

  /// Returns an immutable version of this node.
  /// If the node is transient and owned by [owner], it's frozen (owner set to null).
  /// Otherwise, returns itself (if already immutable).
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

  void _replaceDataWithNodeInPlace(
    int dataIndex,
    ChampNode<K, V> subNode,
    int bitpos,
  ) {
    assert(isTransient(_owner));
    final dataPayloadIndex = dataIndex * 2;
    final newNodeIndex = bitCount(
      nodeMap,
    ); // Index within the node section (before adding new node)
    final newContentNodeIndex =
        (bitCount(dataMap) - 1) * 2 + newNodeIndex; // Index for new node

    // Remove the two data slots
    content.removeRange(dataPayloadIndex, dataPayloadIndex + 2);
    // Insert the node at the correct position relative to other nodes
    content.insert(newContentNodeIndex, subNode);

    // Update bitmaps
    dataMap ^= bitpos; // Remove data bit
    nodeMap |= bitpos; // Add node bit
  }

  void _replaceNodeWithDataInPlace(int nodeIndex, K key, V value, int bitpos) {
    assert(isTransient(_owner));
    final dataEndIndex = bitCount(dataMap) * 2; // OLD dataMap count
    final contentNodeIndex = dataEndIndex + nodeIndex;
    final newDataIndex = bitCount(
      dataMap,
    ); // Index within the data section (before adding new data)
    final newContentDataIndex = newDataIndex * 2;

    // Remove the node entry
    content.removeAt(contentNodeIndex);
    // Insert the data entry at the correct position relative to other data
    content.insertAll(newContentDataIndex, [key, value]);

    // Update bitmaps
    nodeMap ^= bitpos; // Remove node bit
    dataMap |= bitpos; // Add data bit
  }

  // Helper to get the hash of a key (assuming non-null keys for now)
  // TODO: Handle null keys if necessary
  int hashOfKey(K key) => key.hashCode;
}

// --- Helper Functions for Node Creation ---

/// Merges two data entries into a new node (either Internal or Collision).
/// Always creates immutable nodes.
ChampNode<K, V> mergeDataEntries<K, V>(
  int shift,
  int hash1,
  K key1,
  V value1,
  int hash2,
  K key2,
  V value2,
) {
  assert(key1 != key2); // Keys must be different if merging

  if (shift >= 32) {
    // Max shift level reached, must be a collision node
    return ChampCollisionNode<K, V>(hash1, [
      MapEntry(key1, value1),
      MapEntry(key2, value2),
    ]);
  }

  final frag1 = indexFragment(shift, hash1);
  final frag2 = indexFragment(shift, hash2);

  if (frag1 != frag2) {
    // Fragments differ, create an internal node with two data entries
    final bitpos1 = 1 << frag1;
    final bitpos2 = 1 << frag2;
    final newDataMap = bitpos1 | bitpos2;
    // Order entries based on fragment index
    if (frag1 < frag2) {
      return ChampInternalNode<K, V>(newDataMap, 0, [
        key1,
        value1,
        key2,
        value2,
      ]);
    } else {
      return ChampInternalNode<K, V>(newDataMap, 0, [
        key2,
        value2,
        key1,
        value1,
      ]);
    }
  } else {
    // Fragments are the same, recurse deeper
    final subNode = mergeDataEntries(
      shift + kBitPartitionSize, // Use correct constant
      hash1,
      key1,
      value1,
      hash2,
      key2,
      value2,
    );
    final bitpos = 1 << frag1;
    final newNodeMap = bitpos; // Only contains the new sub-node
    return ChampInternalNode<K, V>(0, newNodeMap, [subNode]);
  }
}
