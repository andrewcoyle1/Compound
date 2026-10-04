import SwiftUI

struct FoodPhotoScannerDelegate {
    let onPick: (MealItemModel) -> Void
}

struct FoodPhotoScannerView: View {

    @State var presenter: FoodPhotoScannerPresenter
    let delegate: FoodPhotoScannerDelegate

    @State private var capturedImage: UIImage?
    @State private var shouldCapture: Bool = false

    var body: some View {
        Group {
            if let image = capturedImage {
                if presenter.isAnalysing {
                    analysingPhase(image: image)
                } else {
                    resultsPhase(image: image)
                }
            } else {
                cameraPhase
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            presenter.onViewAppear()
        }
        .task {
            await presenter.onCameraNeeded(isSupported: UIImagePickerController.isSourceTypeAvailable(.camera))
        }
    }

    // MARK: - Phases

    private var cameraPhase: some View {
        ZStack(alignment: .bottom) {
            switch presenter.cameraAccess {
            case .authorized:
                CameraCapture(shouldCapture: $shouldCapture) { image in
                    capturedImage = image
                    Task {
                        await presenter.onCapture(image)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all, edges: .bottom)

                VStack(spacing: Spacing.m) {
                    aiDisclosure
                    captureButton
                }
                .padding(.bottom, Spacing.xxl)
            case .notDetermined:
                // The system alert is on screen, or about to be.
                Color.clear
            case .denied:
                ContentUnavailableView {
                    Label("Camera Access Is Off", systemImage: Symbol.camera)
                } description: {
                    Text("Allow camera access in Settings to photograph a meal. You can still add foods with Search or Describe.")
                } actions: {
                    Button("Open Settings") {
                        presenter.onOpenSettingsPressed()
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .unsupported:
                ContentUnavailableView {
                    Label("Camera Unavailable", systemImage: Symbol.camera)
                } description: {
                    Text("This device has no camera. You can still add foods with Search or Describe.")
                }
            }
        }
    }

    private func analysingPhase(image: UIImage) -> some View {
        VStack(spacing: Spacing.xl) {
            thumbnailView(image: image)
            ProgressView("Analyzing meal…")
                .progressViewStyle(.circular)
            retakeButton
        }
        .padding()
    }

    /// A `List`, like the describer's results and the search tab, so every picker mode that shows
    /// foods shows them the same way.
    private func resultsPhase(image: UIImage) -> some View {
        List {
            Section {
                thumbnailView(image: image)
                    .listRowInsets(EdgeInsets())
            }

            if let error = presenter.errorMessage {
                Section {
                    InlineMessage(.error, error)
                }
            } else if presenter.analysisResults.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Foods Recognized", systemImage: Symbol.food)
                    } description: {
                        Text("Retake the photo in good light, or use Search or Describe.")
                    }
                }
            } else {
                Section {
                    ForEach(presenter.analysisResults) { item in
                        FoodAnalysisResultRow(item: item) {
                            presenter.onResultTapped(item, onPick: delegate.onPick)
                        }
                    }
                } header: {
                    AIEstimateHeader(count: presenter.analysisResults.count, isAdded: presenter.didAddAll) {
                        presenter.onAddAllPressed(onPick: delegate.onPick)
                    }
                } footer: {
                    Text("Estimates can be wrong. Check amounts before logging.")
                }
            }
        }
        .bottomCTA {
            CallToActionButton(isPrimaryAction: false) {
                capturedImage = nil
                presenter.onRetakePressed()
            } label: {
                Text("Retake")
            }
        }
    }

    // MARK: - Subviews

    /// Drawn over the live camera, so white on the dark preview is the one colour that always
    /// reads; it is not an accent stand-in.
    private var captureButton: some View {
        Button {
            shouldCapture = true
        } label: {
            Image(systemName: "camera.circle.fill")
                .iconSize(.hero)
                .foregroundStyle(.white)
                .shadow(radius: Spacing.xs)
        }
        .accessibilityLabel("Take photo")
    }

    /// What "AI" means here: the photo leaves the device, and what happens to it once it does.
    private var aiDisclosure: some View {
        Text("Estimated by AI from your photo. The photo is sent to Google's AI service for analysis and isn't stored by Compound.")
            .font(.caption)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.l, style: .continuous))
            .padding(.horizontal, Spacing.xl)
    }

    private func thumbnailView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: ChartHeight.regular)
            .clipShape(.rect(cornerRadius: Radius.m, style: .continuous))
    }

    private var retakeButton: some View {
        Button("Retake") {
            capturedImage = nil
            presenter.onRetakePressed()
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - CameraCapture

struct CameraCapture: UIViewControllerRepresentable {

    @Binding var shouldCapture: Bool
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return UIViewController()
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.showsCameraControls = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
        if shouldCapture, let picker = uiViewController as? UIImagePickerController {
            picker.takePicture()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraCapture

        init(_ parent: CameraCapture) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.shouldCapture = false
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
        }
    }
}

// MARK: - CoreBuilder

extension CoreBuilder {
    func foodPhotoScannerView(router: AnyRouter, delegate: FoodPhotoScannerDelegate) -> some View {
        FoodPhotoScannerView(
            presenter: FoodPhotoScannerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

// MARK: - Preview

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FoodPhotoScannerDelegate(onPick: { item in
        print(item.displayName)
    })

    return RouterView { router in
        builder.foodPhotoScannerView(router: router, delegate: delegate)
    }
}
