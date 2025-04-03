# Project Brief: ApexCollections

## Core Goal

To create a new immutable collection library for Dart, named **ApexCollections**, that aims to surpass existing solutions like `fast_immutable_collections` in both performance and developer experience.

## Key Objectives

1.  **Superior Performance:** Achieve faster performance across key collection operations compared to `fast_immutable_collections` and native Dart collections, validated through rigorous benchmarking. The initial ambition is to be faster in *all* operations, though trade-offs may be necessary.
2.  **Seamless Dart Integration:** Provide an intuitive, Dart-idiomatic API that integrates smoothly with native Dart types (`List`, `Map`, `Iterable`) and common frameworks (like Flutter), minimizing friction for developers.
3.  **Comprehensive Feature Set:** Offer a rich set of immutable collection types (starting with List and Map) and operations.
4.  **Robustness & Reliability:** Ensure correctness through extensive unit testing.
5.  **Excellent Documentation:** Provide clear, comprehensive documentation (API docs, tutorials, examples) hosted on GitHub Pages.
6.  **Automated Workflow:** Implement CI/CD using GitHub Actions for automated testing, analysis, and publishing to `pub.dev`.

## Project Scope

-   Initial focus: `ApexList` and `ApexMap`.
-   Future considerations: `ApexSet`, potentially other specialized collections.
-   Target platform: Dart (multi-platform).