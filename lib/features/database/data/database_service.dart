import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/utils/logger.dart';
import '../../backup/data/backup_service.dart';
import '../../../core/utils/fuzzy_match.dart';
import '../../sync/data/sync_service.dart';

/// Thrown when a KDBX file cannot be parsed due to corruption or bad format.
class DatabaseCorruptedException implements Exception {
  final Object original;
  DatabaseCorruptedException(this.original);

  @override
  String toString() => 'DatabaseCorruptedException: $original';
}

/// Returns true if the exception indicates a corrupt/invalid KDBX file.
bool isCorruptionError(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('corrupt') ||
      msg.contains('bad version') ||
      msg.contains('invalid header') ||
      msg.contains('dataerror') ||
      msg.contains('format') && msg.contains('invalid') ||
      (e is InvalidCredentialsError == false &&
          msg.contains('invalid') &&
          msg.contains('key'));
}

/// Pre-computed lowercase text for an entry, used for fast search.

/// A search result with relevance score and match positions for highlighting.
class SearchResult {
  final KdbxEntry entry;
  final double score;
  final List<int> matchPositions;
  const SearchResult(this.entry, this.score, this.matchPositions);
}

class SyncAuditChange {
  final String type;
  final String title;
  final String? groupPath;
  final String? modifiedAt;
  final List<String> details;
  final Map<String, String> localValues;
  final Map<String, String> remoteValues;

  const SyncAuditChange({
    required this.type,
    required this.title,
    this.groupPath,
    this.modifiedAt,
    this.details = const [],
    this.localValues = const {},
    this.remoteValues = const {},
  });
}

class SyncAuditReport {
  final List<SyncAuditChange> localOnly;
  final List<SyncAuditChange> remoteOnly;
  final List<SyncAuditChange> modifiedBoth;

  const SyncAuditReport({
    required this.localOnly,
    required this.remoteOnly,
    required this.modifiedBoth,
  });

  bool get hasChanges =>
      localOnly.isNotEmpty || remoteOnly.isNotEmpty || modifiedBoth.isNotEmpty;
}

class _SearchRecord {
  final KdbxEntry entry;
  final String title;
  final String username;
  final String url;
  final String notes;
  final List<String> customFields;
  final List<String> tags;

  _SearchRecord(this.entry)
    : title = (entry.fields['Title']?.text ?? '').toLowerCase(),
      username = (entry.fields['UserName']?.text ?? '').toLowerCase(),
      url = (entry.fields['URL']?.text ?? '').toLowerCase(),
      notes = (entry.fields['Notes']?.text ?? '').toLowerCase(),
      customFields = entry.fields.entries
          .where(
            (e) => ![
              'Title',
              'UserName',
              'Password',
              'URL',
              'Notes',
            ].contains(e.key),
          )
          .map((e) => e.value.text.toLowerCase())
          .toList(),
      tags = (entry.tags ?? []).map((t) => t.toLowerCase()).toList();

