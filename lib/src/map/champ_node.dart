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
