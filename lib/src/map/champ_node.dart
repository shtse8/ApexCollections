/// Defines the core structures for CHAMP Trie nodes used by ApexMap.
library;

import 'dart:collection'; // For HashMap equality check
import 'package:collection/collection.dart'; // For bitCount

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
  /// Const constructor for subclasses.
  const ChampNode();

  /// Retrieves the value associated with [key], or null if not found.
  V? get(K key, int hash, int shift);

  /// Adds or updates a key-value pair. Returns the new node and whether the size increased.
  ChampAddResult<K, V> add(K key, V value, int hash, int shift);

  /// Removes a key. Returns the new node and whether an element was actually removed.
  ChampRemoveResult<K, V> remove(K key, int hash, int shift);

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
  });

  /// Returns true if this node represents the canonical empty node.
  bool get isEmptyNode => false;
}

// --- Node Implementations ---

/// Represents an empty CHAMP Trie node.
class ChampEmptyNode<K, V> extends ChampNode<K, V> {
  // No static instance needed anymore, create on demand.

  const ChampEmptyNode(); // Public const constructor

  @override
  V? get(K key, int hash, int shift) => null;

  @override
  ChampAddResult<K, V> add(K key, V value, int hash, int shift) {
    // Adding to empty creates a new data node.
    final newNode = ChampDataNode<K, V>(hash, key, value);
    return (node: newNode, didAdd: true);
  }

  @override
  ChampRemoveResult<K, V> remove(K key, int hash, int shift) {
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
}

/// Represents a node containing a single key-value pair.
/// Used when a hash collision occurs but keys are different, or as leaf nodes initially.
class ChampDataNode<K, V> extends ChampNode<K, V> {
  final int hash; // Full hash code of the key
  final K key;
  final V value;

  const ChampDataNode(this.hash, this.key, this.value);

  @override
  V? get(K key, int hash, int shift) {
    return (this.hash == hash && this.key == key) ? value : null;
  }

