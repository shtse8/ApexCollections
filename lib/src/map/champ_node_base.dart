/// Defines the abstract base class [ChampNode] for CHAMP Trie nodes and
/// related result type definitions.
library;

// Remove unused: import 'package:meta/meta.dart';
import 'champ_utils.dart'; // Import TransientOwner

// --- Node Base Class ---

/// Abstract base class for nodes in the Compressed Hash-Array Mapped Prefix Tree (CHAMP).
///
/// Nodes represent parts of the immutable map structure. They can be:
/// * `ChampEmptyNode`: Represents the canonical empty map.
/// * `ChampDataNode`: Represents a single key-value pair.
/// * `ChampCollisionNode`: Represents multiple entries with hash collisions at a certain depth.
/// * `ChampSparseNode` / `ChampArrayNode`: Represents a branch with multiple children (data or other nodes).
///
/// Nodes are immutable by default but support transient mutation via the
/// [TransientOwner] mechanism for performance optimization during bulk updates.
// @immutable // Temporarily removed due to transient nodes
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
  /// - `node`: The potentially new root node of the modified subtree (could be `ChampEmptyNode`).
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
  /// Subclasses should override this to handle their specific freezing logic
  /// (like freezing children or making lists unmodifiable) and then call super.freeze().
  ChampNode<K, V> freeze(TransientOwner? owner) {
    if (isTransient(owner)) {
      _owner = null; // Clear owner in the base class
    }
    return this; // Return self, subclasses handle immutability guarantees
  }

  // _clearOwner is no longer needed as freeze handles it.

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
