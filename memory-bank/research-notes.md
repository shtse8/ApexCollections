# Research Notes: Phase 1

## Objective

Track research findings for candidate data structures (`ApexList`, `ApexMap`) as outlined in `phase1-plan.md`.

## RRB-Trees (for `ApexList`)

**(Timestamp: 2025-04-03 ~02:52 UTC+1)**

Initial research based on `clojure/core.rrb-vector/doc/rrb-tree-notes.md` and web searches.

### Key Resources Identified:

1.  **Primary Theoretical Paper:**
    -   Bagwell, P., & Rompf, T. (2011). *RRB-Trees: Efficient Immutable Vectors*. EPFL-REPORT-169879.
    -   *Status:* Located PDF link. **Action:** Study for core concepts and algorithms.
2.  **Practical Implementation Paper:**
    -   Stucki, N., Rompf, T., Ureche, V., & Bagwell, P. (2015). *RRB Vector: A Practical General Purpose Immutable Sequence*. ICFP '15.
    -   *Status:* Located PDF link. **Action:** Study for practical implementation details, optimizations, and performance characteristics, especially related to the Scala implementation.
3.  **Stucki's Master Thesis (Scala Implementation):**
    -   Stucki, N. (2015). *Turning Relaxed Radix Balanced Vector from Theory into Practice for Scala Collections*.
    -   *Status:* Located PDF link. **Action:** Refer to for in-depth Scala implementation details if needed.
4.  **L'orange's Master Thesis (Transience):**
    -   L'orange, J. N. (2014). *Improving RRB-Tree Performance through Transience*.
    -   *Status:* Located PDF link. **Action:** Study later for optimization techniques (mutable transients for batch operations).
5.  **Puente's Paper/Talk (C++ Implementation - `immer`):**
    -   Puente, J. P. B. (2017). *Persistence for the Masses: RRB-Vectors in a Systems Language*. Proc. ACM Program. Lang. 1, ICFP.
    -   *Status:* Located PDF link and talk video. **Action:** Review for insights relevant to low-level implementation details.
6.  **Other Implementations (Code Study):**
    -   `scala-rrb-vector` (Scala)
    -   `immer` (C++)
    -   `im::Vector` (Rust)
    -   `core.rrb-vector` (Clojure) - *Note: This library seems to be the source of the notes file, not necessarily a direct RRB implementation itself? Needs clarification.*
    -   *Status:* Links available. **Action:** Browse codebases for structural patterns and algorithm implementations after understanding the core concepts from papers.


### Core Concepts (Updated Summary - 2025-04-03 ~02:54 UTC+1)

-   **Foundation:** Extends standard persistent vectors (wide, fixed-branching-factor trees, typically power-of-2 like 32) by incorporating ideas from B-trees.
-   **Key Improvement:** Enables efficient **concatenation, insert-at (arbitrary index), and splits** in **O(log N)** time, unlike standard vectors where these can be O(N).
-   **Preserved Performance:** Maintains fast **O(log N) indexing (lookup), updates, and iteration** speeds comparable to standard vectors.
-   **Hybrid Node Structure:** Utilizes both "strict" and "relaxed" nodes:
    -   **Strict Nodes:** Aim for fixed power-of-2 size, packed left, partially filled only on the right edge (like standard vectors).
    -   **Relaxed Nodes:** Allow more flexible child counts (potentially `m` to `2m-1` range) and child sub-tree sizes that don't strictly align with powers of 2. This flexibility is key for efficient structural changes.
    -   **Rightmost Spine Relaxation:** Nodes on the far right edge have even less strict minimum size constraints.
-   **Invariant:** Ensures overall tree balance (all leaves at same depth) while permitting the mix of strict/relaxed nodes. This allows efficient radix-based indexing (with potentially minor linear scans within relaxed nodes) alongside efficient O(log N) structural modifications (concat, insert, slice).
-   **Focus Buffer:** Often employs a "focus" buffer (small array near the last modification point) to optimize localized updates/inserts, as opposed to just a "tail" buffer (always at the end).


### Concatenation Algorithm (Summary - 2025-04-03 ~02:56 UTC+1)

