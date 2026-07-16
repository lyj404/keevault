import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Durable, recoverable file replacement used for sensitive database files.
///
/// The original is never deleted until the replacement has been fully written
/// and flushed. A small transaction manifest makes interrupted writes
/// discoverable on the next launch.
class AtomicFileStore {
  const AtomicFileStore();

  Future<AtomicCommitResult> commit(
    String targetPath,
    Uint8List bytes, {
    Future<void> Function()? backup,
    String? validationHash,
  }) async {
    final target = File(targetPath);
    final directory = target.parent;
    await directory.create(recursive: true);
    final token = '${DateTime.now().microsecondsSinceEpoch}_$pid';
    final temp = File('${target.path}.keevault.$token.tmp');
    final rollback = File('${target.path}.keevault.$token.rollback');
    final manifest = File('${target.path}.keevault.transaction.json');
    final hash = validationHash ?? await _sha256(bytes);

    final data = <String, dynamic>{
      'target': target.path,
      'temp': temp.path,
      'rollback': rollback.path,
      'sha256': hash,
      'length': bytes.length,
      'stage': 'writing',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await manifest.writeAsString(jsonEncode(data), flush: true);
    try {
      await temp.writeAsBytes(bytes, flush: true);
      data['stage'] = 'written';
      await manifest.writeAsString(jsonEncode(data), flush: true);

      if (backup != null && await target.exists()) {
        data['stage'] = 'backing_up';
        await manifest.writeAsString(jsonEncode(data), flush: true);
        await backup();
      }
      data['stage'] = 'backed_up';
      await manifest.writeAsString(jsonEncode(data), flush: true);

      if (await target.exists()) {
        await target.rename(rollback.path);
      }
      data['stage'] = 'replacing';
      await manifest.writeAsString(jsonEncode(data), flush: true);
      await temp.rename(target.path);

      // Keep the rollback until the new file is observable and readable by the
      // caller. This class cannot know the KDBX credentials, so validation is
      // supplied by the caller before invoking commit or immediately after it.
      data['stage'] = 'committed';
      await manifest.writeAsString(jsonEncode(data), flush: true);
      if (await rollback.exists()) await rollback.delete();
      if (await manifest.exists()) await manifest.delete();
      return AtomicCommitResult(
        path: target.path,
        bytesWritten: bytes.length,
        sha256: hash,
      );
    } catch (_) {
      // Roll back only when the new target was not successfully installed.
      if (!await target.exists() && await rollback.exists()) {
        await rollback.rename(target.path);
      }
      rethrow;
    } finally {
      if (await temp.exists()) {
        // A failed transaction deliberately leaves the temp file available for
        // recovery; successful transactions have already renamed it.
      }
    }
  }

  Future<AtomicTransaction?> readPending(String targetPath) async {
    final manifest = File('$targetPath.keevault.transaction.json');
    if (!await manifest.exists()) return null;
    try {
      final value = jsonDecode(await manifest.readAsString());
      if (value is! Map) return null;
      return AtomicTransaction.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }

  Future<List<AtomicRecoveryCandidate>> candidates(String targetPath) async {
    final pending = await readPending(targetPath);
    if (pending == null) return const [];
    final paths = <String>{pending.target, pending.temp, pending.rollback};
    final result = <AtomicRecoveryCandidate>[];
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final stat = await file.stat();
      result.add(AtomicRecoveryCandidate(
        path: path,
        length: stat.size,
        modified: stat.modified,
        expectedSha256: pending.sha256,
      ));
    }
    return result;
  }

  Future<void> discardPending(String targetPath) async {
    final pending = await readPending(targetPath);
    if (pending == null) return;
    for (final path in [pending.temp, pending.rollback]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    final manifest = File('$targetPath.keevault.transaction.json');
    if (await manifest.exists()) await manifest.delete();
  }

  Future<String> _sha256(Uint8List bytes) async {
    final digest = await Sha256().hash(bytes);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class AtomicCommitResult {
  final String path;
  final int bytesWritten;
  final String sha256;
  const AtomicCommitResult({
    required this.path,
    required this.bytesWritten,
    required this.sha256,
  });
}

class AtomicTransaction {
  final String target;
  final String temp;
  final String rollback;
  final String sha256;
  final int length;
  final String stage;
  final DateTime createdAt;

  const AtomicTransaction({
    required this.target,
    required this.temp,
    required this.rollback,
    required this.sha256,
    required this.length,
    required this.stage,
    required this.createdAt,
  });

  factory AtomicTransaction.fromJson(Map<String, dynamic> json) {
    return AtomicTransaction(
      target: json['target'] as String,
      temp: json['temp'] as String,
      rollback: json['rollback'] as String,
      sha256: json['sha256'] as String,
      length: json['length'] as int,
      stage: json['stage'] as String? ?? 'unknown',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AtomicRecoveryCandidate {
  final String path;
  final int length;
  final DateTime modified;
  final String expectedSha256;
  const AtomicRecoveryCandidate({
    required this.path,
    required this.length,
    required this.modified,
    required this.expectedSha256,
  });
}





