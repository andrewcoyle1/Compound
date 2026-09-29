import AVFoundation
import SwiftUI
import VisionKit

@Observable
@MainActor
class BarcodeScannerPresenter {

    private let interactor: BarcodeScannerInteractor
    private let router: BarcodeScannerRouter

    var isScanning: Bool = false
    var scannedCode: String?

    var scanningMode: ScanningMode = .barcode
    var recognisedTypes: Set<DataScannerViewController.RecognizedDataType> = [.barcode()]

    // MARK: Label scanning state
    private(set) var isParsingLabel: Bool = false
    private(set) var parsedIngredient: FoodModel?
    private(set) var labelError: String?
    private(set) var isSavingIngredient: Bool = false
    private(set) var savedSuccessfully: Bool = false

    // MARK: Barcode lookup state
    private(set) var isLookingUpBarcode: Bool = false
    private(set) var barcodeError: String?

    /// The code the current result was produced from. The view feeds every `scannedCode` change
    /// back into `onBarcodeDetected`, so a typed barcode — which sets the code and calls through
    /// itself — would otherwise be looked up twice and filed in the library twice, each copy under
    /// its own id. Cleared by `onRescanPressed`, so the same code can be tried again deliberately.
    private var resolvedBarcode: String?

    // MARK: Manual entry
    var isEnteringManually: Bool = false
    var manualEntryText: String = ""
    private(set) var isTorchOn: Bool = false

    /// The scanner owns the capture session, so the torch is driven straight on the device rather
    /// than through it. Simulators and iPads without a torch report no support and are left alone.
    var isTorchAvailable: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    init(interactor: BarcodeScannerInteractor, router: BarcodeScannerRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: BarcodeScannerDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        isScanning = true
    }

    func onViewDisappear(delegate: BarcodeScannerDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
        isScanning = false
    }

    func onTorchPressed() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let turnOn = !isTorchOn
            device.torchMode = turnOn ? .on : .off
            isTorchOn = turnOn
        } catch {
            interactor.trackEvent(event: Event.onTorchFail(error: error))
        }
    }

    func onManualEntryPressed() {
        // Typing a barcode or label is the fallback when the camera cannot read it, so prefill
        // whatever it did manage to catch.
        manualEntryText = scannedCode ?? ""
        isEnteringManually = true
    }

    /// Feeds typed input down the same path the camera uses, so a manual barcode is looked up and
    /// manual label text is parsed exactly as a scan would be.
    func onManualEntrySubmitted() {
        let text = manualEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isEnteringManually = false

        switch scanningMode {
        case .barcode:
            onBarcodeDetected(text)
        case .label:
            scannedCode = text
            Task { await onParseLabelPressed() }
        }
    }

    // MARK: Label mode actions

    func onParseLabelPressed() async {
        guard let text = scannedCode, !text.isEmpty, !isParsingLabel,
              interactor.ensureOnline(or: router) else { return }
        isParsingLabel = true
        labelError = nil
        parsedIngredient = nil
        interactor.trackEvent(event: Event.onParseLabel)

        do {
            let json = try await interactor.analyzeNutritionLabel(text: text)
            let decoded = try JSONDecoder().decode(NutritionLabelResponse.self, from: Data(json.utf8))
            parsedIngredient = decoded.toFood(authorId: interactor.currentUser?.userId)
        } catch {
            labelError = error.localizedDescription
            interactor.trackEvent(event: Event.onLabelError(message: error.localizedDescription))
        }
        isParsingLabel = false
    }

    func onSaveIngredientPressed() async {
        guard let ingredient = parsedIngredient, !isSavingIngredient else { return }
        isSavingIngredient = true
        interactor.trackEvent(event: Event.onSaveIngredient(name: ingredient.name))

        do {
            try await interactor.saveFood(ingredient, image: nil)
            savedSuccessfully = true
            parsedIngredient = nil
            scannedCode = nil
            isScanning = true
        } catch {
            labelError = error.localizedDescription
            interactor.trackEvent(event: Event.onLabelError(message: error.localizedDescription))
        }
        isSavingIngredient = false
    }

    func onDismissLabelResultPressed() {
        parsedIngredient = nil
        labelError = nil
        savedSuccessfully = false
        isScanning = true
    }

    func onRescanPressed() {
        scannedCode = nil
        resolvedBarcode = nil
        parsedIngredient = nil
        labelError = nil
        barcodeError = nil
        isLookingUpBarcode = false
        isScanning = true
    }

    func onBarcodeDetected(_ code: String) {
        guard resolvedBarcode != code else { return }
        resolvedBarcode = code
        scannedCode = code
        isLookingUpBarcode = true
        barcodeError = nil
        parsedIngredient = nil
        interactor.trackEvent(event: Event.onBarcodeDetected(code: code))
        Task {
            defer { isLookingUpBarcode = false }
            do {
                if let local = interactor.findLocalFood(withBarcode: code) {
                    parsedIngredient = local
                    return
                }
                // `resolvedBarcode` stays set, so the camera seeing the code again does not repeat it.
                guard interactor.ensureOnline(or: router) else { return }
                let food = try await interactor.lookupBarcode(code)
                // Silent: caching the looked-up food is a side effect; the scan itself still succeeds.
                try? await interactor.saveFood(food.withAuthorId(interactor.currentUser?.userId ?? ""), image: nil)
                parsedIngredient = food
            } catch {
                barcodeError = error.localizedDescription
                interactor.trackEvent(event: Event.onBarcodeError(message: error.localizedDescription))
            }
        }
    }

    func onDismissPressed() {
        router.dismissScreen()
    }
}