Based on Peter Horne-Khan's explanation:

-   **Problem Context:** Strict persistent vectors require O(N) concatenation due to cascading node rebalancing to maintain fixed node sizes.
-   **RRB Approach:** Uses a recursive merge strategy:
    1.  Descend the rightmost path of the left tree and leftmost path of the right tree.
    2.  At each level, merge the boundary nodes into a new 'middle' node.
    3.  Combine slots/children from the left parent (minus rightmost), the new middle node, and the right parent (minus leftmost).
-   **Search Step Invariant (`S <= ceil(P/M) + E`):** This is key. Instead of enforcing strict node sizes, it allows a small, constant (`E`) number of extra slots beyond the optimal (`ceil(P/M)`).
-   **Conditional Rebalancing:** Rebalancing (redistributing elements between slots) only occurs *if* the combined node violates the Search Step Invariant.
-   **Rebalancing Process:** If needed, a 'plan' shifts elements minimally between adjacent slots to satisfy the invariant, crucially *reusing* unchanged nodes/subtrees.
-   **Efficiency:** By avoiding unnecessary rebalancing and reusing nodes, concatenation becomes O(log N) (proportional to tree height).
-   **Propagation:** The merged/rebalanced node propagates upwards, potentially triggering merges at higher levels. Redundant root levels are removed.


### Concatenation/Rebalancing Details (Based on Horne-Khan Blog - 2025-04-03 ~03:07 UTC+1)

-   **Size Tables:** When nodes are relaxed (not strictly size M), they require an associated 'size table'. This table stores the *cumulative* count of leaf elements contained within or to the left of each corresponding child slot. This allows finding the correct child slot even with variable sizes.
-   **Relaxed Radix Search:** Navigation uses a two-step process:
    1.  *Radix Step:* Calculate the approximate slot using bit shifts (`idx >> (BIT_WIDTH * height)`), same as standard vectors.
    2.  *Linear Scan Step:* Use the size table to step forward from the approximate slot until the correct slot (whose cumulative size is >= index) is found (`while (sizes[slot] <= idx) slot++`). The Search Step Invariant bounds the number of extra linear steps needed.
-   **Search Step Invariant (`S <= ceil(P/M) + E`):** Confirmed as the core invariant for rebalancing. Allows `E` (e.g., 2) extra slots beyond the optimal count (`ceil(P/M)`) for `P` elements/sub-nodes distributed across `S` actual slots.
-   **Rebalancing Algorithm (when invariant violated during merge):
    1.  *Plan Calculation:* Determine the target distribution of elements across slots to satisfy the invariant. Skips slots that are already sufficiently full (e.g., >= `M - E/2` items). Redistributes items from the first underfull slot into subsequent slots.
    2.  *Plan Execution:* Create new nodes based on the calculated plan, reusing existing nodes/sub-trees wherever possible to minimize copying.




### Split and Insert-At Algorithms (Summary - 2025-04-03 ~03:00 UTC+1)

Based on Bagwell/Rompf (2011) paper, Section 4:

-   **`split(index)`:**
    -   Implemented via left and right slicing.
    -   *Right Slice:* Traverses down path defined by `index`, makes it the new right edge, drops nodes to the right.
    -   *Left Slice:* Traverses down path defined by `index`, makes it the new left edge, drops nodes to the left, shifts remaining nodes left during copy.
    -   *Lazy Balancing:* Slicing might temporarily violate the relaxed invariant; this is fixed lazily during subsequent concatenations involving the sliced parts.
    -   *Complexity:* Stated as O(log N) overall for splits.
-   **`insert-at(index, value)`:**
    -   Achieved by combining split and concatenate:
        1.  `split(index)` into `left_part`, `right_part` (O(log N)).
        2.  Create `middle_part` (new vector with `value`) (O(1)).
        3.  `concatenate(left_part, middle_part)` (O(log N)).
        4.  `concatenate(result, right_part)` (O(log N)).
    -   *Overall Complexity:* O(log N).



### Append and Update Algorithms (Summary - 2025-04-03 ~03:01 UTC+1)

