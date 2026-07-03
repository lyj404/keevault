import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:win32/win32.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isLinux) {
      await _plugin.initialize(
        const InitializationSettings(
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
      );
    } else if (Platform.isAndroid) {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isMacOS) {
      await _plugin.initialize(
        const InitializationSettings(
          macOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
    }

    _initialized = true;
  }

  Future<void> showExpiryNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    if (Platform.isWindows) {
      _showWindowsBalloon(title, body);
      return;
    }

    if (Platform.isLinux) {
      await _showLinuxNotification(title, body);
      return;
    }

    if (Platform.isAndroid || Platform.isMacOS) {
      await _plugin.show(
        0,
        title,
        body,
        NotificationDetails(
          android: Platform.isAndroid
              ? const AndroidNotificationDetails(
                  'expiry_reminder',
                  'Password Expiry Reminders',
                  channelDescription:
                      'Notifications for passwords that are about to expire',
                  importance: Importance.high,
                  priority: Priority.high,
                )
              : null,
          macOS: Platform.isMacOS
              ? const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: false,
                  presentSound: false,
                )
              : null,
        ),
      );
      return;
    }
  }

  /// Windows: Shell_NotifyIcon
  void _showWindowsBalloon(String title, String body) {
    final hInstance = GetModuleHandle(nullptr);
    const className = 'KeeVaultNotifyWnd';
    final classNamePtr = className.toNativeUtf16();
    final windowTitlePtr = 'KeeVault Notify'.toNativeUtf16();
    final wc = calloc<WNDCLASS>();
    Pointer<NOTIFYICONDATA>? nid;
    int hWnd = 0;

    try {
      wc.ref.lpfnWndProc = Pointer.fromFunction(NotificationService._defWindowProc, 0);
      wc.ref.hInstance = hInstance;
      wc.ref.lpszClassName = classNamePtr;
      RegisterClass(wc);

      hWnd = CreateWindowEx(
        0,
        classNamePtr,
        windowTitlePtr,
        0,
        0, 0, 0, 0,
        HWND_MESSAGE,
        0,
        hInstance,
        nullptr,
      );

      if (hWnd == 0) return;

      nid = calloc<NOTIFYICONDATA>();
      nid.ref.cbSize = sizeOf<NOTIFYICONDATA>();
      nid.ref.hWnd = hWnd;
      nid.ref.uID = 1;
      nid.ref.uFlags = NIF_INFO;
      nid.ref.dwInfoFlags = NIIF_INFO;
      nid.ref.Anonymous.uTimeout = 10000;
      nid.ref.szInfoTitle = title;
      nid.ref.szInfo = body;

      Shell_NotifyIcon(NIM_ADD, nid);
      Shell_NotifyIcon(NIM_DELETE, nid);
    } finally {
      if (nid != null) calloc.free(nid);
      if (hWnd != 0) DestroyWindow(hWnd);
      UnregisterClass(classNamePtr, hInstance);
      calloc.free(wc);
      calloc.free(classNamePtr);
      calloc.free(windowTitlePtr);
    }
  }

  /// Windows API callback - static method to prevent GC issues.
  static int _defWindowProc(int hWnd, int uMsg, int wParam, int lParam) {
    return DefWindowProc(hWnd, uMsg, wParam, lParam);
  }

  /// Linux: notify-send
  Future<void> _showLinuxNotification(String title, String body) async {
    try {
      final result = await Process.run('notify-send', [
        '--app-name=KeeVault',
        '--urgency=normal',
        title,
        body,
      ]);
      if (result.exitCode == 0) return;
    } catch (_) {}

    try {
      await _plugin.show(
        0,
        title,
        body,
        const NotificationDetails(
          linux: LinuxNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}