extension BarcodeScannerPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: BarcodeScannerDelegate)
        case onDisappear(delegate: BarcodeScannerDelegate)
        case onParseLabel
        case onSaveIngredient(name: String)
        case onLabelError(message: String)
        case onBarcodeDetected(code: String)
        case onBarcodeError(message: String)
        case onTorchFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:           return "BarcodeScannerView_Appear"
            case .onDisappear:        return "BarcodeScannerView_Disappear"
            case .onParseLabel:       return "BarcodeScanner_ParseLabel"
            case .onSaveIngredient:   return "BarcodeScanner_SaveIngredient"
            case .onLabelError:       return "BarcodeScanner_LabelError"
            case .onBarcodeDetected:  return "BarcodeScanner_BarcodeDetected"
            case .onBarcodeError:     return "BarcodeScanner_BarcodeError"
            case .onTorchFail:        return "BarcodeScanner_TorchFail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let delegate), .onDisappear(let delegate):
                return delegate.eventParameters
            case .onSaveIngredient(let name):
                return ["ingredient_name": name]
            case .onLabelError(let message):
                return ["error": message]
            case .onBarcodeDetected(let code):
                return ["code": code]
            case .onBarcodeError(let message):
                return ["error": message]
            case .onTorchFail(let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onLabelError, .onBarcodeError, .onTorchFail: return .severe
            default:                              return .analytic
            }
        }
    }
}

enum ScanningMode: String, CaseIterable, Identifiable {
    var id: String { self.rawValue }
    case barcode
    case label

    var recognisedTypes: Set<DataScannerViewController.RecognizedDataType> {
        switch self {
        case .barcode: return [.barcode()]
        case .label:   return [.text()]
        }
    }
}

// MARK: - NutritionLabelResponse

private struct NutritionLabelResponse: Decodable {
    let name: String
    let measurementMethod: String?
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fatTotal: Double?
    let fatSaturated: Double?
    let fiber: Double?
    let sugar: Double?
    let sodiumMg: Double?
    let potassiumMg: Double?
    let calciumMg: Double?
    let ironMg: Double?

    func toFood(authorId: String?) -> FoodModel {
        let method: MeasurementMethod = measurementMethod == "volume" ? .volume : .weight
        let now = Date()
        var nutrients: NutrientMap = NutrientMap()
        func set(_ key: NutrientKey, _ value: Double?) {
            if let val = value { nutrients[key] = val }
        }
        set(.calories, calories)
        set(.protein, protein)
        set(.carbs, carbs)
        set(.fatTotal, fatTotal)
        set(.fatSaturated, fatSaturated)
        set(.fiber, fiber)
        set(.sugar, sugar)
        set(.sodiumMg, sodiumMg)
        set(.potassiumMg, potassiumMg)
        set(.calciumMg, calciumMg)
        set(.ironMg, ironMg)
        return FoodModel(
            ingredientId: UUID().uuidString,
            authorId: authorId,
            name: name,
            measurementMethod: method,
            nutrients: nutrients,
            dateCreated: now,
            dateModified: now
        )
    }
}
