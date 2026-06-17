import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/utils/logger.dart';
import '../../backup/data/backup_service.dart';
import '../../sync/data/sync_service.dart';

class DatabaseService {
  final _backupService = BackupService();
  KdbxDatabase? _db;
  String? _filePath;
  String? _password;
  bool _dirty = false;
  Uint8List? _preloadedBytes;
  List<KdbxEntry>? _allEntriesCache;

  /// Last known remote file metadata, used for conflict detection.
  RemoteFileInfo? _lastSyncedRemoteInfo;
  RemoteFileInfo? get lastSyncedRemoteInfo => _lastSyncedRemoteInfo;
  void setLastSyncedRemoteInfo(RemoteFileInfo? info) => _lastSyncedRemoteInfo = info;

  KdbxDatabase? get db => _db;
  String? get filePath => _filePath;
  bool get isOpen => _db != null;
  bool get isDirty => _dirty;

  void markDirty() => _dirty = true;
  void markClean() => _dirty = false;

  /// All entries in a flat cached list. Rebuilt on open/create/mutation.
  List<KdbxEntry> get allEntries => _allEntriesCache ?? [];

  void _rebuildEntryCache() {
    _allEntriesCache = _db?.root.allEntries.toList();
  }

  void rebuildEntryCache() => _rebuildEntryCache();

  /// Preloads file bytes into memory so openFile doesn't block on I/O.
  Future<void> preloadFile(String filePath) async {
    log.i('Preloading file: $filePath');
    _preloadedBytes = await File(filePath).readAsBytes();
  }

  /// Loads a KDBX database in a background isolate to avoid blocking the UI.
  /// The isolate initializes its own crypto engine (FFI if available, pure Dart fallback).
  static Future<KdbxDatabase> _loadDatabase(Uint8List bytes, String password) async {
    return await Isolate.run(() {
      CryptoService.initialize();
      final credentials = KdbxCredentials(
        password: ProtectedData.fromString(password),
      );
      return KdbxDatabase.fromBytes(data: bytes, credentials: credentials);
    });
  }

  Future<KdbxDatabase> openFile(String filePath, String password) async {
    log.i('Opening database: $filePath');
    final bytes = _preloadedBytes ?? await File(filePath).readAsBytes();
    _preloadedBytes = null;
    _db = await _loadDatabase(bytes, password);
    _filePath = filePath;
    _password = password;
    _dirty = false;
    _localizeRecycleBin();
    _rebuildEntryCache();
    log.i('Database opened, entries: ${_allEntriesCache!.length}');
    return _db!;
  }

  Future<KdbxDatabase> createDatabase(String name, String password, String filePath) async {
    log.i('Creating database: $name -> $filePath');
    final credentials = KdbxCredentials(
      password: ProtectedData.fromString(password),
    );
    _db = KdbxDatabase.create(credentials: credentials, name: name);
    _filePath = filePath;
    _password = password;
    _dirty = true;
    _localizeRecycleBin();
    _rebuildEntryCache();
    await save();
    log.i('Database created successfully');
    return _db!;
  }

  Future<KdbxDatabase> reloadFromBytes(Uint8List bytes) async {
    if (_password == null) throw Exception('no_password_cannot_reload');
    _db = await _loadDatabase(bytes, _password!);
    _dirty = false;
    _localizeRecycleBin();
    _rebuildEntryCache();
    return _db!;
  }

  void _localizeRecycleBin() {
    if (_db == null) return;
    final rb = _db!.recycleBin;
    if (rb == null) return;
    final lang = ui.PlatformDispatcher.instance.locale.languageCode;
    if (lang == 'zh') {
      if (rb.name == 'Recycle Bin') rb.name = '回收站';
    } else {
      if (rb.name == '回收站') rb.name = 'Recycle Bin';
    }
  }

