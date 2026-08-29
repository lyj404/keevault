<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## Commands

- Lint / static analysis: `flutter analyze`
- Tests: `flutter test`
- Regenerate localizations after editing `lib/l10n/*.arb`: `flutter gen-l10n`
- Full check before committing: `flutter analyze && flutter test`

## Upgrade baseline

- Flutter SDK: 3.47.x (Impeller is the default renderer on Windows, Linux, and macOS)
- Dart SDK: 3.13.x
- Android compile/target SDK: Flutter-provided values (currently API 36)
- Android minimum SDK: Flutter-provided value (currently API 24)
- Android project toolchain: AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14
- Android Java compile target: Java 17 (the local machine currently runs Gradle with Java 21)
- iOS deployment target: iOS 15
- macOS deployment target: macOS 12
- Material widgets: `material_ui` 1.x

### Pending platform work

- Before adopting Xcode 27/iOS 27, migrate the custom UIKit entry point in `ios/Runner/AppDelegate.swift` to the UIScene lifecycle.
- Android CI or a development machine with Java 17 is required to validate `flutter build appbundle`; AGP 8.x with the installed Java 21 currently fails Android 36 JDK image transformation.
