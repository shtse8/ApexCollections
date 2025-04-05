/// Defines the abstract base class [ChampBitmapNode] for CHAMP nodes using bitmaps.
library;

import 'champ_node_base.dart';
import 'champ_utils.dart';
// Import concrete implementations for the factory constructor
import 'champ_sparse_node.dart';
import 'champ_array_node_base.dart'; // Import base for type
import 'champ_array_node_impl.dart'; // Import concrete implementation

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
    // Nodes are stored in REVERSE order at the end.
    final List<Object?> children;
    if (frag1 < frag2) {
      // frag1 corresponds to index 1 (from end), frag2 to index 0 (from end)
      children = [node2, node1];
    } else {
      // frag2 corresponds to index 1 (from end), frag1 to index 0 (from end)
      children = [node1, node2];
    }

    // Decide whether to create Sparse or Array node based on initial count (which is 2)
    // Always start with SparseNode if threshold allows
    if (kSparseNodeThreshold >= 2) {
      return ChampSparseNode<K, V>(dataMap, newNodeMap, children, owner);
    } else {
      // If threshold is very low (e.g., 0 or 1), start with ArrayNode
      return ChampArrayNodeImpl<K, V>(dataMap, newNodeMap, children, owner);
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
