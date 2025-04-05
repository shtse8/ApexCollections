/// Defines the base abstract class [RrbNode] for RRB-Tree nodes,
/// constants, and the [TransientOwner] class.
library;

/// The branching factor (M) for the RRB-Tree. Determines the maximum number
/// of children an internal node can have or elements a leaf node can hold.
/// Typically a power of 2, often 32 for good performance characteristics.
const int kBranchingFactor = 32; // Or M, typically 32

/// The base-2 logarithm of the [kBranchingFactor]. Used for efficient index
/// calculations within the tree structure (log2(32) = 5).
const int kLog2BranchingFactor = 5; // log2(32)

/// Maximum allowed extra search steps for the Search Step Invariant.
/// Used during rebalancing. A common value is 2.
const int kEMax = 2;

// --- Transient Ownership ---

/// A marker object used to track ownership during transient (mutable) operations
/// on RRB-Tree nodes.
///
/// When performing bulk operations like `addAll` or `fromIterable`, nodes can be
/// temporarily mutated in place if they share the same [TransientOwner]. This
/// avoids excessive copying and improves performance. Once the operation is
/// complete, the tree is "frozen" back into an immutable state using [RrbNode.freeze].
class TransientOwner {
  /// Creates a new unique owner instance.
  const TransientOwner();
}

/// Abstract base class for nodes in the Relaxed Radix Balanced Tree (RRB-Tree).
///
/// Nodes can be either internal ([RrbInternalNode]) containing child nodes,
/// or leaf ([RrbLeafNode]) nodes containing the actual list elements.
/// Nodes are immutable by default but support transient mutation via the
/// [TransientOwner] mechanism for performance optimization during bulk updates.
abstract class RrbNode<E> {
  /// Optional owner for transient nodes. If non-null, this node might be mutable
  /// by the holder of this specific [TransientOwner] instance.
  TransientOwner? _owner; // Made mutable for freezing

  /// Constructor for subclasses. Assigns an optional [owner] for transient state.
  RrbNode([this._owner]); // Changed to non-const

  /// The height of the subtree rooted at this node.
  /// Leaf nodes ([RrbLeafNode]) have height 0. Internal nodes have height > 0.
  int get height;

  /// The total number of elements stored in the subtree rooted at this node.
  int get count;

  /// Returns `true` if this node is a leaf node ([RrbLeafNode]).
  bool get isLeaf => height == 0;

  /// Returns `true` if this node is an internal node ([RrbInternalNode]).
  bool get isBranch => height > 0;

  /// Retrieves the element at the effective [index] within this subtree.
  ///
  /// The [index] is relative to the start of the elements covered by this node.
  /// It must be non-negative and less than this node's [count].
  /// Complexity: O(log N) due to tree traversal.
  E get(int index);

  /// Returns a new node structure representing the tree after updating the
  /// element at the effective [index] within this subtree with the new [value].
  ///
  /// The [index] must be non-negative and less than this node's [count].
  /// Returns `this` if the value is identical to the existing value.
  /// Complexity: O(log N).
  RrbNode<E> update(int index, E value);

  /// Returns a new node structure representing the tree after appending [value]
  /// to the end of the subtree represented by this node.
  ///
  /// This might involve node splits and increasing tree height if nodes are full.
  /// Complexity: Amortized O(log N), potentially O(1) with tail optimizations.
  RrbNode<E> add(E value);

  /// Returns a new node structure representing the tree after removing the
  /// element at the effective [index] within this subtree.
  ///
  /// The [index] must be non-negative and less than this node's [count].
  /// This might involve node merges or rebalancing (using steal or plan-based
  /// redistribution) to maintain RRB-Tree invariants if nodes become underfull.
  /// The tree height may decrease if the root collapses.
  /// Returns `null` if the node becomes empty after removal.
  ///
  /// Accepts an optional [owner] to perform the operation transiently (mutating
  /// nodes in place if possible). If [owner] is null or doesn't match the node's
  /// owner, the operation is performed immutably, returning new node instances.
  /// Complexity: O(log N).
  RrbNode<E>? removeAt(int index, [TransientOwner? owner]); // Added owner

  /// Returns `true` if this node represents an empty tree structure.
  ///
  /// Only the canonical empty leaf node should return true.
  bool get isEmptyNode => false;

  /// Returns `true` if this node is currently mutable and belongs to the
  /// specified [owner].
  bool isTransient(TransientOwner? owner) => owner != null && _owner == owner;

  /// Internal method for subclasses to clear the owner during freeze.
  void internalClearOwner(TransientOwner? freezerOwner) {
    if (isTransient(freezerOwner)) {
      _owner = null;
    }
  }

  /// Internal method for subclasses to set the owner (used by ensureMutable).
  void internalSetOwner(TransientOwner? newOwner) {
    // This should typically only be called when creating a mutable copy
    // or ensuring an existing node is mutable under the correct owner.
    _owner = newOwner;
  }

  /// Returns an immutable version of this node.
  ///
  /// If the node is transient and owned by the provided [owner], it recursively
  /// freezes its children (if any), clears its owner, makes its internal lists
  /// unmodifiable, and returns itself. Otherwise, returns `this`.
  RrbNode<E> freeze(TransientOwner? owner);

  /// Returns a new node structure representing the tree after inserting [value]
  /// at the effective [index] within this subtree.
  ///
  /// The [index] must be non-negative and less than or equal to this node's [count].
  /// This might involve node splits and increasing tree height.
  /// Complexity: O(log N).
  RrbNode<E> insertAt(int index, E value);
}
