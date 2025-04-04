# System Patterns: ApexCollections

## Core Architecture

The library will consist of distinct, immutable collection classes (`ApexList`, `ApexMap`, etc.) built upon underlying persistent data structures.

## Key Data Structures (Updated: 2025-04-05 ~12:51 UTC+1)

The underlying persistent data structures are critical for performance.

-   **For `ApexList`:**
    -   **Selected:** Relaxed Radix Balanced Trees (RRB-Trees).
    -   *Rationale:* Offers efficient O(log N) concatenation, slicing, and insertion/deletion at arbitrary indices, while maintaining fast O(log N) lookup and update. Performance benchmarks confirm its effectiveness for `ApexList`.
-   **For `ApexMap`:**
    -   **Attempted:** Compressed Hash-Array Mapped Prefix Trees (CHAMP).
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