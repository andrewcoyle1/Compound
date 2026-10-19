import AVFAudio
import Flutter
import ImageIO
import UIKit
import UserNotifications
import Vision

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
    // The rest chime (`RestSound`, played by flutter_soloud, which leaves the session to the app):
    // ambient mixes with music and podcasts and follows the silent switch, as the system sound it
    // replaced did.
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The Label scanner's on-device text reading (`PlatformLabelTextReader`).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LabelText") {
      FlutterMethodChannel(
        name: "com.andrewcoyle.compound/label_text",
        binaryMessenger: registrar.messenger()
      ).setMethodCallHandler { call, result in
        guard call.method == "read", let jpeg = call.arguments as? FlutterStandardTypedData else {
          return result(FlutterMethodNotImplemented)
        }
        LabelText.read(jpeg.data) { outcome in
          switch outcome {
          case .success(let text): result(text)
          case .failure(let error):
            result(FlutterError(code: "unreadable", message: error.localizedDescription, details: nil))
          }
        }
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

/// A label photo's text, read with Vision's accurate recogniser: the text recognition behind the
/// Swift app's `DataScannerViewController`. One line per printed line, as the Swift scanner joins
/// its transcripts.
enum LabelText {
  static func read(_ jpeg: Data, completion: @escaping (Result<String, Error>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      let handler = VNImageRequestHandler(data: jpeg, orientation: orientation(of: jpeg))
      let outcome = Result<String, Error> {
        try handler.perform([request])
        return (request.results ?? [])
          .compactMap { $0.topCandidates(1).first?.string }
          .joined(separator: "\n")
      }
      DispatchQueue.main.async { completion(outcome) }
    }
  }

  /// The photo's EXIF orientation, so a portrait shot is read upright.
  private static func orientation(of jpeg: Data) -> CGImagePropertyOrientation {
    guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let raw = properties[kCGImagePropertyOrientation] as? UInt32,
          let orientation = CGImagePropertyOrientation(rawValue: raw)
    else { return .up }
    return orientation
  }
}