Based on Bagwell/Rompf (2011) paper, Sections 1.2 & 5.1:

-   **Core Mechanism:** Both operations involve copying the path from root to the affected leaf (O(log N)).
-   **Tail/Focus Optimization (for effective constant time):
    -   *Append:* A separate buffer (tail/focus, e.g., 32 elements) holds the last block. Appending usually copies only this buffer (O(1)). Integrating a full buffer into the main tree is O(log N), leading to amortized constant time.
    -   *Update:* If index is in the focus block, only copy that block (O(1)). If outside, move focus (O(log N) path copy using 'display' stack) then update in focus (O(1) copy). Optimizes for spatio-temporal locality.


### Initial Research Tasks:

-   [ ] Read and summarize the core concepts from the primary Bagwell/Rompf (2011) paper.
-   [ ] Read and summarize practical implementation details from the Stucki et al. (2015) paper.
-   [ ] Investigate the structure of nodes, branching factor, balancing mechanisms, and algorithms for key operations (append, update, lookup, slice, concat).
-   [ ] Assess feasibility for `const` empty list creation in Dart.


### `const` Empty List Feasibility (Assessment - 2025-04-03 ~03:03 UTC+1)

-   An empty RRB-Tree can be represented by a `null` root or a singleton empty node.
-   A `const ApexList()` constructor could initialize `root = null` and `count = 0`.
-   Alternatively, a shared singleton empty node instance (e.g., representing an empty leaf `const []`) can be `const`.
-   **Conclusion:** Feasible in Dart.

## CHAMP Tries (for `ApexMap`)

**(Timestamp: 2025-04-03 ~02:55 UTC+1)**

Initial research based on web searches.

### HAMT Structure (Foundation for CHAMP):

-   **Hybrid:** Combines hash tables and array-mapped tries (prefix trees).
-   **Hashing:** Keys are hashed.
-   **Trie Path:** Hash is split into chunks (e.g., 5 bits per level) to determine the path down the trie.
-   **Sparse Nodes:** Nodes use a bitmap to track occupied child slots and a dense array for actual child pointers, saving memory compared to full arrays.
-   **Collision Handling:** When keys hash to the same path/bucket, a secondary mechanism (e.g., list) stores colliding entries.


### Core Concepts (Preliminary):

-   **Improvement over HAMT:** CHAMP (Compressed Hash-Array Mapped Prefix Trie) is designed as an optimization over HAMT (Hash-Array Mapped Trie), which is used by `fast_immutable_collections`.
-   **Goals:** Aims for better performance (potentially iteration) and lower memory usage compared to HAMT.
-   **Mechanism:** Likely involves different node representations or compression techniques within the trie structure compared to HAMT.

### CHAMP vs HAMT Comparison (Summary - 2025-04-03 ~02:57 UTC+1)

Based on Ziqi Wang's paper review:

| Feature             | HAMT (Baseline)                                  | CHAMP (Optimized)                                                                 |
| :------------------ | :----------------------------------------------- | :-------------------------------------------------------------------------------- |
| **Node Storage**    | Fixed-size arrays (e.g., 32 slots), many NULLs | Compact arrays, no NULLs stored. Bitmaps (`nodeMap`, `dataMap`) track occupancy. |
| **Memory Usage**    | Higher due to NULLs                              | Lower on average (eliminates NULLs).                                              |
| **Cache Locality**  | Poorer (sparse nodes, interleaved data/pointers) | Better (dense nodes, data/pointers potentially grouped).                          |
| **Deletion**        | Leaves non-canonical structure (singleton paths) | Path compression ("folding") ensures canonical structure.                         |
| **Equality Check**  | Content-based (iteration), inefficient         | Structure-based (bitmaps, elements, recursive), efficient due to canonical form.  |
| **Iteration**       | Potentially poor cache locality                  | Optimized locality (iterate local data first, then recurse).                      |
| **Optional**        | -                                                | Can store incremental hashes (element/node/tree) for faster comparisons.          |




### CHAMP Node Structure & Insertion (Summary - 2025-04-03 ~03:02 UTC+1)

