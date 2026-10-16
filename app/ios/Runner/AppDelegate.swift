import AudioToolbox
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The Live Activity and the home-screen widgets (`WorkoutActivityChannel`).
  private var workoutActivity: WorkoutActivityChannel?

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WorkoutActivity") {
      workoutActivity = WorkoutActivityChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIntents") {
      AppIntentsChannel.shared = AppIntentsChannel(messenger: registrar.messenger())
    }
    // Pushes the system displayed while the app was in the background have no integer id for
    // flutter_local_notifications, so they are cleared here by identifier, all but `keep` (the
    // app's own reminders and the ongoing workout), as Swift's `clearAllDeliveredNotifications`.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeliveredPushes") {
      FlutterMethodChannel(
        name: "com.andrewcoyle.compound/notifications",
        binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { call, result in
        guard call.method == "clearDelivered" else { return result(FlutterMethodNotImplemented) }
        let keep = Set((call.arguments as? [String: Any])?["keep"] as? [String] ?? [])
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { delivered in
          let gone = delivered.map(\.request.identifier).filter { !keep.contains($0) }
          center.removeDeliveredNotifications(withIdentifiers: gone)
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }
}
