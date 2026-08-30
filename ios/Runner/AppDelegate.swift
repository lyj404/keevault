import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let urlChannel = FlutterMethodChannel(
        name: "com.keestone.keestone/external_url",
        binaryMessenger: controller.binaryMessenger
      )
      urlChannel.setMethodCallHandler { call, result in
        guard call.method == "openUrl" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let arguments = call.arguments as? [String: Any],
          let value = arguments["url"] as? String,
          let url = URL(string: value),
          let scheme = url.scheme?.lowercased(),
          url.host?.isEmpty == false,
          ["http", "https"].contains(scheme)
        else {
          result(false)
          return
        }

        UIApplication.shared.open(url, options: [:]) { opened in
          result(opened)
        }
      }

      // App Group container access for the autofill credential snapshot
      // consumed by the Credential Provider Extension. Methods:
      //   getContainerPath -> String?  (absolute path or nil if App Group unset)
      //   writeFile {path, bytes}     -> Bool
      //   deleteFile {path}           -> Bool
      let appGroupChannel = FlutterMethodChannel(
        name: "com.keestone.keestone/app_group",
        binaryMessenger: controller.binaryMessenger
      )
      appGroupChannel.setMethodCallHandler { call, result in
        let fm = FileManager.default
        let appGroupId = "group.com.keestone.keestone"
        switch call.method {
        case "getContainerPath":
          let url = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
          result(url?.path)
        case "writeFile":
          guard
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let bytes = args["bytes"] as? FlutterStandardTypedData
          else {
            result(false)
            return
          }
          do {
            try fm.createDirectory(
              at: URL(fileURLWithPath: path).deletingLastPathComponent(),
              withIntermediateDirectories: true
            )
            try bytes.data.write(to: URL(fileURLWithPath: path), options: .atomic)
            result(true)
          } catch {
            result(false)
          }
        case "deleteFile":
          guard
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String
          else {
            result(false)
            return
          }
          let url = URL(fileURLWithPath: path)
          if fm.fileExists(atPath: url.path) {
            do {
              try fm.removeItem(at: url)
              result(true)
            } catch {
              result(false)
            }
          } else {
            result(true)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
