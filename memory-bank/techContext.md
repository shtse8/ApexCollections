# Technical Context: ApexCollections

## Core Language & Platform

-   **Language:** Dart (latest stable version)
-   **Platform:** Multi-platform (intended to run wherever Dart runs - VM, AOT, Web)

## Key Dependencies

-   **Dart SDK:** The primary dependency.
-   **`package:collection`:** May leverage utility functions if beneficial, but core structures will be custom.
-   **`package:meta`:** For annotations like `@immutable`.
-   **Testing:**
    -   `package:test`: Standard Dart testing framework.
    -   Potentially `package:fake_async` for time-sensitive tests.
    -   Potentially a property-based testing library if adopted.
-   **Benchmarking:**
    -   `package:benchmark_harness`: Standard Dart benchmarking tools.

*Initially, the core implementation will aim for minimal external dependencies beyond the Dart SDK and standard testing/meta packages.*

## Development Environment & Tooling

-   **Version Control:** Git / GitHub
-   **Package Manager:** Pub (Dart's package manager)
-   **IDE:** VS Code recommended (or any Dart-compatible IDE)
-   **Formatting:** `dart format`
-   **Static Analysis:** `dart analyze` (with strict linting rules, potentially `package:lints` or a custom set)
-   **CI/CD:** GitHub Actions

## Technical Constraints & Considerations

-   **Performance:** Achieving superior performance across *all* operations is a major constraint and driver for technical decisions (data structure selection, algorithm optimization).
-   **Memory Usage:** Immutable collections can potentially increase memory pressure due to object allocation. Efficient memory sharing (structural sharing) is critical.
-   **Dart Ecosystem Compatibility:** Must work seamlessly with Dart's type system, asynchronous patterns, and common frameworks (especially Flutter).
-   **Web Compatibility:** Ensure code compiles and performs well when targeting JavaScript (dart2js / DDC). This might influence certain low-level implementation choices.