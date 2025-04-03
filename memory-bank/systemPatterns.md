# System Patterns: ApexCollections

## Core Architecture

The library will consist of distinct, immutable collection classes (`ApexList`, `ApexMap`, etc.) built upon underlying persistent data structures.

## Key Data Structures (To Be Researched/Decided - Phase 1/2)

The core challenge and innovation lie in selecting/designing the underlying persistent data structures. Candidates include:

-   **For List-like structures:**
    -   Relaxed Radix Balanced Trees (RRB-Trees)
    -   Variations of B-trees adapted for persistence
    -   Paged structures
-   **For Map/Set-like structures:**
    -   Hash Array Mapped Tries (HAMT) - (Used by `fast_immutable_collections`, Clojure, Scala)
    -   Compressed Hash-Array Mapped Prefix Trees (CHAMP) - (Potential performance improvements over HAMT)
    -   Variations of balanced binary search trees (e.g., AVL, Red-Black) adapted for persistence (if ordered collections are desired later).

The choice will be driven by Phase 1 research and benchmarking, aiming for the best overall performance profile across common operations (add, remove, update, lookup, iteration) for typical Dart use cases.

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