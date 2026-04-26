import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let controller = window?.rootViewController as? FlutterViewController
    let channel = FlutterMethodChannel(
      name: "de.marcusthierfelder.pflanzenZeug/icloud",
      binaryMessenger: controller?.binaryMessenger ?? engineBridge.pluginRegistry.messenger
    )

    channel.setMethodCallHandler { (call, result) in
      if call.method == "getICloudContainerPath" {
        if let url = FileManager.default.url(
          forUbiquityContainerIdentifier: "iCloud.de.marcusthierfelder.pflanzenZeug"
        ) {
          let documentsUrl = url.appendingPathComponent("Documents")
          // Ordner erstellen falls nötig
          try? FileManager.default.createDirectory(
            at: documentsUrl, withIntermediateDirectories: true
          )
          result(documentsUrl.path)
        } else {
          result(FlutterError(
            code: "ICLOUD_UNAVAILABLE",
            message: "iCloud ist nicht verfügbar. Bitte in den Einstellungen anmelden.",
            details: nil
          ))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
