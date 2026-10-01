import AVFoundation
import SwiftUI

/// What stands between a camera screen and the camera.
///
/// "The device has no camera" and "you said no" used to be one state with one message, so a person
/// who had refused access was told their phone was not supported and given no way to change it.
enum CameraAccess: Equatable {
    /// Not asked yet, or the system alert is on screen.
    case notDetermined
    /// Refused, or restricted by Screen Time or a device profile. Settings is the only way back.
    case denied
    /// The device cannot do this at all. Nothing in Settings changes that.
    case unsupported
    case authorized
}

@MainActor
protocol CameraAccessInteractor {
    /// The permission as it stands, without asking.
    var cameraPermission: CameraAccess { get }
    /// Shows the system alert. Only meaningful while the permission is `.notDetermined`.
    func requestCameraPermission() async -> Bool
    func openAppSettings()
}

extension CameraAccessInteractor {

    /// Asks only when nobody has been asked yet, and only once the person has opened a screen that
    /// needs the camera, which is the moment of use.
    func resolveCameraAccess(isSupported: Bool) async -> CameraAccess {
        guard isSupported else { return .unsupported }
        let current = cameraPermission
        guard current == .notDetermined else { return current }
        return await requestCameraPermission() ? .authorized : .denied
    }
}

extension CoreInteractor: CameraAccessInteractor {

    var cameraPermission: CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:           return .authorized
        case .notDetermined:        return .notDetermined
        case .denied, .restricted:  return .denied
        @unknown default:           return .denied
        }
    }

    func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