  /// Returns the best fuzzy match score across all fields, or null if no match.
  FuzzyMatchResult? matchScore(String query) {
    final lowerQuery = query.toLowerCase();
    FuzzyMatchResult? best;

    void consider(String text) {
      final r = fuzzyMatch(text, lowerQuery);
      if (r != null && r.isMatch) {
        if (best == null || r.score > best!.score) best = r;
      }
    }

    // Primary fields
    consider(title);
    consider(username);
    consider(url);
    consider(notes);
    // Custom fields & tags
    for (final f in customFields) {
      consider(f);
    }
    for (final t in tags) {
      consider(t);
    }

    return best;
  }
}

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
  List<_SearchRecord>? _searchIndex;
  Uint8List? _lastSavedBytes;
  int? _lastSavedHash;

  /// Last known remote file metadata, used for conflict detection.
  RemoteFileInfo? _lastSyncedRemoteInfo;
  RemoteFileInfo? get lastSyncedRemoteInfo => _lastSyncedRemoteInfo;
  void setLastSyncedRemoteInfo(RemoteFileInfo? info) =>
      _lastSyncedRemoteInfo = info;

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
    log.d(
      '[DatabaseService] _rebuildEntryCache count=${_allEntriesCache?.length}',
    );
    _rebuildSearchIndex();
  }

  void _rebuildSearchIndex() {
    final entries = _allEntriesCache;
    if (entries == null) {
      _searchIndex = null;
      return;
    }
    _searchIndex = entries.map((e) => _SearchRecord(e)).toList();
  }

  void rebuildEntryCache() => _rebuildEntryCache();

  /// Preloads file bytes into memory so openFile doesn't block on I/O.
  /// Runs in a background isolate to avoid blocking the UI.
  Future<void> preloadFile(String filePath) async {
    // Skip if already preloaded the same file
    if (_preloadedBytes != null && _preloadedFilePath == filePath) {
      log.i('File already preloaded: $filePath');
      return;
    }
    log.i('Preloading file: $filePath');
    _preloadedBytes = await Isolate.run(() => File(filePath).readAsBytes());
    _preloadedFilePath = filePath;
  }

  /// Loads a KDBX database in a background isolate to avoid blocking the UI.
  /// The isolate initializes its own crypto engine (FFI if available, pure Dart fallback).
  static Future<KdbxDatabase> _loadDatabase(
    Uint8List bytes,
    String password, {
    Uint8List? keyData,
  }) async {
    return await Isolate.run(() {
      CryptoService.initialize();
      final credentials = KdbxCredentials(
        password: ProtectedData.fromString(password),
        keyData: keyData,
      );
      return KdbxDatabase.fromBytes(data: bytes, credentials: credentials);
    });
  }

  Future<KdbxDatabase> openFile(
    String filePath,
    String password, {
    Uint8List? keyData,
  }) async {
    log.i('Opening database: $filePath');
    final bytes = _preloadedBytes ?? await File(filePath).readAsBytes();
    _preloadedBytes = null;
    _preloadedFilePath = null;
    try {
      _db = await _loadDatabase(bytes, password, keyData: keyData);
    } catch (e) {
      if (isCorruptionError(e)) {
        log.e('Database file corrupted: $filePath', error: e);
        throw DatabaseCorruptedException(e);
      }
      rethrow;
    }
    _filePath = filePath;
    _password = password;
    _keyData = keyData;
    markClean();
    _localizeRecycleBin();
    _rebuildEntryCache();
    log.i('Database opened, entries: ${_allEntriesCache!.length}');
    return _db!;
  }

  Future<KdbxDatabase> createDatabase(
    String name,
    String password,
    String filePath, {
    Uint8List? keyData,
  }) async {
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

  Future<KdbxDatabase> reloadFromBytes(
    Uint8List bytes, {
    String? password,
  }) async {
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
    final bytes = Uint8List.fromList(
      await Isolate.run(() {
        CryptoService.initialize();
        return db.save();
      }),
    );
    if (await _backupService.isAutoBackupEnabled()) {
      unawaited(
        _backupService.createBackup(_filePath!).catchError((e) {
          log.e('Auto-backup failed', error: e);
          return null;
        }),
      );
    }
    await File(_filePath!).writeAsBytes(bytes);
    _lastSavedBytes = bytes;
    _lastSavedHash = _computeBytesHash(bytes);
    markClean();
    log.i('Database saved (${bytes.length} bytes)');
    return bytes;
  }

  /// FNV-1a 64-bit hash for fast byte comparison.
  static int _computeBytesHash(Uint8List bytes) {
    int hash = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    for (int i = 0; i < bytes.length; i++) {
      hash ^= bytes[i];
      hash = (hash * prime) & 0x7FFFFFFFFFFFFFFF;
    }
    return hash;
  }

  /// Returns true if the given bytes are identical to the last saved bytes.
  /// Uses hash comparison for O(1) lookup with length pre-check (Bug #6 fix).
  bool isSameAsLastSaved(Uint8List bytes) {
    if (_lastSavedBytes == null) return false;
    if (_lastSavedBytes!.length != bytes.length) return false;
    return _computeBytesHash(bytes) == _lastSavedHash;
  }

  /// Serializes the database to bytes without writing to disk.
  /// Runs in a background isolate to avoid blocking the UI.
  Future<Uint8List> saveToBytes() async {
    if (_db == null) return Uint8List(0);
    final db = _db!;
    final bytes = Uint8List.fromList(
      await Isolate.run(() {
        CryptoService.initialize();
        return db.save();
      }),
    );
    return bytes;
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
    log.w(
      '[DatabaseService] findEntryByUuid MISS uuid=${uuid.string} cacheSize=${allEntries.length}',
    );
    return null;
  }

  List<SearchResult> search(String query) {
    if (_db == null || query.isEmpty) return [];
    final index = _searchIndex;
    if (index == null) return [];
    final results = <SearchResult>[];
    for (final record in index) {
      final match = record.matchScore(query);
      if (match != null && match.isMatch) {
        results.add(SearchResult(record.entry, match.score, match.positions));
      }
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  KdbxGroup? findGroupByPath(String path) {
    if (_db == null || path.isEmpty) return _db?.root;
    final segments = path.split('/');
    KdbxGroup? current = _db!.root;
    for (final segment in segments) {
      if (segment.isEmpty) continue;
      current = current?.groups.where((g) => g.name == segment).firstOrNull;
      if (current == null) {
        log.w(
          '[DatabaseService] findGroupByPath MISS path="$path" failed at segment="$segment"',
        );
        return null;
      }
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

  SyncAuditReport buildSyncAuditReport(KdbxDatabase remoteDb) {
    final localMap = {for (final entry in allEntries) entry.uuid.string: entry};
    final remoteEntries = remoteDb.root.allEntries.toList();
    final remoteMap = {
      for (final entry in remoteEntries) entry.uuid.string: entry,
    };

    final localOnly = <SyncAuditChange>[];
    final remoteOnly = <SyncAuditChange>[];
    final modifiedBoth = <SyncAuditChange>[];

    for (final entry in allEntries) {
      final remoteEntry = remoteMap[entry.uuid.string];
      if (remoteEntry == null) {
        localOnly.add(_buildChange('local_only', entry));
        continue;
      }
      final diff = _entryDiffDetails(entry, remoteEntry);
      final details = diff.details;
      if (details.isNotEmpty) {
        modifiedBoth.add(
          _buildChange(
            'modified_both',
            entry,
            details: details,
            localValues: diff.localValues,
            remoteValues: diff.remoteValues,
          ),
        );
      }
    }

    for (final entry in remoteEntries) {
      if (!localMap.containsKey(entry.uuid.string)) {
        remoteOnly.add(_buildChange('remote_only', entry));
      }
    }

    return SyncAuditReport(
      localOnly: localOnly,
      remoteOnly: remoteOnly,
      modifiedBoth: modifiedBoth,
    );
  }

  Future<SyncAuditReport> buildSyncAuditReportFromBytes(
    Uint8List remoteBytes,
  ) async {
    if (_db == null || _password == null) {
      throw Exception('database_not_open');
    }
    final remoteDb = await _loadDatabase(
      remoteBytes,
      _password!,
      keyData: _keyData,
    );
    return buildSyncAuditReport(remoteDb);
  }

  SyncAuditChange _buildChange(
    String type,
    KdbxEntry entry, {
    List<String> details = const [],
    Map<String, String> localValues = const {},
    Map<String, String> remoteValues = const {},
  }) {
    final title = entry.fields['Title']?.text ?? '(Untitled)';
    final groupPath = entry.parent != null ? getGroupPath(entry.parent!) : '';
    final modifiedAt = entry.times.modification.time?.toIso8601String();
    return SyncAuditChange(
      type: type,
      title: title,
      groupPath: groupPath,
      modifiedAt: modifiedAt,
      details: details,
      localValues: localValues,
      remoteValues: remoteValues,
    );
  }

  ({
    List<String> details,
    Map<String, String> localValues,
    Map<String, String> remoteValues,
  })
  _entryDiffDetails(KdbxEntry local, KdbxEntry remote) {
    final details = <String>[];
    final localValues = <String, String>{};
    final remoteValues = <String, String>{};
    final keys = <String>{...local.fields.keys, ...remote.fields.keys}.toList()
      ..sort();
    for (final key in keys) {
      final localValue = local.fields[key]?.text ?? '';
      final remoteValue = remote.fields[key]?.text ?? '';
      if (localValue != remoteValue) {
        details.add('Field:$key');
        localValues[key] = localValue;
        remoteValues[key] = remoteValue;
      }
    }

    final localTags = (local.tags ?? []).toSet();
    final remoteTags = (remote.tags ?? []).toSet();
    if (localTags.length != remoteTags.length ||
        !localTags.containsAll(remoteTags)) {
      details.add('Tags');
      localValues['Tags'] = localTags.join(', ');
      remoteValues['Tags'] = remoteTags.join(', ');
    }

    final localAttachments = local.binaries.keys.toSet();
    final remoteAttachments = remote.binaries.keys.toSet();
    if (localAttachments.length != remoteAttachments.length ||
        !localAttachments.containsAll(remoteAttachments)) {
      details.add('Attachments');
      localValues['Attachments'] = localAttachments.join(', ');
      remoteValues['Attachments'] = remoteAttachments.join(', ');
    }

    if (local.history.length != remote.history.length) {
      details.add('History');
      localValues['History'] = '${local.history.length}';
      remoteValues['History'] = '${remote.history.length}';
    }

    final localModified = local.times.modification.time;
    final remoteModified = remote.times.modification.time;
    if (localModified != remoteModified) {
      details.add('ModifiedTime');
      localValues['ModifiedTime'] = localModified?.toIso8601String() ?? '';
      remoteValues['ModifiedTime'] = remoteModified?.toIso8601String() ?? '';
    }

    return (
      details: details,
      localValues: localValues,
      remoteValues: remoteValues,
    );
  }

  /// Changes the master password of the currently open database.
  /// Throws [InvalidCredentialsError] if [oldPassword] is incorrect.
  /// Does NOT save to disk — caller should invoke save() afterwards.
  /// If [updateKeyFile] is true, [newKeyData] will be used (null means remove key file).
  /// If [updateKeyFile] is false, the existing key file is preserved.
  void changePassword(
    String oldPassword,
    String newPassword, {
    bool updateKeyFile = false,
    Uint8List? newKeyData,
  }) {
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
    _searchIndex = null;
  }
}
