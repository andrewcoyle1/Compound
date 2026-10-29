import AVFAudio
import CoreImage
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
        let answer: (Result<String, Error>) -> Void = { outcome in
          switch outcome {
          case .success(let text): result(text)
          case .failure(let error):
            result(FlutterError(code: "unreadable", message: error.localizedDescription, details: nil))
          }
        }
        switch call.method {
        case "read":
          guard let jpeg = call.arguments as? FlutterStandardTypedData else {
            return result(FlutterMethodNotImplemented)
          }
          LabelText.read(jpeg.data, completion: answer)
        case "readFrame":
          guard let frame = call.arguments as? [String: Any],
                let bytes = frame["bytes"] as? FlutterStandardTypedData,
                let width = frame["width"] as? Int, let height = frame["height"] as? Int,
                let bytesPerRow = frame["bytesPerRow"] as? Int,
                let rotation = frame["rotation"] as? Int
          else { return result(FlutterMethodNotImplemented) }
          LabelText.readFrame(
            bytes.data, width: width, height: height, bytesPerRow: bytesPerRow,
            rotation: rotation, completion: answer)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WorkoutActivity") {
      workoutActivity = WorkoutActivityChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIntents") {
      AppIntentsChannel.shared = AppIntentsChannel(messenger: registrar.messenger())
    }
    // The App Store Swift app scheduled its reminders under string ids, and iOS keeps them across
    // the update to this app. Its meal reminders repeat daily, so beside Dart's own (ids 4–6)
    // each arrived twice; withdraw them all (Swift `PushManager.knownPendingIDs`).
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
      "meal_reminder_breakfast", "meal_reminder_lunch", "meal_reminder_dinner",
      "come_back_reminder_1", "come_back_reminder_3", "come_back_reminder_5",
      "workout-rest-timer",
    ])
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
    recognise(VNImageRequestHandler(data: jpeg, orientation: orientation(of: jpeg)), completion)
  }

  /// One BGRA frame of the live camera (`DeviceLiveCamera`), turned clockwise by `rotation`
  /// degrees to stand upright. The accurate recogniser still: on a Mac it read the sample label
  /// in about 80 ms where the fast one took 10 ms but misread "1.1 g" and "kJ / 370", and frames
  /// come only twice a second.
  static func readFrame(
    _ bytes: Data, width: Int, height: Int, bytesPerRow: Int, rotation: Int,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let image = CIImage(
      bitmapData: bytes, bytesPerRow: bytesPerRow, size: CGSize(width: width, height: height),
      format: .BGRA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    let orientation: CGImagePropertyOrientation =
      switch rotation {
      case 90: .right
      case 180: .down
      case 270: .left
      default: .up
      }
    recognise(VNImageRequestHandler(ciImage: image, orientation: orientation), completion)
  }

  private static func recognise(
    _ handler: VNImageRequestHandler, _ completion: @escaping (Result<String, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
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
