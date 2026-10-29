import Flutter
import Foundation
import Gopeed

/// iOS side of `com.asterlink.app/native`. Only the methods Dart calls on iOS
/// are implemented; everything else reports notImplemented.
public final class AsterLinkNativeBridge: NSObject {
  private static var shared: AsterLinkNativeBridge?

  private let channel: FlutterMethodChannel
  // The engine is not reentrant across open/close; keep calls in order like the
  // desktop pipe and Android's single native worker.
  private let engineQueue = DispatchQueue(label: "com.asterlink.app.gopeed", qos: .userInitiated)
  private let keepAlive = BackgroundKeepAlive()

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.asterlink.app/native", binaryMessenger: messenger)
    super.init()
    keepAlive.onExpired = { [weak self] in
      // Background time ran out without the audio keep-alive; pause cleanly so
      // tasks resume from saved progress instead of failing mid-transfer.
      self?.channel.invokeMethod("serviceTimeout", arguments: nil)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  public static func register(with messenger: FlutterBinaryMessenger) {
    shared = AsterLinkNativeBridge(messenger: messenger)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "gopeed":
      let method = args["method"] as? String ?? ""
      let payload = args["args"] as? String ?? "{}"
      engineQueue.async {
        var error: NSError?
        let value = MobilecoreCall(method, payload, &error)
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "operation", message: error.localizedDescription, details: nil))
          } else {
            result(value)
          }
        }
      }
    case "foreground":
      let active = (args["active"] as? NSNumber)?.intValue ?? 0
      keepAlive.update(active: active > 0)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
