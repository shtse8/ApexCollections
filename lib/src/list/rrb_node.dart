/// Defines the core structures for RRB-Tree nodes used by ApexList.

const int _kBranchingFactor = 32; // Or M, typically 32
const int _kLog2BranchingFactor = 5; // log2(32)

/// Base class for RRB-Tree nodes.
abstract class RrbNode<E> {
  /// The height of the subtree rooted at this node.
  /// Leaf nodes have height 0.
  int get height;

  /// The total number of elements in the subtree rooted at this node.
  int get count;

  /// Whether this node represents a leaf (contains elements directly).
  bool get isLeaf => height == 0;

  /// Whether this node represents an internal branch (contains child nodes).
  bool get isBranch => height > 0;

  /// Retrieves the element at the effective [index] within this subtree.
  /// The [index] must be valid within the bounds of this node's [count].
  E get(int index);
}

/// Represents an internal node (branch) in the RRB-Tree.
/// Contains references to child nodes and potentially a size table if relaxed.
class RrbInternalNode<E> extends RrbNode<E> {
  @override
  final int height;

  @override
  final int count;

  /// Array containing child nodes (either RrbInternalNode or RrbLeafNode).
  /// The length is the number of slots currently used.
  final List<RrbNode<E>> children;

  /// Cumulative size table. Only present if the node is 'relaxed'
  /// (i.e., not all children subtrees have the maximum size for their height).
  /// `sizeTable[i]` stores the total count of elements in `children[0]` through `children[i]`.
  final List<int>? sizeTable;

  RrbInternalNode(this.height, this.count, this.children, [this.sizeTable])
    : assert(height > 0),
      assert(children.isNotEmpty),
      assert(sizeTable == null || sizeTable.length == children.length);

  /// Indicates if this node requires a size table for relaxed radix search.
  bool get isRelaxed => sizeTable != null;

  @override
  E get(int index) {
    assert(index >= 0 && index < count);

    final shift = height * _kLog2BranchingFactor;
    final indexInNode = (index >> shift) & (_kBranchingFactor - 1);

    if (isRelaxed) {
      // Relaxed Radix Search
      int slot = indexInNode;
      final sizes = sizeTable!;
      // Skip slots until we find the one containing the index
      // Need to check against the *previous* slot's cumulative size
      while (slot > 0 && sizes[slot - 1] > index) {
        slot--; // Should not happen often if radix is close
      }
      while (sizes[slot] <= index) {
        slot++; // Linear scan for the correct slot
      }

      final child = children[slot];
      final indexInChild = (slot == 0) ? index : index - sizes[slot - 1];
      return child.get(indexInChild);
    } else {
      // Strict Radix Search (fixed size children)
      final child = children[indexInNode];
      final indexInChild = index & ((1 << shift) - 1); // Mask out upper bits
      return child.get(indexInChild);
    }
  }
}

/// Represents a leaf node in the RRB-Tree.
/// Contains the actual list elements.
class RrbLeafNode<E> extends RrbNode<E> {
  @override
  int get height => 0;

  @override
  int get count => elements.length;

  /// Array containing the elements stored in this leaf.
  /// Length should be between 1 and _kBranchingFactor.
  final List<E> elements;

  RrbLeafNode(this.elements)
    : assert(elements.isNotEmpty),
      assert(elements.length <= _kBranchingFactor);

  @override
  E get(int index) {
    assert(index >= 0 && index < count);
    return elements[index];
  }
}

// TODO: Implement factory constructors or static methods for creating nodes.
// TODO: Implement methods for node operations (get, update, insert, concat, etc.).
