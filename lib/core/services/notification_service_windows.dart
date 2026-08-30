import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Windows-specific notification implementation using Win32 Shell_NotifyIcon.
/// The window class and window are created once and reused for all notifications.
class WindowsNotificationHelper {
  static final WindowsNotificationHelper _instance =
      WindowsNotificationHelper._();
  factory WindowsNotificationHelper() => _instance;
  WindowsNotificationHelper._();

  int _hWnd = 0;
  bool _classRegistered = false;
  late final int _hInstance;
  late final Pointer<Utf16> _classNamePtr;
  late final Pointer<Utf16> _windowTitlePtr;

  void _ensureInitialized() {
    if (_classRegistered) return;

    _hInstance = GetModuleHandle(nullptr);
    const className = 'KeeStoneNotifyWnd';
    _classNamePtr = className.toNativeUtf16();
    _windowTitlePtr = 'KeeStone Notify'.toNativeUtf16();

    final wc = calloc<WNDCLASS>();
    try {
      wc.ref.lpfnWndProc =
          Pointer.fromFunction(WindowsNotificationHelper._defWindowProc, 0);
      wc.ref.hInstance = _hInstance;
      wc.ref.lpszClassName = _classNamePtr;
      RegisterClass(wc);
      _classRegistered = true;

      _hWnd = CreateWindowEx(
        0,
        _classNamePtr,
        _windowTitlePtr,
        0,
        0, 0, 0, 0,
        HWND_MESSAGE,
        0,
        _hInstance,
        nullptr,
      );
    } finally {
      calloc.free(wc);
    }
  }

  void showBalloon(String title, String body) {
    _ensureInitialized();

    if (_hWnd == 0) return;

    final nid = calloc<NOTIFYICONDATA>();
    try {
      nid.ref.cbSize = sizeOf<NOTIFYICONDATA>();
      nid.ref.hWnd = _hWnd;
      nid.ref.uID = 1;
      nid.ref.uCallbackMessage = WM_APP + 1;
      // The balloon notification is attached to a notification-area icon, so
      // it must be added first and kept alive while the balloon shows. The
      // previous NIM_ADD(NIF_INFO) + immediate NIM_DELETE made Explorer
      // cancel the balloon before it was visible.
      nid.ref.uFlags = NIF_MESSAGE;
      if (Shell_NotifyIcon(NIM_ADD, nid) != 0) {
        nid.ref.uFlags = NIF_INFO;
        nid.ref.dwInfoFlags = NIIF_INFO;
        nid.ref.Anonymous.uTimeout = 10000;
        nid.ref.szInfoTitle = title;
        nid.ref.szInfo = body;
        Shell_NotifyIcon(NIM_MODIFY, nid);

        // Remove the (invisible) icon once the balloon has had time to show.
        Timer(const Duration(seconds: 15), () {
          final cleanup = calloc<NOTIFYICONDATA>();
          try {
            cleanup.ref.cbSize = sizeOf<NOTIFYICONDATA>();
            cleanup.ref.hWnd = _hWnd;
            cleanup.ref.uID = 1;
            Shell_NotifyIcon(NIM_DELETE, cleanup);
          } finally {
            calloc.free(cleanup);
          }
        });
      }
    } finally {
      calloc.free(nid);
    }
  }

  static int _defWindowProc(int hWnd, int uMsg, int wParam, int lParam) {
    return DefWindowProc(hWnd, uMsg, wParam, lParam);
  }

  void dispose() {
    if (_hWnd != 0) {
      DestroyWindow(_hWnd);
      _hWnd = 0;
    }
    if (_classRegistered) {
      UnregisterClass(_classNamePtr, _hInstance);
      calloc.free(_classNamePtr);
      calloc.free(_windowTitlePtr);
      _classRegistered = false;
    }
  }
}