  /// Saves the database to disk and returns the serialized bytes.
  /// The serialization+encryption runs in a background isolate to avoid blocking the UI.
  /// Returns the serialized bytes so callers can reuse them (e.g. for cloud upload).
  Future<Uint8List> save() async {
    if (_db == null || _filePath == null) return Uint8List(0);
    log.i('Saving database: $_filePath');
    final db = _db!;
    final bytes = await Isolate.run(() => db.save());
    if (await _backupService.isAutoBackupEnabled()) {
      unawaited(_backupService.createBackup(_filePath!).catchError((e) {
        log.e('Auto-backup failed', error: e);
        return null;
      }));
    }
    await File(_filePath!).writeAsBytes(bytes);
    _dirty = false;
    log.i('Database saved (${bytes.length} bytes)');
    return Uint8List.fromList(bytes);
  }

  /// Serializes the database to bytes without writing to disk.
  /// Runs in a background isolate to avoid blocking the UI.
  Future<Uint8List> saveToBytes() async {
    if (_db == null) return Uint8List(0);
    final db = _db!;
    final bytes = await Isolate.run(() => db.save());
    return Uint8List.fromList(bytes);
  }

  Future<void> saveAs(String newPath) async {
    _filePath = newPath;
    await save();
  }

  KdbxGroup createGroup(KdbxGroup parent, String name) {
    final group = _db!.createGroup(parent: parent, name: name);
    _dirty = true;
    return group;
  }

  KdbxEntry createEntry(KdbxGroup parent) {
    final entry = _db!.createEntry(parent: parent);
    entry.times = KdbxTimes.fromTime();
    _dirty = true;
    _rebuildEntryCache();
    return entry;
  }

  void deleteItem(KdbxItem item) {
    _db!.remove(item);
    _dirty = true;
    _rebuildEntryCache();
  }

  /// Restores an item from the recycle bin to its previous parent group.
  /// Returns true if restored successfully, false if previous parent not found.
  bool restoreItem(KdbxItem item) {
    if (_db == null) return false;
    final prevUuid = item.previousParent;
    if (prevUuid == null) return false;
    final target = _db!.getGroup(uuid: prevUuid);
    if (target == null) return false;
    _db!.move(item: item, target: target);
    _dirty = true;
    _rebuildEntryCache();
    return true;
  }

  void moveItem(KdbxItem item, KdbxGroup target) {
    _db!.move(item: item, target: target);
    _dirty = true;
    _rebuildEntryCache();
  }

  List<KdbxEntry> search(String query) {
    if (_db == null || query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return allEntries.where((entry) {
      final title = entry.fields['Title']?.text ?? '';
      final username = entry.fields['UserName']?.text ?? '';
      final url = entry.fields['URL']?.text ?? '';
      final notes = entry.fields['Notes']?.text ?? '';
      return title.toLowerCase().contains(lowerQuery) ||
          username.toLowerCase().contains(lowerQuery) ||
          url.toLowerCase().contains(lowerQuery) ||
          notes.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  KdbxGroup? findGroupByPath(String path) {
    if (_db == null || path.isEmpty) return _db?.root;
    final segments = path.split('/');
    KdbxGroup? current = _db!.root;
    for (final segment in segments) {
      if (segment.isEmpty) continue;
      current = current?.groups.where((g) => g.name == segment).firstOrNull;
      if (current == null) return null;
    }
    return current;
  }

  String getGroupPath(KdbxGroup group) {
    final parts = <String>[];
    KdbxGroup? current = group;
    while (current != null && current != _db?.root) {
      parts.add(current.name);
      current = current.parent;
    }
    return parts.reversed.join('/');
  }

  /// Changes the master password of the currently open database.
  /// Throws [InvalidCredentialsError] if [oldPassword] is incorrect.
  /// Does NOT save to disk — caller should invoke save() afterwards.
  void changePassword(String oldPassword, String newPassword) {
    if (_db == null) throw Exception('database_not_open');
    if (_password != oldPassword) {
      throw const InvalidCredentialsError('invalid key');
    }
    _db!.header.credentials = KdbxCredentials(
      password: ProtectedData.fromString(newPassword),
    );
    _password = newPassword;
    _dirty = true;
    log.i('Master password changed');
  }

  void close() {
    log.i('Database closed: $_filePath');
    _db = null;
    _filePath = null;
    _password = null;
    _dirty = false;
    _lastSyncedRemoteInfo = null;
    _preloadedBytes = null;
    _allEntriesCache = null;
  }
}
