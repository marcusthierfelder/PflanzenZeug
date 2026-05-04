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

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PflanzenwartICloudChannel")!
    let channel = FlutterMethodChannel(
      name: "de.marcusthierfelder.pflanzenwart/icloud",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { (call, result) in
      if call.method == "getICloudContainerPath" {
        if let url = FileManager.default.url(
          forUbiquityContainerIdentifier: "iCloud.de.marcusthierfelder.pflanzenwart"
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