Based on Steindorfer (2017) thesis, Chapter 3:

**Node Structure:**

-   **Dual Bitmaps:** Uses `datamap` (for payload presence) and `nodemap` (for sub-node presence) instead of HAMT's single bitmap + dynamic checks.
-   **Compact Array:** Stores payloads and sub-node pointers contiguously in a single `Object[]`, eliminating NULLs.
-   **Optimized Layout:** Payloads stored from the start (index 0 upwards), sub-nodes stored from the end (index `array.length - 1` downwards) to simplify indexing and avoid storing the payload count explicitly.
-   **Indexing:** Uses `Integer.bitCount` on the relevant bitmap (`datamap` for payload, `nodemap` for sub-nodes) combined with the array length for efficient offset calculation into the compact array.

**Insertion Algorithm Principles:**

1.  **Hashing & Path:** Determine hash chunk and `bitpos` for the current level.
2.  **Check Slot:** Examine `datamap` and `nodemap` at `bitpos`.
3.  **Empty Slot:** Copy node, insert payload into data section, set `datamap` bit.
4.  **Data Slot:**
    -   *Keys Equal:* Update value (if map) or return original. Create new node if value updated.
    -   *Keys Different (Hash Collision):* Create collision node, replace original payload with collision node (no bitmap change).
    -   *Keys Different (Hashes Differ):* Path expansion needed. Create new sub-node one level deeper, insert both old and new payloads into it. Modify current node: clear `datamap` bit, set `nodemap` bit, replace old payload with new sub-node pointer in the compact array.
5.  **Sub-Node Slot:** Recursively call insert on sub-node. If recursion returns a modified sub-node, update the pointer in a new copy of the current node.
6.  **Path Copying:** All modifications create new node copies up the path to the root.


### CHAMP Deletion Algorithm & Canonicalization (Summary - 2025-04-03 ~03:09 UTC+1)

Based on Steindorfer (2017) thesis, Chapter 3.4:

-   **Goal:** Maintain canonical form (no singleton paths, single elements inlined) via invariant `branchSize >= 2 * nodeArity + payloadArity`.
-   **Process:** Recursive deletion down the hash path.
-   **Canonicalization on Return:** When returning from recursion (`isModified == true`):
    -   *Check Node Arity & Result Branch Size:* Use `arity` of current node and `branchSize` (approximated by `sizePredicate`) of the returned node (`resultNode`).
    -   *Case A (Singleton Path Collapse):* If `current.arity == 1` && `resultNode.branchSize == 1`, return `resultNode` directly (removes current node).
    -   *Case B (Singleton Path Persists):* If `current.arity == 1` && `resultNode.branchSize > 1`, update current node's pointer to `resultNode`.
    -   *Case C (Inline Collapsed Child):* If `current.arity > 1` && `resultNode.branchSize == 1`, inline the single element from `resultNode` into the current node (replace sub-node pointer with data payload, update bitmaps).
    -   *Case D (Standard Update):* Otherwise, update the current node's pointer to `resultNode`.
-   **`sizePredicate`:** Efficient local approximation of `branchSize` (returns EMPTY, ONE, or MORE_THAN_ONE) used for canonicalization logic.
-   **Result:** Ensures identical trees for identical content, enabling efficient structure-based equality.



### Key Resources Identified:

1.  **Primary Resource (Thesis):**
    -   Steindorfer, M. *Efficient Immutable Collections*. PhD Thesis. (Link found via Scala issue tracker).
    -   *Status:* Link available. **Action:** Study for the definitive explanation of CHAMP.
