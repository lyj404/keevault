import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens an external HTTP(S) URL using the platform's default handler.
class ExternalUrlService {
  ExternalUrlService._();

  static const _channel = MethodChannel('com.keevault.keevault/external_url');

  static Future<bool> openUrl(Uri uri) async {
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return false;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        return await _channel.invokeMethod<bool>('openUrl', <String, dynamic>{
              'url': uri.toString(),
            }) ??
            false;
      }

      if (defaultTargetPlatform == TargetPlatform.linux) {
        final result = await Process.run('xdg-open', [uri.toString()]);
        return result.exitCode == 0;
      }
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await Process.run('open', [uri.toString()]);
        return result.exitCode == 0;
      }
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final result = await Process.run('cmd', [
          '/c',
          'start',
          '',
          uri.toString(),
        ]);
        return result.exitCode == 0;
      }
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on ProcessException {
      return false;
    }

    return false;
  }
}
