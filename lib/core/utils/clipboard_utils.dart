import 'dart:async';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import 'fnv_hash.dart';

Timer? _clipboardTimer;
String? _lastCopiedHash;

void copyToClipboardWithAutoClear(
  String text, {
  Duration timeout = AppConstants.clipboardClearTimeout,
}) {
  _clipboardTimer?.cancel();
  Clipboard.setData(ClipboardData(text: text));
  // Hold only a hash of the copied value so the plaintext isn't retained
  // in the timer closure for the whole timeout window.
  final copiedHash = FnvHash.hashString(text);
  _lastCopiedHash = copiedHash;
  if (timeout.inSeconds > 0) {
    _clipboardTimer = Timer(timeout, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      final currentText = current?.text;
      if (currentText != null &&
          FnvHash.hashString(currentText) == copiedHash) {
        Clipboard.setData(const ClipboardData(text: ''));
        _lastCopiedHash = null;
      }
    });
  }
}

/// Clears the clipboard on app exit if it still holds a value we copied.
Future<void> clearClipboardIfCopied() async {
  _clipboardTimer?.cancel();
  final lastHash = _lastCopiedHash;
  if (lastHash == null) return;
  try {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    final currentText = current?.text;
    if (currentText != null && FnvHash.hashString(currentText) == lastHash) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  } catch (_) {}
  _lastCopiedHash = null;
}
