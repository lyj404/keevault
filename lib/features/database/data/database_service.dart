import 'dart:async';
import 'dart:io';
import 'dart:isolate';
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
  Uint8List? _keyData;
  bool _dirty = false;
  Uint8List? _preloadedBytes;
  String? _preloadedFilePath;
  List<KdbxEntry>? _allEntriesCache;
  Uint8List? _lastSavedBytes;

  /// Last known remote file metadata, used for conflict detection.
  RemoteFileInfo? _lastSyncedRemoteInfo;
  RemoteFileInfo? get lastSyncedRemoteInfo => _lastSyncedRemoteInfo;
  void setLastSyncedRemoteInfo(RemoteFileInfo? info) => _lastSyncedRemoteInfo = info;

  KdbxDatabase? get db => _db;
  String? get filePath => _filePath;
  bool get isOpen => _db != null;
  bool get isDirty => _dirty;
  bool get hasKeyFile => _keyData != null;

  /// Callback invoked when dirty state changes.
  void Function(bool isDirty)? onDirtyChanged;

  void markDirty() {
    _dirty = true;
    onDirtyChanged?.call(true);
  }
  void markClean() {
    _dirty = false;
    onDirtyChanged?.call(false);
  }

  /// All entries in a flat cached list. Rebuilt on open/create/mutation.
  List<KdbxEntry> get allEntries => _allEntriesCache ?? [];

  void _rebuildEntryCache() {
    _allEntriesCache = _db?.root.allEntries.toList();
  }

  void rebuildEntryCache() => _rebuildEntryCache();

  /// Preloads file bytes into memory so openFile doesn't block on I/O.
  Future<void> preloadFile(String filePath) async {
    // Skip if already preloaded the same file
    if (_preloadedBytes != null && _preloadedFilePath == filePath) {
      log.i('File already preloaded: $filePath');
      return;
    }
    log.i('Preloading file: $filePath');
    _preloadedBytes = await File(filePath).readAsBytes();
    _preloadedFilePath = filePath;
  }

  /// Loads a KDBX database in a background isolate to avoid blocking the UI.
  /// The isolate initializes its own crypto engine (FFI if available, pure Dart fallback).
  static Future<KdbxDatabase> _loadDatabase(Uint8List bytes, String password, {Uint8List? keyData}) async {
    return await Isolate.run(() {
      CryptoService.initialize();
      final credentials = KdbxCredentials(
        password: ProtectedData.fromString(password),
        keyData: keyData,
      );
      return KdbxDatabase.fromBytes(data: bytes, credentials: credentials);
    });
  }

  Future<KdbxDatabase> openFile(String filePath, String password, {Uint8List? keyData}) async {
    log.i('Opening database: $filePath');
    final bytes = _preloadedBytes ?? await File(filePath).readAsBytes();
    _preloadedBytes = null;
    _preloadedFilePath = null;
    _db = await _loadDatabase(bytes, password, keyData: keyData);
    _filePath = filePath;
    _password = password;
    _keyData = keyData;
    markClean();
    _localizeRecycleBin();
    _rebuildEntryCache();
    log.i('Database opened, entries: ${_allEntriesCache!.length}');
    return _db!;
  }

  Future<KdbxDatabase> createDatabase(String name, String password, String filePath, {Uint8List? keyData}) async {
    log.i('Creating database: $name -> $filePath');
    final credentials = KdbxCredentials(
      password: ProtectedData.fromString(password),
      keyData: keyData,
    );
    _db = KdbxDatabase.create(credentials: credentials, name: name);
    _filePath = filePath;
    _password = password;
    _keyData = keyData;
    markDirty();
    _localizeRecycleBin();
    _rebuildEntryCache();
    await save();
    log.i('Database created successfully');
    return _db!;
  }

  Future<KdbxDatabase> reloadFromBytes(Uint8List bytes, {String? password}) async {
    final pw = password ?? _password;
    if (pw == null) throw Exception('no_password_cannot_reload');
    _db = await _loadDatabase(bytes, pw, keyData: _keyData);
    _password = pw;
    markClean();
    _localizeRecycleBin();
    _rebuildEntryCache();
    return _db!;
  }

  void _localizeRecycleBin() {
    // Intentionally no-op: localizing the recycle bin name on every open
    // causes unnecessary dirty state and sync conflicts for bilingual users.
  }

  /// Saves the database to disk and returns the serialized bytes.
  /// The serialization+encryption runs in a background isolate to avoid blocking the UI.
  /// Returns the serialized bytes so callers can reuse them (e.g. for cloud upload).
  Future<Uint8List> save() async {
    if (_db == null || _filePath == null) return Uint8List(0);
    log.i('Saving database: $_filePath');
    final db = _db!;
    final bytes = await Isolate.run(() {
      CryptoService.initialize();
      return db.save();
    });
    if (await _backupService.isAutoBackupEnabled()) {
      unawaited(_backupService.createBackup(_filePath!).catchError((e) {
        log.e('Auto-backup failed', error: e);
        return null;
      }));
    }
    await File(_filePath!).writeAsBytes(bytes);
    _lastSavedBytes = Uint8List.fromList(bytes);
    markClean();
    log.i('Database saved (${bytes.length} bytes)');
    return Uint8List.fromList(bytes);
  }

  /// Returns true if the given bytes are identical to the last saved bytes.
  bool isSameAsLastSaved(Uint8List bytes) {
    if (_lastSavedBytes == null) return false;
    if (_lastSavedBytes!.length != bytes.length) return false;
    for (int i = 0; i < bytes.length; i++) {
      if (_lastSavedBytes![i] != bytes[i]) return false;
    }
    return true;
  }

  /// Serializes the database to bytes without writing to disk.
  /// Runs in a background isolate to avoid blocking the UI.
  Future<Uint8List> saveToBytes() async {
    if (_db == null) return Uint8List(0);
    final db = _db!;
    final bytes = await Isolate.run(() {
      CryptoService.initialize();
      return db.save();
    });
    return Uint8List.fromList(bytes);
  }

  Future<void> saveAs(String newPath) async {
    _filePath = newPath;
    await save();
  }

  KdbxGroup createGroup(KdbxGroup parent, String name) {
    final group = _db!.createGroup(parent: parent, name: name);
    markDirty();
    return group;
  }

  KdbxEntry createEntry(KdbxGroup parent) {
    final entry = _db!.createEntry(parent: parent);
    entry.times = KdbxTimes.fromTime();
    markDirty();
    _rebuildEntryCache();
    return entry;
  }

  void deleteItem(KdbxItem item) {
    _db!.remove(item);
    markDirty();
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
    markDirty();
    _rebuildEntryCache();
    return true;
  }

  void moveItem(KdbxItem item, KdbxGroup target) {
    _db!.move(item: item, target: target);
    markDirty();
    _rebuildEntryCache();
  }

  KdbxEntry? findEntryByUuid(KdbxUuid uuid) {
    if (_db == null) return null;
    for (final entry in allEntries) {
      if (entry.uuid == uuid) return entry;
    }
    return null;
  }

  List<KdbxEntry> search(String query) {
    if (_db == null || query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return allEntries.where((entry) {
      final title = entry.fields['Title']?.text ?? '';
      final username = entry.fields['UserName']?.text ?? '';
      final url = entry.fields['URL']?.text ?? '';
      final notes = entry.fields['Notes']?.text ?? '';
      final customMatch = entry.fields.entries
          .where((e) => !['Title', 'UserName', 'Password', 'URL', 'Notes'].contains(e.key))
          .any((e) => e.value.text.toLowerCase().contains(lowerQuery));
      return title.toLowerCase().contains(lowerQuery) ||
          username.toLowerCase().contains(lowerQuery) ||
          url.toLowerCase().contains(lowerQuery) ||
          notes.toLowerCase().contains(lowerQuery) ||
          customMatch;
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
  /// If [updateKeyFile] is true, [newKeyData] will be used (null means remove key file).
  /// If [updateKeyFile] is false, the existing key file is preserved.
  void changePassword(String oldPassword, String newPassword, {bool updateKeyFile = false, Uint8List? newKeyData}) {
    if (_db == null) throw Exception('database_not_open');
    if (_password != oldPassword) {
      throw const InvalidCredentialsError('invalid key');
    }
    final keyData = updateKeyFile ? newKeyData : _keyData;
    _db!.header.credentials = KdbxCredentials(
      password: ProtectedData.fromString(newPassword),
      keyData: keyData,
    );
    _password = newPassword;
    _keyData = keyData;
    markDirty();
    log.i('Master password changed');
  }

  void close() {
    log.i('Database closed: $_filePath');
    _db = null;
    _filePath = null;
    _password = null;
    _keyData = null;
    markClean();
    _lastSyncedRemoteInfo = null;
    _preloadedBytes = null;
    _allEntriesCache = null;
  }
}
