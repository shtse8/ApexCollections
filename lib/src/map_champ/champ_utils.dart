/// Contains constants, top-level helper functions for index calculation,
/// and the TransientOwner class used across CHAMP Trie node implementations.
library;

// --- Constants ---

/// The number of bits used for each level (hash fragment) of the CHAMP trie.
/// A value of 5 means each node can have up to 2^5 = 32 children/data entries.
const int kBitPartitionSize = 5;

/// Bitmask used to extract the hash fragment for the current level.
/// Calculated as `(1 << kBitPartitionSize) - 1`.
const int kBitPartitionMask = (1 << kBitPartitionSize) - 1;

/// The maximum depth of the CHAMP trie, determined by the hash code size (32 bits)
/// and the partition size. `ceil(32 / 5) = 7`.
const int kMaxDepth = 7; // ceil(32 / 5) - Max depth based on 32-bit hash

/// Threshold for switching between Sparse and Array nodes.
const int kSparseNodeThreshold = 8;

// --- Top-Level Helper Functions for Index Calculation ---

/// Counts the number of set bits (1s) in an integer's binary representation.
/// Also known as the Hamming weight or population count (popcount).
/// Used for calculating indices within the node's content array based on bitmaps.
int bitCount(int i) {
  // Optimized bit count (popcount/Hamming weight) using SWAR for 32 bits.
  // Assumes input 'i' relevant bits fit within 32 (true for dataMap/nodeMap).
  i = i & 0xFFFFFFFF; // Ensure we operate on lower 32 bits
  i = i - ((i >> 1) & 0x55555555);
  i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
  i = (i + (i >> 4)) & 0x0F0F0F0F;
  i = i + (i >> 8);
  i = i + (i >> 16);
  return i & 0x3F; // Mask to get final count (0-32)
}

/// Extracts the relevant fragment (portion) of the [hash] code for a given [shift] level.
/// The [shift] determines which bits of the hash code are considered for this level.
int indexFragment(int shift, int hash) => (hash >> shift) & kBitPartitionMask;

/// Calculates the index within the data portion of the children/content list
/// corresponding to a given hash fragment [frag].
/// Requires the node's dataMap.
int dataIndexFromFragment(int frag, int dataMap) =>
    bitCount(dataMap & ((1 << frag) - 1));

/// Calculates the index within the node portion of the children/content list
/// corresponding to a given hash fragment [frag].
/// Requires the node's nodeMap.
int nodeIndexFromFragment(int frag, int nodeMap) =>
    bitCount(nodeMap & ((1 << frag) - 1));

/// Calculates the starting index in the children/content list for a data entry,
/// given its index within the conceptual data array ([dataIndex]).
int contentIndexFromDataIndex(int dataIndex) => dataIndex * 2;

/// Calculates the index in the children/content list for a child node,
/// given its index within the conceptual *reversed* node array ([nodeIndex]).
/// Requires the total length of the content list.
/// Nodes are stored in reverse order at the end of the list.
int contentIndexFromNodeIndex(int nodeIndex, int listLength) =>
    listLength -
    1 -
    nodeIndex; // Using the optimized version from previous attempt

// --- Transient Ownership ---

/// A marker object used to track ownership during transient (mutable) operations
/// on CHAMP Trie nodes.
///
/// When performing bulk operations like `addAll` or `fromMap`, nodes can be
/// temporarily mutated in place if they share the same [TransientOwner]. This
/// avoids excessive copying and improves performance. Once the operation is
/// complete, the tree is "frozen" back into an immutable state using `ChampNode.freeze`.
class TransientOwner {
  /// Creates a new unique owner instance.
  const TransientOwner();
}
