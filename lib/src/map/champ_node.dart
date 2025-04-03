/// Defines the core structures for CHAMP Trie nodes used by ApexMap/ApexSet.

const int _kHashBits = 32; // Standard Dart hash code size
const int _kBitPartitionSize = 5; // Hash bits used per level
const int _kBranchingFactor = 1 << _kBitPartitionSize; // 32

/// Base class for CHAMP Trie nodes.
abstract class ChampNode<K, V> {
  // Potentially add common methods or properties later if needed.
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

  // TODO: Implement methods for lookup, insertion, removal, iteration, equality etc.
  // These will involve bit manipulation on dataMap/nodeMap and indexing into content.
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

  // TODO: Implement methods for lookup, insertion, removal specific to collision nodes.
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
