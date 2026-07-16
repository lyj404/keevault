import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final package = File('PKGBUILD').readAsStringSync();
  final srcInfo = File('.SRCINFO').readAsStringSync();
  final pubspecMatch = RegExp(
    r'^version:\s*([^+\s]+)',
    multiLine: true,
  ).firstMatch(pubspec);
  final packageMatch = RegExp(
    r'^pkgver=(\S+)',
    multiLine: true,
  ).firstMatch(package);
  final srcInfoMatch = RegExp(
    r'^\s*pkgver = (\S+)',
    multiLine: true,
  ).firstMatch(srcInfo);
  final versions = {
    'pubspec.yaml': pubspecMatch?.group(1),
    'PKGBUILD': packageMatch?.group(1),
    '.SRCINFO': srcInfoMatch?.group(1),
  };
  if (versions.values.any((value) => value == null) ||
      versions.values.toSet().length != 1) {
    stderr.writeln('Version mismatch: $versions');
    exitCode = 1;
    return;
  }
  stdout.writeln('Version consistency OK: ${versions.values.first}');
}