2.  **Paper Summary/Comparison:**
    -   [https://wangziqi2013.github.io/paper/2020/08/28/CHAMP.html](https://wangziqi2013.github.io/paper/2020/08/28/CHAMP.html)
    -   *Status:* Link available. **Action:** Read for a summary of CHAMP vs. HAMT differences and claimed improvements.
3.  **Implementation (Java):**
    -   `norswap/triemap` ([https://github.com/norswap/triemap](https://github.com/norswap/triemap))


### `const` Empty Map Feasibility (Assessment - 2025-04-03 ~03:03 UTC+1)

-   An empty CHAMP Trie is typically represented by a shared singleton empty node instance.
-   This empty node instance would have `datamap = 0`, `nodemap = 0`, and `contentArray = const []`.
-   Such a node can be declared `const` in Dart.
-   The `ApexMap` class can have a `const` constructor referencing this shared `const` empty node and setting `count = 0`.
-   **Conclusion:** Feasible in Dart.
    -   *Status:* Link available. **Action:** Browse codebase later for implementation details.

### Initial Research Tasks:

-   [ ] Understand the basic structure of HAMT first (as CHAMP builds upon it).
-   [ ] Read the summary/comparison resource to grasp the key differences between CHAMP and HAMT.
-   [ ] Study Steindorfer's thesis/papers for the detailed CHAMP specification.
-   [ ] Assess feasibility for `const` empty map creation in Dart.

## CHAMP Optimizations (OOPSLA'15 - Steindorfer & Vinju)

Key optimizations proposed for Hash-Array Mapped Tries (HAMT) on the JVM, resulting in the CHAMP design:

1.  **Node Layout Reordering & Compression:**
    *   Separates sub-node references and key/value data entries within the node's content array.
    *   Uses two bitmaps (`dataMap`, `nodeMap`) to track the presence of data and nodes respectively.
    *   **Optimized Layout:** Stores sub-node references in *reverse* order at the end of the array. This allows calculating the node index via `array.length - 1 - index(nodeMap, bitpos)`, avoiding the need to calculate `bitCount(dataMap)` for offset.
    *   **Benefit:** Improves cache locality for iteration (data processed first, then nodes) and saves memory in maps by eliminating empty slots needed in traditional HAMTs for node pointers.

2.  **Canonical Representation via Compaction on Delete:**
    *   Ensures the trie remains in its most compact form even after deletions.
    *   Defines an invariant: `branchSize >= 2 * nodeArity + payloadArity` (sub-trees with arity < 2 are collapsed or inlined).
    *   Deletion algorithm recursively removes the element and then compacts/inlines nodes on the way back up based on arity and an approximated `sizePredicate` (Empty, One, MoreThanOne) to avoid costly full subtree size calculations.
    *   **Benefit:** Improves cache locality, reduces memory footprint, and enables faster equality checks.

3.  **Faster Equality Checking:**
    *   Leverages the canonical representation.
    *   **Short-circuiting:** When comparing two CHAMP nodes, if their `dataMap` or `nodeMap` differ, they cannot be equal, allowing immediate return `false`.
    *   If bitmaps match, recursively compare content (e.g., using `ListEquality` for the node's content array).
    *   **Benefit:** Makes equality checking significantly faster, often sub-linear, especially when comparing derived collections that share structure.

4.  **Efficient Iterators:**
    *   Uses a pre-allocated stack (or simulates one) for node traversal.
    *   Iterates data entries within a node *before* descending into child nodes.
    *   Reduces iteration complexity from O(m + n) to O(n) node visits (where n is node count, m is data entry count).
    *   **Benefit:** Improves iteration performance due to better cache locality and fewer node visits.

5.  **Hash Code Memoization (Optional - MEMCHAMP):**
    *   **Collection Hash Code:** Cache the entire collection's hash code in the outer wrapper object and update it incrementally on add/remove. Requires insertion-order independent hashing.
    *   **Element Hash Code:** Consolidate element hash codes into an integer array within each node (field consolidation) instead of separate leaf nodes. Trades memory for potentially faster lookups (fewer `hashCode`/`equals` calls).

**Current Implementation Status (ApexMap):**
*   Node Layout: Implemented optimized layout (nodes reversed at end). (Done during file splitting refactor)
*   Canonical Representation: Deletion logic includes shrinking/collapsing. (Done during file splitting refactor)
*   Faster Equality: Implemented `hashCode`/`==` with bitmap short-circuiting. (Done)
*   Efficient Iterators: Basic structure exists, but optimization needed (e.g., avoid temporary MapEntry). (Pending)
*   Memoization: Not implemented. (Pending)


### CHAMP Implementation Outcome & Pivot (2025-04-05 ~12:52 UTC+1)

-   **Implementation:** A functional CHAMP-based `ApexMap` was implemented, including node structures, core operations (add, remove, update, lookup), and an iterator.
-   **Performance Reality:**
    -   Final benchmarks (with a correct but unoptimized iterator creating temporary `MapEntry` objects) showed significant performance issues compared to `fast_immutable_collections` (FIC), which uses HAMT:
        -   `iterateEntries`: ~3042 us (**~2.5x slower** than FIC ~1235 us).
        -   `toMap`: ~9099 us (Slower than FIC ~6915 us).
        -   `add`: ~4.34 us (Slower than FIC ~0.22 us).
        -   `lookup[]`: ~0.22 us (Slower than FIC ~0.06 us).
        -   `fromMap`: ~8979 us (Much slower than FIC ~1830 us).
    -   While `addAll` (~34 us), `remove` (~3.88 us), and `update` (~8.52 us) showed strong performance, the poor results for iteration, lookup, and add were major concerns.
-   **Optimization Attempts (Iterator):**
    -   The primary theoretical advantage of CHAMP (efficient iteration) was not realized in the initial implementation due to the overhead of creating temporary `MapEntry` objects.
    -   Two separate attempts were made to optimize the `ChampTrieIterator` by avoiding temporary object creation (using a `_BitmapPayloadRef` helper class to store references to data within nodes).
    -   **Both attempts failed**, introducing logic errors that caused numerous test failures. Reverting the optimization restored correctness but kept the poor iteration performance.
-   **Conclusion & Decision:**
    -   Despite CHAMP's theoretical advantages, achieving efficient *and* correct iteration performance in the Dart implementation proved highly complex and error-prone.
    -   The significant performance deficit in key operations (iteration, lookup, add) compared to the main competitor (FIC/HAMT) outweighed the benefits seen in other operations (`addAll`, `remove`, `update`).
    -   **Decision:** **Abandon CHAMP** as the underlying data structure for `ApexMap`.
-   **Next Step:** **Pivot to researching Hash Array Mapped Tries (HAMT)** as the alternative data structure for `ApexMap`. The focus will be on understanding HAMT implementations that prioritize iteration and lookup performance, learning from existing libraries like FIC.


## HAMT Research (Phase 4.5)

**(Timestamp: 2025-04-05 ~12:57 UTC+1)**

Following the decision to abandon CHAMP due to persistent iteration performance issues in the Dart implementation, research now focuses on Hash Array Mapped Tries (HAMT) as the alternative for `ApexMap`.

### Initial Findings & Resources (from Web Search):

1.  **Optimizing HAMT for JVM (The Morning Paper Review):**
    *   [https://blog.acolyer.org/2015/11/27/hamt/](https://blog.acolyer.org/2015/11/27/hamt/)
    *   *Relevance:* Reviews a paper comparing/optimizing HAMT implementations (Clojure, Scala) and CHAMP on the JVM. Discusses key differences like compaction on delete (Scala does, Clojure doesn't) and node structures. Highly relevant for understanding potential design choices and trade-offs for a Dart HAMT. **Action:** Study this article in detail.
2.  **Wikipedia - HAMT:**
    *   [https://en.wikipedia.org/wiki/Hash_array_mapped_trie](https://en.wikipedia.org/wiki/Hash_array_mapped_trie)
    *   *Note:* Mentions that HAMT performance can be improved by using a larger root table and the importance of the population count function (`Integer.bitCount` in Java/Dart).
3.  **Java/Scala Performance Discussions:**
    *   Stack Overflow and Medium articles discuss general Map performance in Java/Scala. May contain useful implementation details or pitfalls.
4.  **Existing Implementations (Non-Dart):**
    *   Various implementations exist in C++, C, Swift, Rust. Code study might be useful later.

### Key Focus Areas for Dart HAMT Research:

*   **Iteration Performance:** How do successful HAMT implementations (like FIC's) achieve fast iteration? What are the node structures and iteration algorithms used?
*   **Lookup/Add Performance:** How does HAMT compare to CHAMP in these areas in practice (contrary to initial CHAMP theory)?
*   **Node Structure:** What are the common node representations (bitmaps, array sizes, collision handling)?
*   **Compaction:** Is compaction on delete necessary or beneficial in the Dart context?
*   **Transience:** Can mutable transients be applied effectively to HAMT for batch operations?

### OOPSLA'15 Paper Analysis (Steindorfer & Vinju)

**(Timestamp: 2025-04-05 ~12:58 UTC+1)**

Detailed analysis of the paper "Optimizing Hash-Array Mapped Tries for Fast and Lean Immutable JVM Collections" reveals key CHAMP design principles and potential insights for our HAMT implementation:

**1. CHAMP Core Optimizations (vs. Traditional HAMT):**

*   **Node Layout (Section 3):**
    *   Separates payloads (data) and sub-nodes in a single compact array (payloads from start, nodes reversed from end).
    *   Uses two bitmaps (`datamap`, `nodemap`) for tracking and indexing.
    *   **Goal:** Improve cache locality, especially for iteration (process local data before recursion), theoretically reducing node visits from O(m+n) to O(n).
    *   **Indexing:** Optimized sub-node indexing (`array.length - 1 - index(nodemap, bitpos)`) avoids calculating `datamap` bit count for offset.
*   **Canonical Representation (Section 4):**
    *   Maintained via compaction and inlining during deletion (`branchSize >= 2 * nodeArity + payloadArity` invariant).
    *   **Goal:** Improve cache locality, reduce memory, enable fast structural equality checking.
    *   **Implementation:** Relies on the invariant and an efficient local `sizePredicate`.
*   **Efficient Iterators (Section 5.1):**
    *   Paper suggests using a pre-allocated stack.
    *   Emphasizes iterating node data *before* recursing into child nodes for O(n) node visit complexity.
*   **Faster Equality Checking (Section 4.3):**
    *   Leverages canonical form for bitmap short-circuiting.
    *   Combined with reference equality checks, often achieves sub-linear performance.

**2. Performance Claims (JVM - Section 6):**

*   Paper benchmarks show CHAMP significantly outperforms contemporary Scala/Clojure HAMTs on the JVM in iteration (1.3-6.7x), equality (3-25.4x), and memory footprint.

**3. Reflection on ApexCollections' Dart CHAMP Implementation:**

*   **Iteration Bottleneck:** Our primary issue. The theoretical O(n) node visit complexity wasn't achieved, likely due to:
    *   Overhead of creating temporary `MapEntry` objects during iteration.
    *   Failed attempts (`_BitmapPayloadRef`) to eliminate temporary objects introduced logic errors, highlighting implementation complexity.
    *   The paper's suggested iterator optimizations (pre-allocated stack, strict traversal order) might not have been perfectly implemented or were hindered by Dart runtime specifics.
*   **Dart vs. JVM:** Optimizations relying on JVM specifics (e.g., memory alignment) might not translate directly.
*   **Complexity:** Implementing CHAMP's canonicalization, indexing, and especially the optimized iterator correctly proved difficult and error-prone in Dart.

**4. Implications for HAMT Design (Phase 4.5):**

*   **Iterator is Paramount:** Designing an iterator that avoids temporary object allocation (like `MapEntry`) is crucial for performance. Studying `fast_immutable_collections` (FIC) iterator is a priority.
*   **Node Structure Trade-offs:** Re-evaluate the node structure. While CHAMP's layout is theoretically good for iteration, its complexity was problematic. A simpler traditional HAMT structure (e.g., single bitmap) might be easier to implement correctly and efficiently in Dart, even if it requires other minor trade-offs.
*   **Compaction Strategy:** Decide whether to implement compaction on delete. It aids canonicalization and equality checks but adds complexity. If fast equality isn't the top priority, skipping compaction (like Clojure) might simplify the implementation. Evaluate FIC's approach.
*   **Hash Code Caching:** Consider caching key hash codes within nodes to potentially speed up lookups/comparisons.
*   **Learn from FIC:** Deep dive into `fast_immutable_collections` source code for its HAMT node structure, collision handling, and particularly its iterator implementation.

