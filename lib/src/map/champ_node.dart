/// Defines the core structures for CHAMP Trie nodes used by ApexMap/ApexSet.
library;

const int _kHashBits = 32; // Standard Dart hash code size
const int _kBitPartitionSize = 5; // Hash bits used per level
const int _kBranchingFactor = 1 << _kBitPartitionSize; // 32
const List<Object?> _emptyContent = []; // Canonical empty content list

/// Base class for CHAMP Trie nodes.
abstract class ChampNode<K, V> {
  /// Const constructor for subclasses.
  const ChampNode();

  /// Retrieves the value associated with [key] within this subtree,
  /// returning `null` if the key is not found.
  /// Requires the full [hash] of the key and the current [shift] level.
  V? get(K key, int hash, int shift);

  /// Returns a new node structure representing the trie after adding or
  /// updating the entry with [key], [value], and its [hash].
  /// [shift] indicates the current level in the trie.
  /// Returns `this` if the key/value pair was already present.
  ChampNode<K, V> add(K key, V value, int hash, int shift);

  /// Returns `true` if this node (and its subtree) contains no entries.
  bool get isEmpty;

  /// Returns `true` if this node (and its subtree) contains entries.
  bool get isNotEmpty => !isEmpty;

  /// Returns a new node structure representing the trie after removing the
  /// entry associated with [key] and its [hash].
  /// [shift] indicates the current level in the trie.
  /// Returns `this` if the key was not found.
  /// Needs a mechanism (e.g., a result object or mutable flag) to signal
  /// if a removal actually occurred for canonicalization.
  ChampNode<K, V> remove(K key, int hash, int shift /*, MutableFlag removed*/);

  /// Returns the total number of entries in the subtree rooted at this node.
  /// Note: This might be expensive for internal nodes if not cached.
  int get arity;

  /// Returns true if this node represents the canonical empty node.
  bool get isEmptyNode => false;
}

/// Represents a standard internal node in the CHAMP Trie.
/// Uses bitmaps to compactly store references to data entries and child nodes.
class ChampInternalNode<K, V> extends ChampNode<K, V> {
  /// Bitmap indicating which slots contain data payloads (key or key/value).
  final int dataMap;

  /// Bitmap indicating which slots contain child node pointers.
  final int nodeMap;

  /// Compact array storing data payloads and child nodes contiguously.
  /// Data payloads (key/value pairs) are stored from the beginning (alternating).
  /// Child nodes (ChampNode instances) are stored from the end.
  final List<Object?> content;

  ChampInternalNode(this.dataMap, this.nodeMap, this.content)
    : assert((dataMap & nodeMap) == 0); // Ensure no slot has both bits set

  int get dataArity => Integer.bitCount(dataMap);
  int get nodeArity => Integer.bitCount(nodeMap);

  @override
  int get arity => dataArity + nodeArity;

  @override
  bool get isEmpty => arity == 0;

  // --- Helper methods for node modification (Internal - Defined Before Use) ---

  /// Creates a new content array with data payload at logical [dataIndex]
  /// replaced by [newNode].
  List<Object?> _replaceDataWithNode(int dataIndex, ChampNode<K, V> newNode) {
    final oldDataLen = dataArity * 2;
    final oldNodeLen = nodeArity;
    final newDataLen = oldDataLen - 2; // Removing key/value
    final newNodeLen = oldNodeLen + 1; // Adding node pointer
    final newContent = List<Object?>.filled(newDataLen + newNodeLen, null);

    // Calculate the actual array index for the data to remove
    final payloadIndexToRemove = dataIndex * 2;
    // Calculate the logical node index where the new node should be inserted
    // This depends on the bit position corresponding to the removed data.
    // Assume we can calculate `nodeIndexToInsert`.
    // int nodeIndexToInsert = _calculateNodeIndexForData(dataIndex); // Fictional helper
    int nodeIndexToInsert = 0; // Placeholder - MUST BE CALCULATED CORRECTLY
    final nodeArrayIndexToInsert = newDataLen + nodeIndexToInsert;

    // 1. Copy data elements before the removal index
    List.copyRange(newContent, 0, content, 0, payloadIndexToRemove);

    // 2. Copy data elements after the removal index (shifting left by 2)
    List.copyRange(
      newContent,
      payloadIndexToRemove,
      content,
      payloadIndexToRemove + 2,
      oldDataLen,
    );

    // 3. Copy node elements before the insertion index
    List.copyRange(
      newContent,
      newDataLen,
      content,
      oldDataLen,
      oldDataLen + nodeIndexToInsert,
    );

    // 4. Insert the new node pointer
    newContent[nodeArrayIndexToInsert] = newNode;

    // 5. Copy node elements after the insertion index (shifting right by 1)
    List.copyRange(
      newContent,
      nodeArrayIndexToInsert + 1,
      content,
      oldDataLen + nodeIndexToInsert,
      oldDataLen + oldNodeLen,
    );

    // WARNING: This implementation is complex and likely incorrect without
    // the proper calculation of `nodeIndexToInsert` based on the original bitpos.
    throw UnimplementedError(
      "_replaceDataWithNode needs correct index math and bitpos context",
    );
    // return newContent;
  }

