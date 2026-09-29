import SwiftUI
import VisionKit

struct BarcodeScannerDelegate {
    var onFoodFound: ((FoodModel) -> Void)?
    var onBarcodeScanned: ((String) -> Void)?
    var eventParameters: [String: Any]? { nil }
}

struct BarcodeScannerView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State var presenter: BarcodeScannerPresenter
    let delegate: BarcodeScannerDelegate

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
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
                        .reducedMotionAnimation(.spring(duration: 0.3), value: showOverlay)
                }
            } else {
                Text("Scanner not supported on this device.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onChange(of: presenter.scanningMode) { _, newValue in
            presenter.recognisedTypes = newValue.recognisedTypes
            presenter.onRescanPressed()
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
                    Button("Cancel") { presenter.isEnteringManually = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presenter.onManualEntrySubmitted() }
                        .disabled(presenter.manualEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Top controls

    private var topControls: some View {
        HStack {
            Picker("", selection: $presenter.scanningMode) {
                ForEach(ScanningMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 120)

            Spacer()

            Button {
                presenter.onManualEntryPressed()
            } label: {
                Image(systemName: "keyboard")
                    .padding()
                    .background(.secondary, in: .circle)
            }
            .accessibilityLabel("Enter manually")

            if presenter.isTorchAvailable {
                Button {
                    presenter.onTorchPressed()
                } label: {
                    Image(systemName: presenter.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .padding()
                        .background(.secondary, in: .circle)
                }
                .accessibilityLabel(presenter.isTorchOn ? String(localized: "Turn off torch") : String(localized: "Turn on torch"))
            }
        }
        .padding()
    }

    // MARK: - Barcode bottom display

    @ViewBuilder
    private var barcodeBottomDisplay: some View {
        if presenter.isLookingUpBarcode {
            HStack(spacing: 10) {
                ProgressView()
                Text("Looking up product...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect()
            .padding(.bottom, 32)
        } else if presenter.scannedCode == nil {
            Text("Point camera at a barcode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect()
                .padding(.bottom, 32)
        }
    }

    // MARK: - Label mode bottom bar

    private var labelModeBottomBar: some View {
        VStack(spacing: 10) {
            if presenter.isParsingLabel {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analysing label...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .glassEffect()

                Button("Re-scan", action: presenter.onRescanPressed)
                    .buttonStyle(.glass)
            } else if presenter.scannedCode != nil {
                Text("Label text captured")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Re-scan", action: presenter.onRescanPressed)
                        .buttonStyle(.glass)

                    Button {
                        Task { await presenter.onParseLabelPressed() }
                    } label: {
                        Text("Parse Label")
                            .foregroundStyle(colorScheme.backgroundPrimary)
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                Text("Point camera at a nutrition label")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .glassEffect()
            }
        }
        .padding(.bottom, 32)
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
        VStack(alignment: .leading, spacing: 16) {
            if let ingredient = presenter.parsedIngredient {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ingredient.name)
                            .font(.title3.bold())
                        Spacer()
                        Text("per 100g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let description = ingredient.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Macros row
                HStack(spacing: 8) {
                    if let cal = ingredient.calories {
                        macroChip("\(Int(cal)) kcal", color: .orange)
                    }
                    if let protein = ingredient.protein {
                        macroChip("P \(formatted(protein))g", color: .blue)
                    }
                    if let carbs = ingredient.carbs {
                        macroChip("C \(formatted(carbs))g", color: .green)
                    }
                    if let fatTotal = ingredient.fatTotal {
                        macroChip("F \(formatted(fatTotal))g", color: .yellow)
                    }
                }

                // Secondary nutrients
                let secondaryItems: [NutrientAmount] = [
                    NutrientAmount(name: "Fiber", value: ingredient.fiber, unit: "g"),
                    NutrientAmount(name: "Sugar", value: ingredient.sugar, unit: "g"),
                    NutrientAmount(name: "Sat fat", value: ingredient.fatSaturated, unit: "g"),
                    NutrientAmount(name: "Sodium", value: ingredient.sodiumMg, unit: "mg"),
                    NutrientAmount(name: "Potassium", value: ingredient.potassiumMg, unit: "mg"),
                    NutrientAmount(name: "Calcium", value: ingredient.calciumMg, unit: "mg"),
                    NutrientAmount(name: "Iron", value: ingredient.ironMg, unit: "mg")
                ]
                let available = secondaryItems.filter { $0.value != nil }
                if !available.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(available, id: \.name) { nutrient in
                            Text("\(nutrient.name): \(formatted(nutrient.value))\(nutrient.unit)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }

            } else if let error = presenter.barcodeError, presenter.scanningMode == .barcode {
                Label(error, systemImage: "barcode.viewfinder")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            } else if let error = presenter.labelError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            }

            // Action buttons
            if presenter.scanningMode == .barcode {
                HStack(spacing: 12) {
                    Button("Re-scan", action: presenter.onRescanPressed)
                        .buttonStyle(.glass)
                        .frame(maxWidth: .infinity)

                    if let ingredient = presenter.parsedIngredient {
                        Button {
                            delegate.onFoodFound?(ingredient)
                            presenter.onDismissPressed()
                        } label: {
                            Text("Use This Food")
                                .foregroundStyle(colorScheme.backgroundPrimary)
                        }
                        .buttonStyle(.glassProminent)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Button("Dismiss") {
                        presenter.onDismissLabelResultPressed()
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)

                    if presenter.parsedIngredient != nil {
                        Button {
                            Task { await presenter.onSaveIngredientPressed() }
                        } label: {
                            if presenter.isSavingIngredient {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(colorScheme.backgroundPrimary)
                            } else {
                                Text("Save to Library")
                                    .frame(maxWidth: .infinity)
                                    .foregroundStyle(colorScheme.backgroundPrimary)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(presenter.isSavingIngredient)
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.bottom, 32)
    }

    // MARK: - Helpers

    private func macroChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.2), in: Capsule())
    }

    /// Accepts an optional so `NutrientAmount.value` can be passed straight through;
    /// non-optional call sites are unaffected.
    private func formatted(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
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
                router: CoreRouter(router: router, builder: self)
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
