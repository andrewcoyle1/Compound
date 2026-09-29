//
//  BarcodeScannerHandoffTests.swift
//  DialedInUnitTests
//
//  Split out of BarcodeScannerPresenterTests.swift, which was already at the file-length limit.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// "Use This Food", inside the food picker.
///
/// The scanner is a mode switched in place inside the picker, not a screen of its own, so it must
/// never dismiss on its own — that would close the whole picker before the amount screen
/// `onFoodFound` pushes could show. It used to, by calling `dismissScreen()` after handing the
/// food back; the fix moved the tap into a presenter method that only forwards to the delegate.
@MainActor
struct BarcodeScannerHandoffTests {

    private final class Interactor: SpyGlobalInteractor, BarcodeScannerInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var cameraPermission: CameraAccess = .authorized
        func requestCameraPermission() async -> Bool { true }
        func openAppSettings() { }
        func analyzeNutritionLabel(text: String) async throws -> String { "" }
        func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws { }
        func lookupBarcode(_ code: String) async throws -> FoodModel { FoodModel(name: code) }
        func findLocalFood(withBarcode barcode: String) -> FoodModel? { nil }
    }

    private final class Router: BarcodeScannerRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @Test("Test Using A Found Food Only Hands It Back")
    func testUsingAFoundFoodOnlyHandsItBack() {
        var received: [String] = []
        let delegate = BarcodeScannerDelegate(onFoodFound: { received.append($0.name) })
        let presenter = BarcodeScannerPresenter(interactor: Interactor(), router: Router(), delegate: delegate)

        presenter.onUseThisFoodPressed(FoodModel(name: "Oat Milk"), delegate: delegate)

        #expect(received == ["Oat Milk"])
    }
}