  /// Creates a new content array with [key]/[value] inserted at the logical [dataIndex].
  List<Object?> _insertData(int dataIndex, K key, V value) {
    final oldDataLen = dataArity * 2;
    final oldNodeLen = nodeArity;
    final newDataLen = oldDataLen + 2;
    final newContent = List<Object?>.filled(newDataLen + oldNodeLen, null);

    // 1. Copy data elements before the insertion index
    final payloadIndex = dataIndex * 2;
    List.copyRange(newContent, 0, content, 0, payloadIndex);

    // 2. Insert the new key-value pair
    newContent[payloadIndex] = key;
    newContent[payloadIndex + 1] = value;

    // 3. Copy data elements after the insertion index
    List.copyRange(
      newContent,
      payloadIndex + 2,
      content,
      payloadIndex,
      oldDataLen,
    );

    // 4. Copy all node elements (shifting them by 2 positions)
    List.copyRange(
      newContent,
      newDataLen,
      content,
      oldDataLen,
      oldDataLen + oldNodeLen,
    );

    return newContent;
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
      // Node map has the bit set, data map is 0
      return ChampInternalNode<K, V>(0, mask1, [subNode]);
    } else {
      // Can differentiate at this level
      // Data map has both bits set, node map is 0
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

  List<Object?> _removeData(int dataIndex) {
    final oldDataLen = dataArity * 2;
    final oldNodeLen = nodeArity;
    final newDataLen = oldDataLen - 2;
    final newContent = List<Object?>.filled(newDataLen + oldNodeLen, null);

    // 1. Copy data elements before the removal index
    final payloadIndex = dataIndex * 2;
    List.copyRange(newContent, 0, content, 0, payloadIndex);

    // 2. Copy data elements after the removal index (shifting left by 2)
    List.copyRange(
      newContent,
      payloadIndex,
      content,
      payloadIndex + 2,
      oldDataLen,
    );

    // 3. Copy all node elements (shifting left by 2)
    List.copyRange(
      newContent,
      newDataLen,
      content,
      oldDataLen,
      oldDataLen + oldNodeLen,
    );

    return newContent;
  }

  List<Object?> _removeNode(int nodeLocalIndex) {
    final oldDataLen = dataArity * 2;
    final oldNodeLen = nodeArity;
    final newNodeLen = oldNodeLen - 1;
    final newContent = List<Object?>.filled(oldDataLen + newNodeLen, null);

    // Calculate the actual array index for the node to remove (from the end)
    // nodeLocalIndex is the index within the conceptual node array (0 to nodeArity-1)
    // The actual index in the content array is calculated from the end.
    final nodeIndexToRemove =
        oldDataLen + nodeLocalIndex; // Index relative to start of node section
    // which is at oldDataLen

    // 1. Copy all data elements
    List.copyRange(newContent, 0, content, 0, oldDataLen);

    // 2. Copy node elements before the removal index
    List.copyRange(
      newContent,
      oldDataLen,
      content,
      oldDataLen,
      nodeIndexToRemove,
    );

    // 3. Copy node elements after the removal index (shifting left by 1)
    List.copyRange(
      newContent,
      nodeIndexToRemove,
      content,
      nodeIndexToRemove + 1,
      oldDataLen + oldNodeLen,
    );

    return newContent;
  }

  List<Object?> _replaceNodeWithData(int nodeLocalIndex, K key, V value) {
    final oldDataLen = dataArity * 2;
    final oldNodeLen = nodeArity;
    final newDataLen = oldDataLen + 2; // Adding key/value
    final newNodeLen = oldNodeLen - 1; // Removing node pointer
    final newContent = List<Object?>.filled(newDataLen + newNodeLen, null);

    // Calculate the actual array index for the node to remove
    final nodeIndexToRemove = oldDataLen + nodeLocalIndex;

    // Calculate the logical data index where the new key/value should be inserted
    // This depends on the bit position corresponding to the removed node.
    // We need the original bitpos that led to this nodeLocalIndex.
    // This requires more context than available in this helper alone.
    // For now, assume we can calculate `dataIndexToInsert`.
    // int dataIndexToInsert = _calculateDataIndexForNode(nodeLocalIndex); // Fictional helper
    int dataIndexToInsert = 0; // Placeholder - MUST BE CALCULATED CORRECTLY
    final payloadIndexToInsert = dataIndexToInsert * 2;

    // 1. Copy data elements before the insertion point
    List.copyRange(newContent, 0, content, 0, payloadIndexToInsert);

    // 2. Insert the new key-value pair
    newContent[payloadIndexToInsert] = key;
    newContent[payloadIndexToInsert + 1] = value;

    // 3. Copy data elements after the insertion point
    List.copyRange(
      newContent,
      payloadIndexToInsert + 2,
      content,
      payloadIndexToInsert,
      oldDataLen,
    );

    // 4. Copy node elements before the removal index
    List.copyRange(
      newContent,
      newDataLen,
      content,
      oldDataLen,
      nodeIndexToRemove,
    );

    // 5. Copy node elements after the removal index (shifting left by 1)
    List.copyRange(
      newContent,
      newDataLen + nodeLocalIndex,
      content,
      nodeIndexToRemove + 1,
      oldDataLen + oldNodeLen,
    );

    // WARNING: This implementation is complex and likely incorrect without
    // the proper calculation of `dataIndexToInsert` based on the original bitpos.
    throw UnimplementedError(
      "_replaceNodeWithData needs correct index math and bitpos context",
    );
    // return newContent;
  }

  // --- Public API Methods ---

  @override
  V? get(K key, int hash, int shift) {
    final mask = 1 << ((hash >> shift) & (_kBranchingFactor - 1));

    if ((dataMap & mask) != 0) {
      // Potential data payload match
      final index = Integer.bitCount(dataMap & (mask - 1));
      // Assuming keys/values are stored alternatingly for maps
      final payloadIndex = index * 2;
      if (payloadIndex >= content.length) return null; // Bounds check
      final currentKey = content[payloadIndex] as K;
      if (key == currentKey) {
        return content[payloadIndex + 1] as V;
      }
      return null; // Key mismatch
    }

    if ((nodeMap & mask) != 0) {
      // Potential match in sub-node
      final index = Integer.bitCount(nodeMap & (mask - 1));
      final nodeIndex = content.length - 1 - index; // Nodes stored from the end
      if (nodeIndex < 0 || nodeIndex >= content.length) {
        return null; // Bounds check
      }
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

  @override
  ChampNode<K, V> remove(K key, int hash, int shift /*, MutableFlag removed*/) {
    final mask = 1 << ((hash >> shift) & (_kBranchingFactor - 1));
    final bitpos = mask;

    if ((dataMap & bitpos) != 0) {
      // Potential data payload match
      final dataIndex = Integer.bitCount(dataMap & (bitpos - 1));
      final payloadIndex = dataIndex * 2;
      final currentKey = content[payloadIndex] as K;

      if (key == currentKey) {
        // Key match: Remove this entry
        // removed?.flag = true; // Signal removal occurred
        final newDataMap = dataMap ^ bitpos;
        if (arity == 1) {
          // This was the only entry in the node
          return ChampInternalNode(
            0,
            0,
            _emptyContent,
          ); // Return canonical empty node
        }
        final newContent = _removeData(dataIndex);
        return ChampInternalNode<K, V>(newDataMap, nodeMap, newContent);
      }
      return this; // Key mismatch, not found here
    }

    if ((nodeMap & bitpos) != 0) {
      // Potential match in sub-node
      final nodeLocalIndex = Integer.bitCount(nodeMap & (bitpos - 1));
      final nodeIndex = content.length - 1 - nodeLocalIndex;
      final childNode = content[nodeIndex] as ChampNode<K, V>;
      final newChildNode = childNode.remove(
        key,
        hash,
        shift + _kBitPartitionSize /*, removed*/,
      );

      // if (removed?.flag != true) { // Check if removal happened below
      //   return this;
      // }
      if (identical(childNode, newChildNode)) {
        return this; // No change below
      }

      // Canonicalization check after potential removal below
      if (newChildNode is ChampInternalNode<K, V> &&
          newChildNode.arity == 1 &&
          newChildNode.nodeArity == 0) {
        // Child collapsed to a single data entry, inline it
        final singleKey = newChildNode.content[0] as K;
        final singleValue = newChildNode.content[1] as V;
        final newContent = _replaceNodeWithData(
          nodeLocalIndex,
          singleKey,
          singleValue,
        );
        return ChampInternalNode<K, V>(
          dataMap | bitpos,
          nodeMap ^ bitpos,
          newContent,
        );
      } else if (newChildNode.isEmpty) {
        // Check isEmpty on the returned node
        // Child became empty, remove the node pointer
        final newNodeMap = nodeMap ^ bitpos;
        if (arity == 1) {
          // This node becomes empty
          return ChampInternalNode(
            0,
            0,
            _emptyContent,
          ); // Return canonical empty node
        }
        final newContent = _removeNode(nodeLocalIndex);
        return ChampInternalNode<K, V>(dataMap, newNodeMap, newContent);
      } else {
        // Child changed but didn't collapse/empty, just update pointer
        final newContent = List<Object?>.of(content);
        newContent[nodeIndex] = newChildNode;
        return ChampInternalNode<K, V>(dataMap, nodeMap, newContent);
      }
    }

    // Key not found in this node or any sub-node
    return this;
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

  @override
  int get arity => entries.length;

  @override
  bool get isEmpty => entries.isEmpty; // Collision node is empty if list is empty

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

  @override
  ChampNode<K, V> remove(K key, int hash, int shift /*, MutableFlag removed*/) {
    int removalIndex = -1;
    for (int i = 0; i < entries.length; i++) {
      if (key == entries[i].key) {
        removalIndex = i;
        break;
      }
    }

    if (removalIndex == -1) {
      return this; // Key not found
    }

    // removed?.flag = true; // Signal removal occurred

    if (entries.length == 2) {
      // Removing one entry leaves only one - should be inlined by the caller (InternalNode)
      final remainingEntry = entries[1 - removalIndex]; // Get the other entry
      // Create a new InternalNode containing only this single entry.
      // The parent InternalNode's remove logic will handle inlining this.
      final remainingHash =
          remainingEntry.key.hashCode; // Assuming standard hashCode
      // We need the hash fragment relative to the *parent's* level (shift - partitionSize)
      // to correctly place it in the new InternalNode's bitmap.
      final parentShift = shift - _kBitPartitionSize;
      // Ensure shift doesn't go negative (shouldn't happen if called correctly)
      final effectiveShift = parentShift < 0 ? 0 : parentShift;
      final bitpos =
          1 << ((remainingHash >> effectiveShift) & (_kBranchingFactor - 1));

      // Data map has the bit set, node map is 0
      return ChampInternalNode<K, V>(bitpos, 0, [
        remainingEntry.key,
        remainingEntry.value,
      ]);
    } else {
      // More than 2 entries, just remove from list
      final newEntries = List<MapEntry<K, V>>.of(entries)
        ..removeAt(removalIndex);
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
/// Represents the canonical empty CHAMP Trie node.
class ChampEmptyNode<K, V> extends ChampNode<K, V> {
  static final ChampEmptyNode _instance = ChampEmptyNode._();

  /// Singleton instance of the empty node.
  static ChampEmptyNode<K, V> instance<K, V>() =>
      _instance as ChampEmptyNode<K, V>;

  const ChampEmptyNode._();

  @override
  int get arity => 0;

  @override
  bool get isEmpty => true;

  @override
  bool get isEmptyNode => true;

  @override
  V? get(K key, int hash, int shift) => null;

  @override
  ChampNode<K, V> add(K key, V value, int hash, int shift) {
    // Adding to empty creates a new InternalNode with a single data entry.
    final bitpos = 1 << ((hash >> shift) & (_kBranchingFactor - 1));
    return ChampInternalNode<K, V>(bitpos, 0, [key, value]);
  }

  @override
  ChampNode<K, V> remove(K key, int hash, int shift /*, MutableFlag removed*/) {
    // Removing from empty returns empty.
    return this;
  }
}

// TODO: Implement factory constructors or static methods for creating nodes.
// TODO: Implement the helper methods (_replaceDataWithNode, _insertData, _removeData, _removeNode)
