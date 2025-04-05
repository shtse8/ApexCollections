<!-- Version: 1.1 | Last Updated: 2025-04-05 | Updated By: Cline -->
# System Patterns: ApexCollections

## Core Architecture
The library will consist of distinct, immutable collection classes (`ApexList`, `ApexMap`, etc.) built upon underlying persistent data structures.

## Key Data Structures & File Structure (Updated: 2025-04-05 ~06:45 UTC+1)

The underlying persistent data structures are critical for performance.

-   **For `ApexList`:**
    -   **Selected:** Relaxed Radix Balanced Trees (RRB-Trees).
    -   *File Structure:*
        -   `lib/src/list/rrb_node_base.dart`: Abstract `RrbNode`, constants, `TransientOwner`.
        -   `lib/src/list/rrb_internal_node.dart`: `RrbInternalNode` implementation.
        -   `lib/src/list/rrb_leaf_node.dart`: `RrbLeafNode` implementation.
        -   `lib/src/list/rrb_tree_utils.dart`: Helper functions (concatenation, slicing, etc.).
    -   *Rationale:* Offers efficient O(log N) concatenation, slicing, and insertion/deletion at arbitrary indices, while maintaining fast O(log N) lookup and update. Performance benchmarks confirm its effectiveness for `ApexList`.
-   **For `ApexMap`:**
    -   **Attempted:** Compressed Hash-Array Mapped Prefix Trees (CHAMP).
    -   *File Structure (CHAMP Attempt):*
        -   `lib/src/map/champ_node_base.dart`: Abstract `ChampNode`, result types.
        -   `lib/src/map/champ_bitmap_node.dart`: Abstract `ChampBitmapNode`.
        -   `lib/src/map/champ_empty_node.dart`: `ChampEmptyNode` implementation.
        -   `lib/src/map/champ_data_node.dart`: `ChampDataNode` implementation.
        -   `lib/src/map/champ_collision_node.dart`: `ChampCollisionNode` implementation.
        -   `lib/src/map/champ_sparse_node.dart`: `ChampSparseNode` implementation (extends `ChampBitmapNode`).
        -   `lib/src/map/champ_array_node_base.dart`: Abstract `ChampArrayNode` (extends `ChampBitmapNode`).
        -   `lib/src/map/champ_array_node_impl.dart`: Concrete `ChampArrayNodeImpl`.
        -   `lib/src/map/champ_array_node_*.dart` (e.g., `_get`, `_add`): Extension methods for `ChampArrayNode`. (Note: Splitting via extensions was reverted for `ApexMapImpl` itself due to issues, but kept for node logic for now).
        -   `lib/src/map/champ_utils.dart`: Constants, helper functions (`bitCount`, `indexFragment`), `TransientOwner`.
        -   `lib/src/map/champ_merging.dart`: Logic for merging entries/nodes.
        -   `lib/src/map/champ_iterator.dart`: CHAMP Trie iterator.
        -   *Initial Rationale:* Theoretical advantages over HAMT in cache locality, memory usage, and iteration speed.
        -   *Outcome:* While `addAll`, `remove`, and `update` performed well, the Dart implementation faced significant challenges in achieving competitive iteration performance (~2.5x slower than FIC's HAMT). Multiple optimization attempts failed due to complexity and introducing logic errors. `add` and `lookup` were also slower than FIC.
    -   **Next Candidate:** Hash Array Mapped Tries (HAMT).
        -   *Rationale:* Used by the primary competitor (`fast_immutable_collections`) and demonstrates better iteration and lookup performance in that context. While potentially slower in some operations like `remove` compared to CHAMP, its overall performance profile, particularly for iteration and lookup, appears more promising given the difficulties encountered with CHAMP in Dart.
        -   *Status:* Research and design phase (Phase 4.5) initiated to evaluate and potentially implement HAMT for `ApexMap`.

The choice of data structure aims for the best *overall* performance profile across common operations (add, remove, update, lookup, iteration) for typical Dart use cases, acknowledging that trade-offs may exist.

## API Design Philosophy

-   **Immutability:** All operations must return new collection instances, leaving the original unchanged.
-   **Efficiency:** Operations should strive for optimal asymptotic complexity (e.g., near O(log N) or O(1) where possible) and low constant factors. Copy-on-write semantics are fundamental.
-   **Dart Idioms:** Leverage Dart features like extension methods, effective typing, and potentially patterns/records where appropriate to provide a seamless developer experience.
-   **Interoperability:** Design constructors and conversion methods (`toList`, `toMap`, etc.) to be efficient and easy to use with standard Dart `Iterable`s.

## Testing Strategy

-   Comprehensive unit tests for all public API methods.
-   Property-based testing to cover a wider range of inputs and edge cases.
-   Benchmarking tests to track performance regressions/improvements.
-   Tests for immutability guarantees (ensuring original collections are never modified).