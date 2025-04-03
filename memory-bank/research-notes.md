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

### Initial Research Tasks:

-   [ ] Read and summarize the core concepts from the primary Bagwell/Rompf (2011) paper.
-   [ ] Read and summarize practical implementation details from the Stucki et al. (2015) paper.
-   [ ] Investigate the structure of nodes, branching factor, balancing mechanisms, and algorithms for key operations (append, update, lookup, slice, concat).
-   [ ] Assess feasibility for `const` empty list creation in Dart.

## CHAMP Tries (for `ApexMap`)

-   *(Research not yet started)*