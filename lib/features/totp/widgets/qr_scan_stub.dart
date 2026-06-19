import 'package:flutter/material.dart';

// Stub for platforms without camera support (Linux, Windows, Web)
class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<String?> openQrScanner(BuildContext context) async => null;
