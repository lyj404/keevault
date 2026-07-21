import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/core/services/external_url_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.keevault.keevault/external_url');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform opens valid URLs through the platform channel', () async {
      debugDefaultTargetPlatformOverride = platform;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });

      final opened = await ExternalUrlService.openUrl(
        Uri.parse('https://github.com/lyj404/keevault/releases/latest'),
      );

      expect(opened, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'openUrl');
      expect(calls.single.arguments, <String, dynamic>{
        'url': 'https://github.com/lyj404/keevault/releases/latest',
      });
    });
  }

  test('rejects URLs that are not HTTP or HTTPS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var channelCalled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      channelCalled = true;
      return true;
    });

    expect(
      await ExternalUrlService.openUrl(Uri.parse('file:///tmp/release')),
      isFalse,
    );
    expect(channelCalled, isFalse);
  });
}
