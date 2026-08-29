import 'dart:async';

import 'package:flutter/foundation.dart';

/// Single shared 1-second ticker for every visible TOTP widget, so N tiles
/// don't each own their own [Timer.periodic]. The timer runs only while at
/// least one listener is attached.
class TotpTicker extends ChangeNotifier {
  TotpTicker._();

  static final TotpTicker instance = TotpTicker._();

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }
}
