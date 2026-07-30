import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global reference to the root [ProviderContainer], captured in `main()`.
///
/// Background isolates and headless method-channel handlers (e.g. the mobile
/// autofill bridge) have no [BuildContext] and therefore cannot reach Riverpod
/// via `ProviderScope.containerOf`. This top-level reference lets them read
/// providers such as `databaseServiceProvider` / `databaseProvider` directly.
///
/// Set once in `main()` before `runApp`.
late ProviderContainer globalContainer;
