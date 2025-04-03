/// Defines the core structures for CHAMP Trie nodes used by ApexMap/ApexSet.

const int _kHashBits = 32; // Standard Dart hash code size
const int _kBitPartitionSize = 5; // Hash bits used per level
const int _kBranchingFactor = 1 << _kBitPartitionSize; // 32

/// Base class for CHAMP Trie nodes.
abstract class ChampNode<K, V> {
  /// Retrieves the value associated with [key] within this subtree,
  /// returning `null` if the key is not found.
  /// Requires the full [hash] of the key and the current [shift] level.
  V? get(K key, int hash, int shift);

  /// Returns a new node structure representing the trie after adding or
  /// updating the entry with [key], [value], and its [hash].
  /// [shift] indicates the current level in the trie.
  /// Returns `this` if the key/value pair was already present.
  ChampNode<K, V> add(K key, V value, int hash, int shift);
}

/// Represents a standard internal node in the CHAMP Trie.
/// Uses bitmaps to compactly store references to data entries and child nodes.
class ChampInternalNode<K, V> extends ChampNode<K, V> {
  /// Bitmap indicating which slots contain data payloads (key or key/value).
  final int dataMap;

  /// Bitmap indicating which slots contain child node pointers.
  final int nodeMap;

  /// Compact array storing data payloads and child nodes contiguously.
  /// Data payloads (key or key/value pairs) are stored from the beginning.
  /// Child nodes (ChampNode instances) are stored from the end.
  final List<Object?> content;

  ChampInternalNode(this.dataMap, this.nodeMap, this.content)
    : assert((dataMap & nodeMap) == 0); // Ensure no slot has both bits set

  int get dataArity => Integer.bitCount(dataMap);
  int get nodeArity => Integer.bitCount(nodeMap);
  int get arity => dataArity + nodeArity;

  bool get isEmpty => arity == 0;
  bool get isNotEmpty => arity > 0;

  @override
  V? get(K key, int hash, int shift) {
    final mask = 1 << ((hash >> shift) & (_kBranchingFactor - 1));

    if ((dataMap & mask) != 0) {
      // Potential data payload match
      final index = Integer.bitCount(dataMap & (mask - 1));
      // Assuming keys/values are stored alternatingly for maps
      final currentKey = content[index * 2] as K;
      if (key == currentKey) {
        return content[index * 2 + 1] as V;
      }
      return null; // Key mismatch
    }

    if ((nodeMap & mask) != 0) {
      // Potential match in sub-node
      final index = Integer.bitCount(nodeMap & (mask - 1));
      final nodeIndex = content.length - 1 - index; // Nodes stored from the end
      final childNode = content[nodeIndex] as ChampNode<K, V>;
      return childNode.get(key, hash, shift + _kBitPartitionSize);
    }

    // Key not found in this node
    return null;
  }

