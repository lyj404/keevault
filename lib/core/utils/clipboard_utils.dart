import 'dart:async';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

Timer? _clipboardTimer;

void copyToClipboardWithAutoClear(
  String text, {
  Duration timeout = AppConstants.clipboardClearTimeout,
}) {
  _clipboardTimer?.cancel();
  Clipboard.setData(ClipboardData(text: text));
  if (timeout.inSeconds > 0) {
    _clipboardTimer = Timer(timeout, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == text) {
        Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
}
