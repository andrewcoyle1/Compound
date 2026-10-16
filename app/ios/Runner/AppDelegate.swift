import AudioToolbox
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: lets the app decide how a notification shows while it is in
    // front (the rest timer's stays quiet), and hears taps.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The rest-complete sound (`RestSound`): system sound 1007, the stand-in the Swift app plays
    // (`SoundEffectFile.restComplete`). It follows the silent switch.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RestSound") {
      FlutterMethodChannel(
        name: "com.andrewcoyle.compound/sound",
        binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { call, result in
        guard call.method == "restComplete" else { return result(FlutterMethodNotImplemented) }
        AudioServicesPlaySystemSound(1007)
        result(nil)
      }
    }
  }
}