  @override
  ChampNode<K, V> add(K key, V value, int hash, int shift) {
    final mask = 1 << ((hash >> shift) & (_kBranchingFactor - 1));
    final bitpos = mask; // Use mask as bitpos for clarity

    if ((dataMap & bitpos) != 0) {
      // Slot contains a data payload
      final dataIndex = Integer.bitCount(dataMap & (bitpos - 1));
      final payloadIndex = dataIndex * 2;
      final currentKey = content[payloadIndex] as K;

      if (key == currentKey) {
        // Key match: Update value if different
        final currentValue = content[payloadIndex + 1] as V;
        if (identical(currentValue, value) || currentValue == value) {
          return this; // Value is the same, no change
        }
        // Create new node with updated value
        final newContent = List<Object?>.of(content);
        newContent[payloadIndex + 1] = value;
        return ChampInternalNode<K, V>(dataMap, nodeMap, newContent);
      } else {
        // Key mismatch: Collision or path expansion needed
        final currentVal = content[payloadIndex + 1] as V;
        final currentEntry = MapEntry(currentKey, currentVal);
        final newEntry = MapEntry(key, value);

        // Need hash of existing key to proceed
        final currentHash = currentKey.hashCode; // Assuming standard hashCode

        if (currentHash == hash) {
          // Full hash collision: Create CollisionNode
          final collisionNode = ChampCollisionNode<K, V>(hash, [
            currentEntry,
            newEntry,
          ]);
          final newContent = _replaceDataWithNode(dataIndex, collisionNode);
          return ChampInternalNode<K, V>(
            dataMap ^ bitpos,
            nodeMap | bitpos,
            newContent,
          );
        } else {
          // Hashes differ: Expand path
          final subNode = _createSubNode(
            currentEntry,
            currentHash,
            newEntry,
            hash,
            shift + _kBitPartitionSize,
          );
          final newContent = _replaceDataWithNode(dataIndex, subNode);
          return ChampInternalNode<K, V>(
            dataMap ^ bitpos,
            nodeMap | bitpos,
            newContent,
          );
        }
      }
    } else if ((nodeMap & bitpos) != 0) {
      // Slot contains a sub-node
      final nodeLocalIndex = Integer.bitCount(nodeMap & (bitpos - 1));
      final nodeIndex = content.length - 1 - nodeLocalIndex;
      final subNode = content[nodeIndex] as ChampNode<K, V>;
      final newSubNode = subNode.add(
        key,
        value,
        hash,
        shift + _kBitPartitionSize,
      );

      if (identical(subNode, newSubNode)) {
        return this; // Sub-node didn't change
      }
      // Create new node with updated sub-node
      final newContent = List<Object?>.of(content);
      newContent[nodeIndex] = newSubNode;
      return ChampInternalNode<K, V>(dataMap, nodeMap, newContent);
    } else {
      // Slot is empty: Insert new data payload
      final dataIndex = Integer.bitCount(dataMap & (bitpos - 1));
      final newContent = _insertData(dataIndex, key, value);
      return ChampInternalNode<K, V>(dataMap | bitpos, nodeMap, newContent);
    }
  }

  // --- Helper methods for node modification (Internal) ---

  /// Creates a new content array with data at [dataIndex] replaced by [newNode].
  List<Object?> _replaceDataWithNode(int dataIndex, ChampNode<K, V> newNode) {
    final dataPayloadIndex = dataIndex * 2;
    final nodeLocalIndex = Integer.bitCount(
      nodeMap & ((1 << dataIndex) - 1),
    ); // Approximation, needs refinement based on actual bitpos
    final newNodeIndex =
        (content.length - nodeArity) -
        1 -
        nodeLocalIndex; // Calculate insertion point for node

    final newContent = List<Object?>.filled(
      content.length - 2 + 1,
      null,
    ); // -2 for data, +1 for node

    // Copy data before the replaced slot
    List.copyRange(newContent, 0, content, 0, dataPayloadIndex);
    // Copy data after the replaced slot
    List.copyRange(
      newContent,
      dataPayloadIndex,
      content,
      dataPayloadIndex + 2,
      dataArity * 2,
    );
    // Copy nodes before the insertion point
    List.copyRange(
      newContent,
      dataArity * 2,
      content,
      dataArity * 2,
      newNodeIndex + dataArity * 2,
    ); // Adjust source index
    // Insert the new node
    newContent[newNodeIndex + dataArity * 2] = newNode;
    // Copy nodes after the insertion point
    List.copyRange(
      newContent,
      newNodeIndex + dataArity * 2 + 1,
      content,
      newNodeIndex + dataArity * 2 + 1,
      content.length,
    ); // Adjust indices

    // This helper needs careful index calculation based on actual bit positions
    // and the dual-growth strategy. Placeholder logic shown.
    throw UnimplementedError("_replaceDataWithNode needs correct index math");
  }

  /// Creates a new content array with [key]/[value] inserted at [dataIndex].
  List<Object?> _insertData(int dataIndex, K key, V value) {
    final dataPayloadIndex = dataIndex * 2;
    final newContent = List<Object?>.filled(content.length + 2, null);

    // Copy elements before insertion point
    List.copyRange(newContent, 0, content, 0, dataPayloadIndex);
    // Insert new key/value
    newContent[dataPayloadIndex] = key;
    newContent[dataPayloadIndex + 1] = value;
    // Copy elements after insertion point
    List.copyRange(
      newContent,
      dataPayloadIndex + 2,
      content,
      dataPayloadIndex,
      dataArity * 2,
    );
    // Copy all existing nodes
    List.copyRange(
      newContent,
      dataArity * 2 + 2,
      content,
      dataArity * 2,
      content.length,
    );

    // This helper needs careful index calculation based on actual bit positions
    // and the dual-growth strategy. Placeholder logic shown.
    throw UnimplementedError("_insertData needs correct index math");
  }

