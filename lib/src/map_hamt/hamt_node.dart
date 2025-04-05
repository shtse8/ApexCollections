import 'package:meta/meta.dart';
import 'package:collection/collection.dart'; // For SetEquality, DeepCollectionEquality

// Helper function for bitCount as a workaround for potential analyzer issues
int _bitCount(int n) {
  int count = 0;
  while (n > 0) {
    n &= (n - 1); // Clear the least significant bit set
    count++;
  }
  return count;
}

// Placeholder for Transient Ownership if needed later
class TransientOwner {
  bool _isOwned = true;
  bool get isOwned => _isOwned;

  void disown() {
    _isOwned = false;
  }
}

/// Base class for all HAMT node types.
@immutable
abstract class HamtNode<K, V> {
  const HamtNode();

  // TODO: Define core node operations (get, add, remove, update)
  // These will likely return modification results (e.g., NodeModified, ValueSet, etc.)

  // TODO: Define properties needed for iteration (e.g., size, children, data)

  /// Placeholder for checking if the node is empty.
  bool get isEmpty => true; // Default for base, override in concrete classes

  /// Placeholder for node size (number of key-value pairs).
  int get size => 0; // Default for base, override in concrete classes

  /// Placeholder for getting a value by key and hash.
  V? get(K key, int hash, int shift);

  /// Placeholder for adding or updating a key-value pair.
  HamtNode<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  );

  /// Placeholder for removing a key.
  HamtNode<K, V> remove(K key, int hash, int shift, TransientOwner? owner);

  /// Checks if a key exists within this node or its children.
  bool containsKey(K key, int hash, int shift);

  // TODO: Add equality and hashCode implementations
}

/// Represents an empty HAMT node (singleton).
class HamtEmptyNode<K, V> extends HamtNode<K, V> {
  const HamtEmptyNode();

  static final HamtEmptyNode _instance = const HamtEmptyNode();
  static HamtEmptyNode<K, V> instance<K, V>() =>
      _instance as HamtEmptyNode<K, V>;

  @override
  bool get isEmpty => true;

  @override
  int get size => 0;

  @override
  V? get(K key, int hash, int shift) => null;

  @override
  HamtNode<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    // Return a HamtDataNode when adding to empty
    // TODO: Handle transient owner?
    return HamtDataNode(hash, key, value);
  }

  @override
  HamtNode<K, V> remove(K key, int hash, int shift, TransientOwner? owner) {
    return this; // Removing from empty does nothing
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    return false; // Key cannot exist in an empty node
  }

  @override
  int get hashCode => 0;

  @override
  bool operator ==(Object other) => other is HamtEmptyNode;
}

/// Represents a node containing a single key-value pair.
@immutable
class HamtDataNode<K, V> extends HamtNode<K, V> {
  final int dataHash; // Store the full hash for potential collision checks
  final K dataKey;
  final V dataValue;

  const HamtDataNode(this.dataHash, this.dataKey, this.dataValue);

  @override
  bool get isEmpty => false;

  @override
  int get size => 1;

  @override
  V? get(K key, int hash, int shift) {
    // No need to check hash here, only key equality matters
    return (key == dataKey) ? dataValue : null;
  }

  @override
  HamtNode<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    if (key == dataKey) {
      // Update existing key
      if (value == dataValue) {
        return this; // Value is the same, return same instance
      }
      // TODO: Handle transient owner for update?
      return HamtDataNode(hash, key, value);
    }

    // Collision or expansion needed
    // Use the hash fragment at the current level for comparison
    final currentFrag = HamtBitmapNode.indexFragment(
      dataHash,
      shift,
    ); // Use static helper
    final newFrag = HamtBitmapNode.indexFragment(
      hash,
      shift,
    ); // Use static helper

    if (currentFrag == newFrag) {
      // Hash collision at this level's fragment
      // TODO: Handle transient owner?
      return HamtCollisionNode(currentFrag, [
        this,
        HamtDataNode(hash, key, value),
      ]);
    } else {
      // Create a new SparseNode containing both the original data and the new data
      // Corrected call to static empty method
      return HamtSparseNode.empty<K, V>()
          .add(dataKey, dataValue, dataHash, shift, owner) // Add original data
          .add(key, value, hash, shift, owner); // Add new data
    }
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    // Only need to check key equality
    return key == dataKey;
  }

  @override
  HamtNode<K, V> remove(K key, int hash, int shift, TransientOwner? owner) {
    if (key == dataKey) {
      return HamtEmptyNode.instance<K, V>();
    }
    return this; // Key not found
  }

  @override
  int get hashCode => dataHash ^ dataKey.hashCode ^ dataValue.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HamtDataNode &&
          runtimeType == other.runtimeType &&
          // dataHash == other.dataHash && // Hash equality isn't strictly needed if keys match
          dataKey == other.dataKey &&
          dataValue == other.dataValue;
}

