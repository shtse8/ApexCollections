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

### Initial Research Tasks:

-   [ ] Read and summarize the core concepts from the primary Bagwell/Rompf (2011) paper.
-   [ ] Read and summarize practical implementation details from the Stucki et al. (2015) paper.
-   [ ] Investigate the structure of nodes, branching factor, balancing mechanisms, and algorithms for key operations (append, update, lookup, slice, concat).
-   [ ] Assess feasibility for `const` empty list creation in Dart.

## CHAMP Tries (for `ApexMap`)

-   *(Research not yet started)*