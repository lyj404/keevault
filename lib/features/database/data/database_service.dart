import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kpasslib/kpasslib.dart';

class DatabaseService {
  KdbxDatabase? _db;
  String? _filePath;
  bool _dirty = false;

  KdbxDatabase? get db => _db;
  String? get filePath => _filePath;
  bool get isOpen => _db != null;
  bool get isDirty => _dirty;

  void markDirty() => _dirty = true;
  void markClean() => _dirty = false;

  Future<KdbxDatabase> openFile(String filePath, String password) async {
    final bytes = await File(filePath).readAsBytes();
    final credentials = KdbxCredentials(
      password: ProtectedData.fromString(password),
    );
    _db = await KdbxDatabase.fromBytes(data: bytes, credentials: credentials);
    _filePath = filePath;
    _dirty = false;
    _localizeRecycleBin();
    return _db!;
  }

  Future<KdbxDatabase> createDatabase(String name, String password, String filePath) async {
    final credentials = KdbxCredentials(
      password: ProtectedData.fromString(password),
    );
    _db = KdbxDatabase.create(credentials: credentials, name: name);
    _filePath = filePath;
    _dirty = true;
    _localizeRecycleBin();
    await save();
    return _db!;
  }

  /// 将回收站重命名为中文
  void _localizeRecycleBin() {
    if (_db == null) return;
    final rb = _db!.recycleBin;
    if (rb != null && rb.name == 'Recycle Bin') {
      rb.name = '回收站';
    }
  }

  Future<void> save() async {
    if (_db == null || _filePath == null) return;
    final bytes = await _db!.save();
    if (kIsWeb) {
      // Web: handled by caller via download
    } else {
      await File(_filePath!).writeAsBytes(bytes);
    }
    _dirty = false;
  }

  Future<Uint8List> saveToBytes() async {
    if (_db == null) return Uint8List(0);
    final bytes = await _db!.save();
    _dirty = false;
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
    _dirty = true;
    return entry;
  }

  void deleteItem(KdbxItem item) {
    _db!.remove(item);
    _dirty = true;
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
    return true;
  }

  void moveItem(KdbxItem item, KdbxGroup target) {
    _db!.move(item: item, target: target);
    _dirty = true;
  }

  List<KdbxEntry> search(String query) {
    if (_db == null || query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _db!.root.allEntries.where((entry) {
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

  void close() {
    _db = null;
    _filePath = null;
    _dirty = false;
  }
}