/// Represents a node containing multiple entries with the same hash code fragment
/// (but potentially different full hash codes or keys).
@immutable
class HamtCollisionNode<K, V> extends HamtNode<K, V> {
  final int collisionFrag; // The hash fragment where the collision occurred
  // Store as a list of DataNodes for simplicity, could optimize later
  // Ensure children always have > 1 element
  final List<HamtDataNode<K, V>> children;

  const HamtCollisionNode(this.collisionFrag, this.children)
    : assert(children.length > 1);

  @override
  bool get isEmpty => false;

  @override
  int get size => children.length;

  @override
  V? get(K key, int hash, int shift) {
    // We only need to check the key here, hash collision already happened
    for (final child in children) {
      if (child.dataKey == key) {
        return child.dataValue;
      }
    }
    return null;
  }

  @override
  HamtNode<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    final newFrag = HamtBitmapNode.indexFragment(
      hash,
      shift,
    ); // Use static helper

    if (newFrag != collisionFrag) {
      // The new key's hash fragment differs, so we need to expand.
      // Create a new Bitmap node containing the current collision node
      // and the new data node, placed according to their respective hash fragments.
      // TODO: Handle transient owner?
      final newDataNode = HamtDataNode(hash, key, value);
      // Create a new SparseNode containing the current collision node and the new data node
      // Assuming addNode exists and works correctly on HamtSparseNode
      HamtBitmapNode<K, V> newNode = HamtSparseNode.empty<K, V>();
      newNode =
          newNode.addNode(collisionFrag, this, shift, owner)
              as HamtBitmapNode<K, V>;
      newNode =
          newNode.addNode(newFrag, newDataNode, shift, owner)
              as HamtBitmapNode<K, V>;
      return newNode;
    }

    // Hash fragment matches, add/update within the collision list
    int foundIndex = -1;
    for (int i = 0; i < children.length; i++) {
      if (children[i].dataKey == key) {
        foundIndex = i;
        break;
      }
    }

    // TODO: Handle transient owner?
    final newChildren = List<HamtDataNode<K, V>>.from(children);
    final newDataNode = HamtDataNode(
      hash,
      key,
      value,
    ); // Use full hash for data node

    if (foundIndex != -1) {
      // Key found, update
      if (newChildren[foundIndex].dataValue == value) {
        return this; // Value is the same, no change needed
      }
      newChildren[foundIndex] = newDataNode; // Update existing entry
    } else {
      // Key not found, add new entry
      newChildren.add(newDataNode);
    }
    return HamtCollisionNode(collisionFrag, newChildren);
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    // Only need to check key equality within the list
    for (final child in children) {
      if (child.dataKey == key) {
        return true;
      }
    }
    return false;
  }

  @override
  HamtNode<K, V> remove(K key, int hash, int shift, TransientOwner? owner) {
    // We only need to check the key here
    int foundIndex = -1;
    for (int i = 0; i < children.length; i++) {
      if (children[i].dataKey == key) {
        foundIndex = i;
        break;
      }
    }

    if (foundIndex == -1) {
      return this; // Key not found in this collision node
    }

    // TODO: Handle transient owner?
    if (children.length == 2) {
      // Removing one leaves only one, collapse back to a DataNode
      final remainingChild = children[1 - foundIndex];
      return remainingChild;
    } else {
      // Remove from list and create a new CollisionNode
      final newChildren = List<HamtDataNode<K, V>>.from(children);
      newChildren.removeAt(foundIndex);
      return HamtCollisionNode(collisionFrag, newChildren);
    }
  }

  @override
  int get hashCode =>
      collisionFrag ^ const DeepCollectionEquality.unordered().hash(children);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HamtCollisionNode &&
          runtimeType == other.runtimeType &&
          collisionFrag == other.collisionFrag &&
          const DeepCollectionEquality.unordered().equals(
            children,
            other.children,
          );
}