  @override
  ChampAddResult<K, V> add(K key, V value, int hash, int shift) {
    if (key == this.key) {
      // Update existing key if value is different
      if (value == this.value) {
        return (node: this, didAdd: false); // No change
      }
      return (
        node: ChampDataNode(hash, key, value),
        didAdd: false,
      ); // Updated value
    }

    // Collision: create an internal node or collision node
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
  ChampRemoveResult<K, V> remove(K key, int hash, int shift) {
    if (this.hash == hash && this.key == key) {
      // Found the key, remove it by returning the empty node.
      // Found the key, remove it by returning a new empty node.
      return (
        node: ChampEmptyNode<K, V>(),
        didRemove: true,
      ); // Cannot be const here
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
  }) {
    if (key == this.key) {
      // Key found, apply updateFn
      final updatedValue = updateFn(value);
      // If value is identical, return original node
      if (identical(updatedValue, value)) {
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
        // Need to decide if collision node or internal node is appropriate here
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
}

/// Represents a node containing multiple entries that have the same hash fragment
/// up to a certain level, but different full hash codes or different keys.
class ChampCollisionNode<K, V> extends ChampNode<K, V> {
  final int hash; // The hash code common to all entries in this node
  final List<MapEntry<K, V>> entries;

  const ChampCollisionNode(this.hash, this.entries)
    : assert(entries.length >= 2);

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
  ChampAddResult<K, V> add(K key, V value, int hash, int shift) {
    assert(hash == this.hash); // Hash must match

    for (int i = 0; i < entries.length; i++) {
      if (entries[i].key == key) {
        // Key exists, update value if different
        if (entries[i].value == value) {
          return (node: this, didAdd: false); // No change
        }
        final newEntries = List<MapEntry<K, V>>.of(entries);
        newEntries[i] = MapEntry(key, value);
        return (
          node: ChampCollisionNode(hash, newEntries),
          didAdd: false,
        ); // Updated
      }
    }

    // Key doesn't exist, add new entry
    final newEntries = [...entries, MapEntry(key, value)];
    return (node: ChampCollisionNode(hash, newEntries), didAdd: true); // Added
  }

  @override
  ChampRemoveResult<K, V> remove(K key, int hash, int shift) {
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

    if (entries.length == 2) {
      // Removing one leaves only one entry, convert back to DataNode
      final remainingEntry = entries[1 - foundIndex]; // Get the other entry
      final newNode = ChampDataNode<K, V>(
        hash, // Hash is the same
        remainingEntry.key,
        remainingEntry.value,
      );
      return (node: newNode, didRemove: true);
    } else {
      // More than 2 entries remain, create a new CollisionNode
      final newEntries = List<MapEntry<K, V>>.of(entries);
      newEntries.removeAt(foundIndex);
      final newNode = ChampCollisionNode<K, V>(hash, newEntries);
      return (node: newNode, didRemove: true);
    }
  }

  @override
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
  }) {
    assert(hash == this.hash); // Hash must match for collision node

    int foundIndex = -1;
    V? oldValue;
    for (int i = 0; i < entries.length; i++) {
      if (entries[i].key == key) {
        foundIndex = i;
        oldValue = entries[i].value;
        break;
      }
    }

    if (foundIndex != -1) {
      // Key found, apply updateFn
      final updatedValue = updateFn(oldValue!);
      if (identical(updatedValue, oldValue)) {
        return (node: this, sizeChanged: false); // Value didn't change
      }
      // Create new list with updated entry
      final newEntries = List<MapEntry<K, V>>.of(entries);
      newEntries[foundIndex] = MapEntry(key, updatedValue);
      return (
        node: ChampCollisionNode(this.hash, newEntries),
        sizeChanged: false,
      );
    } else {
      // Key not found in collision list
      if (ifAbsentFn != null) {
        // Add new entry using ifAbsentFn
        final newValue = ifAbsentFn();
        final newEntries = [...entries, MapEntry(key, newValue)];
        return (
          node: ChampCollisionNode(this.hash, newEntries),
          sizeChanged: true,
        );
      } else {
        // Key not found, no ifAbsentFn, return original node
        return (node: this, sizeChanged: false);
      }
    }
  }
}

/// Represents an internal node containing references to sub-nodes and/or data entries.
class ChampInternalNode<K, V> extends ChampNode<K, V> {
  /// Bitmap indicating the presence of data entries.
  final int dataMap;

  /// Bitmap indicating the presence of sub-nodes.
  final int nodeMap;

  /// Array storing data entries (key, value pairs) and sub-nodes.
  /// Data entries are stored first, followed by sub-nodes.
  /// Data: [k1, v1, k2, v2, ...]
  /// Nodes: [..., nodeA, nodeB, ...]
  final List<Object?> content;

  const ChampInternalNode(this.dataMap, this.nodeMap, this.content);

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
  ChampAddResult<K, V> add(K key, V value, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

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
        final newContent = List<Object?>.of(content);
        newContent[payloadIndex + 1] = value;
        return (
          node: ChampInternalNode(dataMap, nodeMap, newContent),
          didAdd: false,
        );
      } else {
        // Hash collision, different keys
        final subNode = mergeDataEntries(
          shift + kBitPartitionSize,
          this.hashOfKey(currentKey),
          currentKey,
          currentValue,
          hash,
          key,
          value,
        );
        // Replace data entry with the new sub-node
        final newDataMap = dataMap ^ bitpos; // Remove data bit
        final newNodeMap = nodeMap | bitpos; // Add node bit
        final newContent = replaceDataWithNode(dataIndex, subNode);
        return (
          node: ChampInternalNode(newDataMap, newNodeMap, newContent),
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
      );

      if (identical(addResult.node, subNode))
        return (node: this, didAdd: false); // No change below

      final newContent = List<Object?>.of(content);
      newContent[contentIdx] = addResult.node;
      return (
        node: ChampInternalNode(dataMap, nodeMap, newContent),
        didAdd: addResult.didAdd,
      );
    } else {
      // Empty slot, insert new data entry
      final dataIndex = dataIndexFromFragment(frag);
      final newDataMap = dataMap | bitpos;
      final newContent = insertDataEntry(dataIndex, key, value);
      return (
        node: ChampInternalNode(newDataMap, nodeMap, newContent),
        didAdd: true,
      );
    }
  }

  @override
  ChampRemoveResult<K, V> remove(K key, int hash, int shift) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      // Check data entries
      final dataIndex = dataIndexFromFragment(frag);
      final payloadIndex = contentIndexFromDataIndex(dataIndex);
      if (content[payloadIndex] == key) {
        // Found the key to remove
        final newDataMap = dataMap ^ bitpos; // Remove data bit
        final newContent = removeDataEntry(dataIndex);

        // Check if node needs shrinking/collapsing
        if (nodeMap == 0 && bitCount(newDataMap) == 1) {
          // Only one data entry left, collapse to DataNode
          final lastDataIndex = bitCount(
            newDataMap & (bitpos - 1),
          ); // Find index of remaining entry
          final lastPayloadIndex = lastDataIndex * 2;
          final lastKey = newContent[lastPayloadIndex] as K;
          final lastValue = newContent[lastPayloadIndex + 1] as V;
          // Need the hash of the remaining key
          final lastHash = hashOfKey(lastKey); // Assume hashOfKey exists
          return (
            node: ChampDataNode(lastHash, lastKey, lastValue),
            didRemove: true,
          );
        }

        return (
          node: ChampInternalNode(newDataMap, nodeMap, newContent),
          didRemove: true,
        );
      }
      return (
        node: this,
        didRemove: false,
      ); // Hash fragment collision, but different key
    } else if ((nodeMap & bitpos) != 0) {
      // Check sub-nodes
      final nodeIndex = nodeIndexFromFragment(frag);
      final contentIdx = contentIndexFromNodeIndex(nodeIndex);
      final subNode = content[contentIdx] as ChampNode<K, V>;
      final removeResult = subNode.remove(key, hash, shift + kBitPartitionSize);

      if (identical(removeResult.node, subNode)) {
        return (node: this, didRemove: false); // Not found in sub-tree
      }

      final newNode = removeResult.node;

      // Check if the sub-node became empty or needs collapsing
      if (newNode.isEmptyNode) {
        // Remove the sub-node entry entirely
        final newNodeMap = nodeMap ^ bitpos; // Remove node bit
        final newContent = removeNodeEntry(nodeIndex);

        // If only one data entry remains, collapse to DataNode
        if (newNodeMap == 0 && bitCount(dataMap) == 1) {
          final lastDataIndex = 0; // Only one data entry left
          final lastPayloadIndex = lastDataIndex * 2;
          final lastKey = newContent[lastPayloadIndex] as K;
          final lastValue = newContent[lastPayloadIndex + 1] as V;
          final lastHash = hashOfKey(lastKey);
          return (
            node: ChampDataNode(lastHash, lastKey, lastValue),
            didRemove: true,
          );
        }
        return (
          node: ChampInternalNode(dataMap, newNodeMap, newContent),
          didRemove: true,
        );
      } else if (newNode is ChampDataNode<K, V>) {
        // Sub-node collapsed into a DataNode, replace node entry with data entry
        final newNodeMap = nodeMap ^ bitpos; // Remove node bit
        final newDataMap = dataMap | bitpos; // Add data bit
        final newContent = replaceNodeWithData(
          nodeIndex,
          newNode.key,
          newNode.value,
        );
        return (
          node: ChampInternalNode(newDataMap, newNodeMap, newContent),
          didRemove: true,
        );
      } else {
        // Sub-node changed but didn't collapse/empty
        final newContent = List<Object?>.of(content);
        newContent[contentIdx] = newNode;
        return (
          node: ChampInternalNode(dataMap, nodeMap, newContent),
          didRemove: true,
        );
      }
    }