  /// Creates a sub-node when two entries collide at the current level.
  ChampNode<K, V> _createSubNode(
    MapEntry<K, V> entry1,
    int hash1,
    MapEntry<K, V> entry2,
    int hash2,
    int shift,
  ) {
    if (shift >= _kHashBits) {
      // Max depth reached, create collision node
      return ChampCollisionNode<K, V>(hash1, [entry1, entry2]);
    }

    final mask1 = 1 << ((hash1 >> shift) & (_kBranchingFactor - 1));
    final mask2 = 1 << ((hash2 >> shift) & (_kBranchingFactor - 1));

    if (mask1 == mask2) {
      // Still colliding at this level, recurse
      final subNode = _createSubNode(
        entry1,
        hash1,
        entry2,
        hash2,
        shift + _kBitPartitionSize,
      );
      return ChampInternalNode<K, V>(0, mask1, [
        subNode,
      ]); // Node map has the bit set
    } else {
      // Can differentiate at this level
      // Ensure order for consistent structure if needed (e.g., based on mask value)
      if (mask1 < mask2) {
        return ChampInternalNode<K, V>(mask1 | mask2, 0, [
          entry1.key,
          entry1.value,
          entry2.key,
          entry2.value,
        ]);
      } else {
        return ChampInternalNode<K, V>(mask1 | mask2, 0, [
          entry2.key,
          entry2.value,
          entry1.key,
          entry1.value,
        ]);
      }
    }
  }
}

/// Represents a node containing entries that have the same full hash code
/// or whose hash codes collide completely up to the maximum trie depth.
class ChampCollisionNode<K, V> extends ChampNode<K, V> {
  /// The hash code shared by all entries in this node.
  final int hash;

  /// List storing the actual key-value pairs that collided.
  /// For a Set, V would typically be a placeholder type or the key itself.
  final List<MapEntry<K, V>> entries;

  ChampCollisionNode(this.hash, this.entries)
    : assert(
        entries.length >= 2,
      ); // Must have at least 2 entries to be a collision

  int get arity => entries.length;

  @override
  V? get(K key, int hash, int shift) {
    // In a collision node, we ignore hash/shift and just check the list
    for (final entry in entries) {
      if (key == entry.key) {
        return entry.value;
      }
    }
    return null; // Key not found in collision list
  }

  @override
  ChampNode<K, V> add(K key, V value, int hash, int shift) {
    // Check if key already exists
    int existingIndex = -1;
    for (int i = 0; i < entries.length; i++) {
      if (key == entries[i].key) {
        existingIndex = i;
        break;
      }
    }

    if (existingIndex != -1) {
      // Key exists, update value if different
      final currentEntry = entries[existingIndex];
      if (identical(currentEntry.value, value) || currentEntry.value == value) {
        return this; // Value is the same
      }
      final newEntries = List<MapEntry<K, V>>.of(entries);
      newEntries[existingIndex] = MapEntry(key, value);
      return ChampCollisionNode<K, V>(hash, newEntries);
    } else {
      // Key doesn't exist, add new entry
      final newEntries = List<MapEntry<K, V>>.of(entries)
        ..add(MapEntry(key, value));
      // If only one entry remains after potential prior deletions,
      // it should ideally be inlined back into a parent node,
      // but that logic belongs in the InternalNode's deletion handling.
      // Here, we just return a new collision node with the added entry.
      return ChampCollisionNode<K, V>(hash, newEntries);
    }
  }
}

// Helper for bit counting (consider adding as extension or utility)
class Integer {
  static int bitCount(int n) {
    // Efficient bit count implementation (e.g., from Dart SDK internals or standard algorithms)
    n = n - ((n >> 1) & 0x55555555);
    n = (n & 0x33333333) + ((n >> 2) & 0x33333333);
    return (((n + (n >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
  }
}

// TODO: Define a shared empty node instance (likely an InternalNode with 0 maps/content).
// TODO: Implement factory constructors or static methods for creating nodes.