/// Abstract base class for HAMT nodes that use a bitmap to track children/data.
@immutable
abstract class HamtBitmapNode<K, V> extends HamtNode<K, V> {
  final int bitmap;
  // Content can store HamtNode<K,V> or potentially [K, V] pairs directly
  // depending on the chosen HAMT strategy.
  // For simplicity, let's start with storing only HamtNode<K,V>.
  final List<HamtNode<K, V>> content;

  const HamtBitmapNode(this.bitmap, this.content);

  @override
  bool get isEmpty => false; // Bitmap nodes are never logically empty

  /// Calculates the sparse index in the content array for a given bit position.
  int sparseIndex(int bitpos) {
    // Count the number of set bits *before* the target bitpos in the bitmap
    // Use helper function as workaround for potential analyzer issue with int.bitCount
    return _bitCount(bitmap & (bitpos - 1));
  }

  /// Calculates the index fragment (e.g., 5 bits) for a given hash and shift level.
  static int indexFragment(int hash, int shift) {
    return (hash >> shift) & 0x1f; // 0x1f = 31 = 0b11111
  }

  /// Creates a bitmask for a given index fragment.
  static int bitpos(int indexFragment) {
    return 1 << indexFragment;
  }

  // Helper to add a node (DataNode or CollisionNode) to a BitmapNode.
  // This is used when expanding from Data/Collision or adding to existing Bitmap.
  // Returns HamtNode because it might stay Sparse or transition to Array.
  HamtNode<K, V> addNode(
    int frag,
    HamtNode<K, V> nodeToAdd,
    int shift,
    TransientOwner? owner,
  );

  // Concrete implementations (Sparse/Array) will override get, add, remove.
}

/// Represents a HAMT node using a bitmap and a sparse array for children.
@immutable
class HamtSparseNode<K, V> extends HamtBitmapNode<K, V> {
  const HamtSparseNode(super.bitmap, super.content);

  // Corrected static empty method
  static HamtSparseNode<K, V> empty<K, V>() => const HamtSparseNode(0, []);

  @override
  int get size {
    // Sum the sizes of all children
    int totalSize = 0;
    for (final node in content) {
      totalSize += node.size;
    }
    return totalSize;
  }

  @override
  V? get(K key, int hash, int shift) {
    final frag = HamtBitmapNode.indexFragment(hash, shift);
    final pos = HamtBitmapNode.bitpos(frag);

    if ((bitmap & pos) == 0) {
      return null; // No entry for this fragment
    }

    final idx = sparseIndex(pos);
    // Basic bounds check (should ideally not happen with correct logic)
    if (idx >= content.length) {
      print(
        "Error: SparseNode.get index out of bounds. Bitmap: ${bitmap.toRadixString(2)}, Pos: ${pos.toRadixString(2)}, Idx: $idx, ContentLen: ${content.length}",
      );
      return null;
    }
    final child = content[idx];
    return child.get(key, hash, shift + 5); // Recurse to next level
  }

  @override
  HamtNode<K, V> add(
    K key,
    V value,
    int hash,
    int shift,
    TransientOwner? owner,
  ) {
    final frag = HamtBitmapNode.indexFragment(hash, shift);
    final pos = HamtBitmapNode.bitpos(frag);
    final idx = sparseIndex(pos);

    if ((bitmap & pos) == 0) {
      // Insert new entry (DataNode) into this node
      final newDataNode = HamtDataNode(hash, key, value);
      // TODO: Handle transient owner?
      final newContent = List<HamtNode<K, V>>.from(content);
      newContent.insert(idx, newDataNode);
      final newBitmap = bitmap | pos;
      // TODO: Check if node needs to transition to ArrayNode (if density high)?
      return HamtSparseNode(newBitmap, newContent);
    } else {
      // Collision or update within existing child
      // Basic bounds check
      if (idx >= content.length) {
        print(
          "Error: SparseNode.add index out of bounds. Bitmap: ${bitmap.toRadixString(2)}, Pos: ${pos.toRadixString(2)}, Idx: $idx, ContentLen: ${content.length}",
        );
        // Fallback: Recreate node with just the new item? Or throw?
        // This indicates a logic error elsewhere. For now, let's try adding as if empty.
        final newDataNode = HamtDataNode(hash, key, value);
        return HamtSparseNode(pos, [newDataNode]);
      }
      final child = content[idx];
      final newChild = child.add(key, value, hash, shift + 5, owner);

      if (identical(child, newChild)) {
        return this; // Child did not change
      }

      // TODO: Handle transient owner?
      final newContent = List<HamtNode<K, V>>.from(content);
      newContent[idx] = newChild;
      // Return HamtSparseNode for now, assuming no transition
      return HamtSparseNode(bitmap, newContent);
    }
  }