    return (node: this, didRemove: false); // Key not found in this branch
  }

  @override
  ChampUpdateResult<K, V> update(
    K key,
    int hash,
    int shift,
    V Function(V value) updateFn, {
    V Function()? ifAbsentFn,
  }) {
    final frag = indexFragment(shift, hash);
    final bitpos = 1 << frag;

    if ((dataMap & bitpos) != 0) {
      // Check data entries
      final dataIndex = dataIndexFromFragment(frag);
      final payloadIndex = contentIndexFromDataIndex(dataIndex);
      final currentKey = content[payloadIndex] as K;

      if (currentKey == key) {
        // Key found in data payload
        final currentValue = content[payloadIndex + 1] as V;
        final updatedValue = updateFn(currentValue);
        if (identical(updatedValue, currentValue)) {
          return (node: this, sizeChanged: false); // Value didn't change
        }
        // Create new node with updated value in content array
        final newContent = List<Object?>.of(content);
        newContent[payloadIndex + 1] = updatedValue;
        return (
          node: ChampInternalNode(dataMap, nodeMap, newContent),
          sizeChanged: false,
        );
      } else {
        // Hash collision at this level, but keys differ
        if (ifAbsentFn != null) {
          // Convert existing data entry + new entry into a sub-node (collision or internal)
          final newValue = ifAbsentFn();
          final currentVal = content[payloadIndex + 1] as V;
          final subNode = mergeDataEntries(
            shift + kBitPartitionSize, // Use correct constant
            this.hashOfKey(currentKey),
            currentKey,
            currentVal,
            hash,
            key,
            newValue,
          );
          // Replace data entry with the new sub-node
          final newDataMap = dataMap ^ bitpos; // Remove data bit
          final newNodeMap = nodeMap | bitpos; // Add node bit
          final newContent = replaceDataWithNode(dataIndex, subNode);
          return (
            node: ChampInternalNode(newDataMap, newNodeMap, newContent),
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
        ifAbsentFn: ifAbsentFn, // Use correct constant
      );

      // If sub-node didn't change, return original node
      if (identical(updateResult.node, subNode)) {
        return (node: this, sizeChanged: false);
      }

      // Create new internal node with the updated sub-node
      final newContent = List<Object?>.of(content);
      newContent[contentIdx] = updateResult.node;
      return (
        node: ChampInternalNode(dataMap, nodeMap, newContent),
        sizeChanged: updateResult.sizeChanged,
      );
    } else {
      // Empty slot
      if (ifAbsentFn != null) {
        // Insert new data entry using ifAbsentFn
        final newValue = ifAbsentFn();
        final newDataMap = dataMap | bitpos; // Add data bit
        final newContent = insertDataEntry(
          dataIndexFromFragment(frag),
          key,
          newValue,
        ); // Use correct constant
        return (
          node: ChampInternalNode(newDataMap, nodeMap, newContent),
          sizeChanged: true,
        );
      } else {
        // Key not found, no ifAbsentFn
        return (node: this, sizeChanged: false);
      }
    }
  }

  // --- Helper methods for content manipulation ---

  /// Creates a new content array by inserting a data entry.
  List<Object?> insertDataEntry(int dataIndex, K key, V value) {
    final dataPayloadIndex = dataIndex * 2;
    final nodeStartIndex = bitCount(dataMap) * 2;
    final newContent = List<Object?>.filled(content.length + 2, null);

    // Copy elements before insertion point
    List.copyRange(newContent, 0, content, 0, dataPayloadIndex);
    // Insert new data entry
    newContent[dataPayloadIndex] = key;
    newContent[dataPayloadIndex + 1] = value;
    // Copy elements after insertion point
    List.copyRange(
      newContent,
      dataPayloadIndex + 2,
      content,
      dataPayloadIndex,
      nodeStartIndex,
    );
    // Copy node entries
    List.copyRange(
      newContent,
      nodeStartIndex + 2,
      content,
      nodeStartIndex,
      content.length,
    );

    return newContent;
  }

  /// Creates a new content array by removing a data entry.
  List<Object?> removeDataEntry(int dataIndex) {
    final dataPayloadIndex = dataIndex * 2;
    final nodeStartIndex = bitCount(dataMap) * 2; // Based on OLD dataMap
    final newContent = List<Object?>.filled(content.length - 2, null);

    // Copy elements before removal point
    List.copyRange(newContent, 0, content, 0, dataPayloadIndex);
    // Copy elements after removal point (data part)
    List.copyRange(
      newContent,
      dataPayloadIndex,
      content,
      dataPayloadIndex + 2,
      nodeStartIndex,
    );
    // Copy node entries (adjusting destination index)
    List.copyRange(
      newContent,
      nodeStartIndex - 2,
      content,
      nodeStartIndex,
      content.length,
    );

    return newContent;
  }

  /// Creates a new content array by removing a node entry.
  List<Object?> removeNodeEntry(int nodeIndex) {
    final dataEndIndex = bitCount(dataMap) * 2;
    final contentNodeIndex = dataEndIndex + nodeIndex;
    final newContent = List<Object?>.filled(content.length - 1, null);

    // Copy data entries
    List.copyRange(newContent, 0, content, 0, dataEndIndex);
    // Copy node entries before removal point
    List.copyRange(
      newContent,
      dataEndIndex,
      content,
      dataEndIndex,
      contentNodeIndex,
    );
    // Copy node entries after removal point
    List.copyRange(
      newContent,
      contentNodeIndex,
      content,
      contentNodeIndex + 1,
      content.length,
    );

    return newContent;
  }

  /// Creates a new content array replacing a data entry with a sub-node.
  List<Object?> replaceDataWithNode(int dataIndex, ChampNode<K, V> subNode) {
    final dataPayloadIndex = dataIndex * 2;
    final nodeStartIndex = bitCount(dataMap) * 2; // OLD dataMap count
    final newNodeIndex = bitCount(
      nodeMap,
    ); // Index within the node section (NEW nodeMap)
    final newContentNodeIndex =
        (bitCount(dataMap) - 1) * 2 +
        newNodeIndex; // Adjusted index in newContent

    final newContent = List<Object?>.filled(
      content.length - 1,
      null,
    ); // Size decreases by 1 (2 data -> 1 node)

    // Copy data before removed entry
    List.copyRange(newContent, 0, content, 0, dataPayloadIndex);
    // Copy data after removed entry
    List.copyRange(
      newContent,
      dataPayloadIndex,
      content,
      dataPayloadIndex + 2,
      nodeStartIndex,
    );
    // Copy nodes before insertion point
    List.copyRange(
      newContent,
      nodeStartIndex - 2,
      content,
      nodeStartIndex,
      nodeStartIndex + newNodeIndex,
    );
    // Insert the new subNode
    newContent[newContentNodeIndex] = subNode;
    // Copy nodes after insertion point
    List.copyRange(
      newContent,
      newContentNodeIndex + 1,
      content,
      nodeStartIndex + newNodeIndex,
      content.length,
    );

    return newContent;
  }

  /// Creates a new content array replacing a sub-node with a data entry.
  List<Object?> replaceNodeWithData(int nodeIndex, K key, V value) {
    final dataEndIndex = bitCount(dataMap) * 2; // OLD dataMap count
    final contentNodeIndex = dataEndIndex + nodeIndex;
    final newDataIndex = bitCount(
      dataMap,
    ); // Index within the data section (NEW dataMap)
    final newContentDataIndex = newDataIndex * 2;

    final newContent = List<Object?>.filled(
      content.length + 1,
      null,
    ); // Size increases by 1 (1 node -> 2 data)

    // Copy existing data entries
    List.copyRange(newContent, 0, content, 0, dataEndIndex);
    // Copy nodes before the replaced node
    List.copyRange(
      newContent,
      dataEndIndex,
      content,
      dataEndIndex,
      contentNodeIndex,
    );
    // Insert the new data entry where the node was (conceptually)
    newContent[newContentDataIndex] = key;
    newContent[newContentDataIndex + 1] = value;
    // Copy nodes after the replaced node (adjusting destination index)
    List.copyRange(
      newContent,
      newContentDataIndex + 2,
      content,
      contentNodeIndex + 1,
      content.length,
    );

    return newContent;
  }

  // Helper to get the hash of a key (assuming non-null keys for now)
  // TODO: Handle null keys if necessary
  int hashOfKey(K key) => key.hashCode;
}

// --- Helper Functions for Node Creation ---

/// Merges two data entries into a new node (either Internal or Collision).
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
