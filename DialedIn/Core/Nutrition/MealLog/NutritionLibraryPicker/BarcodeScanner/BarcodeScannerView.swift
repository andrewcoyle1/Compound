import SwiftUI
import VisionKit

struct BarcodeScannerDelegate {
    var onFoodFound: ((FoodModel) -> Void)?
    var onBarcodeScanned: ((String) -> Void)?
    var eventParameters: [String: Any]? { nil }
}

struct BarcodeScannerView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State var presenter: BarcodeScannerPresenter
    let delegate: BarcodeScannerDelegate

    /// Inside the food picker the scanner is one mode of a screen that already has a title and a
    /// way out. Opened on its own, from Create Food, it is a sheet and needs both.
    var body: some View {
        if presenter.returnsBarcodeOnly {
            scanner
                .navigationTitle("Scan Barcode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { presenter.onDismissPressed() }
                    }
                }
        } else {
            scanner
        }
    }

    private var scanner: some View {
        ZStack {
            switch presenter.cameraAccess {
            case .authorized:
                BarcodeScanner(
                    isScanning: $presenter.isScanning,
                    scannedCode: $presenter.scannedCode,
                    recognizedDataTypes: $presenter.recognisedTypes,
                    scanningMode: presenter.scanningMode
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)

                VStack {
                    topControls
                    Spacer()
                    if presenter.scanningMode == .barcode {
                        barcodeBottomDisplay
                    } else {
                        labelModeBottomBar
                    }
                }

                let showOverlay = presenter.parsedIngredient != nil
                    || (presenter.scanningMode == .label && !presenter.isParsingLabel && presenter.labelError != nil)
                    || (presenter.scanningMode == .barcode && presenter.barcodeError != nil)
                if showOverlay {
                    parsedIngredientOverlay
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .reducedMotionAnimation(.standard, value: showOverlay)
                }
            case .notDetermined:
                // The system alert is on screen, or about to be.
                Color.clear
            case .denied:
                cameraDeniedView
            case .unsupported:
                scannerUnsupportedView
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .task {
            await presenter.onCameraNeeded(isSupported: DataScannerViewController.isSupported)
        }
        .onChange(of: presenter.scanningMode) {
            presenter.onScanningModeChanged()
        }
        .onChange(of: presenter.scannedCode) { _, newValue in
            guard let code = newValue, presenter.scanningMode == .barcode else { return }
            presenter.onBarcodeDetected(code)
        }
        .sheet(isPresented: $presenter.isEnteringManually) {
            manualEntrySheet
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - No camera

    /// Typing the barcode needs no camera, so it is offered in both states below.
    private var cameraDeniedView: some View {
        ContentUnavailableView {
            Label("Camera Access Is Off", systemImage: Symbol.camera)
        } description: {
            Text("Allow camera access in Settings to scan barcodes and nutrition labels, or type the barcode in.")
        } actions: {
            Button("Open Settings") {
                presenter.onOpenSettingsPressed()
            }
            .buttonStyle(.glassProminent)
            enterManuallyButton
        }
    }

    private var scannerUnsupportedView: some View {
        ContentUnavailableView {
            Label("Scanner Unavailable", systemImage: Symbol.barcode)
        } description: {
            Text("This device can't scan barcodes. You can type the barcode in.")
        } actions: {
            enterManuallyButton
        }
    }

    private var enterManuallyButton: some View {
        Button("Enter Manually") {
            presenter.onManualEntryPressed()
        }
        .buttonStyle(.glass)
    }

    // MARK: - Manual entry

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        presenter.scanningMode == .barcode ? String(localized: "Barcode number") : String(localized: "Label text"),
                        text: $presenter.manualEntryText,
                        axis: presenter.scanningMode == .barcode ? .horizontal : .vertical
                    )
                    .keyboardType(presenter.scanningMode == .barcode ? .numberPad : .default)
                    .lineLimit(presenter.scanningMode == .barcode ? 1 : 10)
                } footer: {
                    Text(
                        presenter.scanningMode == .barcode
                        ? "Type the barcode digits printed under the bars."
                        : "Type the nutrition table as it appears on the packaging."
                    )
                }
            }
            .navigationTitle(presenter.scanningMode == .barcode ? String(localized: "Enter Barcode") : String(localized: "Enter Label"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { presenter.isEnteringManually = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { presenter.onManualEntrySubmitted() }
                        .disabled(presenter.manualEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        // A native sheet, because it edits the presenter's bindings; the detents match `.half`, so
        // the field is never trapped at the large type sizes.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Top controls

    private var topControls: some View {
        HStack {
            // Reading a label produces a food, which a caller that only wants the digits cannot use.
            if !presenter.returnsBarcodeOnly {
                Picker("Scanning mode", selection: $presenter.scanningMode) {
                    ForEach(ScanningMode.allCases) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            Spacer()

            Button {
                presenter.onManualEntryPressed()
            } label: {
                Image(systemName: "keyboard")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Enter manually")

            if presenter.isTorchAvailable {
                Button {
                    presenter.onTorchPressed()
                } label: {
                    Image(systemName: presenter.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(presenter.isTorchOn ? String(localized: "Turn off torch") : String(localized: "Turn on torch"))
            }
        }
        .padding()
    }

    // MARK: - Barcode bottom display

    @ViewBuilder
    private var barcodeBottomDisplay: some View {
        if presenter.isLookingUpBarcode {
            HStack(spacing: Spacing.s) {
                ProgressView()
                Text("Looking up product...")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.m)
            .glassEffect()
            .padding(.bottom, Spacing.xxl)
        } else if presenter.scannedCode == nil {
            Text("Point camera at a barcode")
                .font(.rowDetail)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.m)
                .glassEffect()
                .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Label mode bottom bar

    private var labelModeBottomBar: some View {
        VStack(spacing: Spacing.m) {
            if presenter.isParsingLabel {
                HStack(spacing: Spacing.s) {
                    ProgressView()
                    Text("Analyzing label...")
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, Spacing.m)
                .glassEffect()

                Button("Re-scan", action: presenter.onRescanPressed)
                    .buttonStyle(.glass)
            } else if presenter.scannedCode != nil {
                Text("Label text captured")
                    .font(.label)
                    .foregroundStyle(.secondary)

                HStack(spacing: Spacing.m) {
                    Button("Re-scan", action: presenter.onRescanPressed)
                        .buttonStyle(.glass)

                    Button {
                        Task { await presenter.onParseLabelPressed() }
                    } label: {
                        Text("Parse Label")
                            .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                Text("Point camera at a nutrition label")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, Spacing.m)
                    .glassEffect()
            }
        }
        .padding(.bottom, Spacing.xxl)
    }

    // MARK: - Parsed ingredient overlay

    private var parsedIngredientOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { presenter.onDismissLabelResultPressed() }
            parsedIngredientCard
        }
    }

    private var parsedIngredientCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if let ingredient = presenter.parsedIngredient {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(ingredient.name)
                            .font(.sectionTitle)
                        Spacer()
                        Text("per 100g")
                            .font(.label)
                            .foregroundStyle(.secondary)
                    }
                    if let description = ingredient.description {
                        Text(description)
                            .font(.label)
                            .foregroundStyle(.secondary)
                    }
                }

                MacroChips(calories: ingredient.calories, protein: ingredient.protein, carbs: ingredient.carbs, fat: ingredient.fatTotal)

                let secondaryItems: [NutrientAmount] = [
                    NutrientAmount(name: String(localized: "Fiber"), value: ingredient.fiber, unit: "g"),
                    NutrientAmount(name: String(localized: "Sugar"), value: ingredient.sugar, unit: "g"),
                    NutrientAmount(name: String(localized: "Sat fat"), value: ingredient.fatSaturated, unit: "g"),
                    NutrientAmount(name: String(localized: "Sodium"), value: ingredient.sodiumMg, unit: "mg"),
                    NutrientAmount(name: String(localized: "Potassium"), value: ingredient.potassiumMg, unit: "mg"),
                    NutrientAmount(name: String(localized: "Calcium"), value: ingredient.calciumMg, unit: "mg"),
                    NutrientAmount(name: String(localized: "Iron"), value: ingredient.ironMg, unit: "mg")
                ]
                let available = secondaryItems.filter { $0.value != nil }
                if !available.isEmpty {
                    FlowLayout(spacing: Spacing.xs) {
                        ForEach(available, id: \.name) { nutrient in
                            Chip("\(nutrient.name): \(nutrient.formattedValue)", tint: .secondary)
                        }
                    }
                }

            } else if let error = presenter.barcodeError, presenter.scanningMode == .barcode {
                InlineMessage(.error, error)
            } else if let error = presenter.labelError {
                InlineMessage(.error, error)
            }

            actionButtons
        }
        .padding(Spacing.xl)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.xxl)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if presenter.scanningMode == .barcode {
            HStack(spacing: Spacing.m) {
                Button("Re-scan", action: presenter.onRescanPressed)
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)

                if let ingredient = presenter.parsedIngredient {
                    Button {
                        delegate.onFoodFound?(ingredient)
                        presenter.onDismissPressed()
                    } label: {
                        Text("Use This Food")
                            .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            HStack(spacing: Spacing.m) {
                Button("Dismiss") {
                    presenter.onDismissLabelResultPressed()
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)

                if presenter.parsedIngredient != nil {
                    Button {
                        Task { await presenter.onSaveIngredientPressed() }
                    } label: {
                        Group {
                            if presenter.isSavingIngredient {
                                ProgressView()
                                    .tint(.onAccent)
                            } else {
                                Text("Save to Library")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(presenter.isSavingIngredient)
                }
            }
        }
    }
}

// MARK: - BarcodeScanner (UIViewControllerRepresentable)

struct BarcodeScanner: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    @Binding var scannedCode: String?
    @Binding var recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    var scanningMode: ScanningMode

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: BarcodeScanner

        init(_ parent: BarcodeScanner) {
            self.parent = parent
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            switch parent.scanningMode {
            case .barcode:
                guard let item = addedItems.first,
                      case let .barcode(barcode) = item,
                      let payload = barcode.payloadStringValue else { return }
                parent.scannedCode = payload
                parent.isScanning = false
            case .label:
                let text = allItems.compactMap { item -> String? in
                    if case let .text(textItem) = item { return textItem.transcript }
                    return nil
                }.joined(separator: "\n")
                guard !text.isEmpty else { return }
                parent.scannedCode = text
                // Don't stop scanning — user triggers analysis manually
            }
        }
    }
}

// MARK: - CoreBuilder

extension CoreBuilder {

    func barcodeScannerView(router: AnyRouter, delegate: BarcodeScannerDelegate) -> some View {
        BarcodeScannerView(
            presenter: BarcodeScannerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                delegate: delegate
            ),
            delegate: delegate
        )
    }

}

// MARK: CoreRouter

extension CoreRouter {
    
    func showBarcodeScannerView(delegate: BarcodeScannerDelegate) {
        router.showScreen(.sheet) { router in
            builder.barcodeScannerView(router: router, delegate: delegate)
        }
    }
}

// MARK: - Preview

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = BarcodeScannerDelegate()

    return RouterView { router in
        builder.barcodeScannerView(router: router, delegate: delegate)
    }
}
