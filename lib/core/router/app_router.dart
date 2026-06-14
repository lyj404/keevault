import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/database/screens/welcome_screen.dart';
import '../../features/database/screens/unlock_screen.dart';
import '../../features/database/screens/create_database_screen.dart';
import '../../features/explorer/screens/explorer_screen.dart';
import '../../features/entry/screens/entry_detail_screen.dart';
import '../../features/entry/screens/entry_edit_screen.dart';
import '../../features/group/screens/group_edit_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/backup/screens/backup_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/unlock',
      builder: (context, state) {
        final filePath = state.uri.queryParameters['path'] ?? '';
        final isCloud = state.uri.queryParameters['cloud'] == 'true';
        final syncedETag = state.uri.queryParameters['etag'];
        return UnlockScreen(filePath: filePath, isCloud: isCloud, syncedETag: syncedETag);
      },
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const CreateDatabaseScreen(),
    ),
    GoRoute(
      path: '/explorer',
      builder: (context, state) => const ExplorerScreen(),
    ),
    GoRoute(
      path: '/entry/detail',
      builder: (context, state) {
        final entryIndex = int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0;
        final groupPath = state.uri.queryParameters['groupPath'] ?? '';
        return EntryDetailScreen(entryIndex: entryIndex, groupPath: groupPath);
      },
    ),
    GoRoute(
      path: '/entry/edit',
      builder: (context, state) {
        final entryIndex = state.uri.queryParameters['index'];
        final groupPath = state.uri.queryParameters['groupPath'] ?? '';
        return EntryEditScreen(
          entryIndex: entryIndex != null ? int.tryParse(entryIndex) : null,
          groupPath: groupPath,
        );
      },
    ),
    GoRoute(
      path: '/group/edit',
      builder: (context, state) {
        final groupPath = state.uri.queryParameters['groupPath'] ?? '';
        return GroupEditScreen(groupPath: groupPath);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/backup',
      builder: (context, state) => const BackupScreen(),
    ),
  ],
);