  @override
  HamtNode<K, V> addNode(
    int frag,
    HamtNode<K, V> nodeToAdd,
    int shift,
    TransientOwner? owner,
  ) {
    final pos = HamtBitmapNode.bitpos(frag);
    final idx = sparseIndex(pos);

    // TODO: Handle transient owner?
    final newContent = List<HamtNode<K, V>>.from(content);
    newContent.insert(idx, nodeToAdd);
    final newBitmap = bitmap | pos;
    // TODO: Check if node needs to transition to ArrayNode (if density high)?
    // Return HamtSparseNode for now
    return HamtSparseNode(newBitmap, newContent);
  }

  @override
  bool containsKey(K key, int hash, int shift) {
    final frag = HamtBitmapNode.indexFragment(hash, shift);
    final pos = HamtBitmapNode.bitpos(frag);

    if ((bitmap & pos) == 0) {
      return false; // No entry for this fragment
    }

    final idx = sparseIndex(pos);
    // Basic bounds check
    if (idx >= content.length) {
      print(
        "Error: SparseNode.containsKey index out of bounds. Bitmap: ${bitmap.toRadixString(2)}, Pos: ${pos.toRadixString(2)}, Idx: $idx, ContentLen: ${content.length}",
      );
      return false;
    }
    final child = content[idx];
    return child.containsKey(key, hash, shift + 5); // Recurse
  }

  @override
  HamtNode<K, V> remove(K key, int hash, int shift, TransientOwner? owner) {
    final frag = HamtBitmapNode.indexFragment(hash, shift);
    final pos = HamtBitmapNode.bitpos(frag);

    if ((bitmap & pos) == 0) {
      return this; // Key not found here
    }

    final idx = sparseIndex(pos);
    // Basic bounds check
    if (idx >= content.length) {
      print(
        "Error: SparseNode.remove index out of bounds. Bitmap: ${bitmap.toRadixString(2)}, Pos: ${pos.toRadixString(2)}, Idx: $idx, ContentLen: ${content.length}",
      );
      return this; // Cannot remove if index is wrong
    }
    final child = content[idx];
    final newChild = child.remove(key, hash, shift + 5, owner);

    if (identical(child, newChild)) {
      return this; // Child did not change
    }

    // TODO: Handle transient owner?
    if (newChild.isEmpty) {
      // Child became empty, remove it from this node
      final newBitmap = bitmap & ~pos;
      if (newBitmap == 0) {
        // This node becomes empty
        return HamtEmptyNode.instance<K, V>();
      }

      final newContent = List<HamtNode<K, V>>.from(content);
      newContent.removeAt(idx);

      // Collapse check: If only one child remains and it's a DataNode or CollisionNode
      // (i.e., not another BitmapNode needing the current level's bitmap info),
      // return the child directly to avoid unnecessary intermediate nodes.
      if (newContent.length == 1) {
        final singleChild = newContent[0];
        if (singleChild is HamtDataNode<K, V> ||
            singleChild is HamtCollisionNode<K, V>) {
          // Check if the child's hash fragment matches the current node's expected fragment
          // This check might be complex or unnecessary depending on how strict we are.
          // For now, let's assume collapsing is safe if it's not a BitmapNode.
          return singleChild;
        }
        // If the single child is another BitmapNode, we still need this SparseNode level.
      }

      // TODO: Check if node needs to transition from ArrayNode back to SparseNode?
      // Return HamtSparseNode for now
      return HamtSparseNode(newBitmap, newContent);
    } else {
      // Child was modified but not empty
      final newContent = List<HamtNode<K, V>>.from(content);
      newContent[idx] = newChild;
      // Return HamtSparseNode for now
      return HamtSparseNode(bitmap, newContent);
    }
  }

  @override
  int get hashCode => bitmap ^ const DeepCollectionEquality().hash(content);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HamtSparseNode && // Use parentheses for clarity
          runtimeType == other.runtimeType &&
          bitmap == other.bitmap &&
          const DeepCollectionEquality().equals(content, other.content));
}

// TODO: Define HamtArrayNode<K, V> (less common, uses full array)
