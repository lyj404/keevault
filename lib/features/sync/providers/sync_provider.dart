import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sync_service.dart';

enum SyncState { idle, syncing, success, error }

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);
