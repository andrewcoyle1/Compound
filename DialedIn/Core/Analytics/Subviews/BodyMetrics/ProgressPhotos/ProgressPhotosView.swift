import SwiftUI

struct ProgressPhotosView: View {

    @State var presenter: ProgressPhotosPresenter

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: Spacing.s)]

    var body: some View {
        ScrollView {
            if presenter.photos.isEmpty {
                ContentUnavailableView(
                    "No Progress Photos",
                    systemImage: Symbol.camera,
                    description: Text("Add a front, side or back photo to see how you change over time.")
                )
                .padding(.top, Spacing.xxl)
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    Text("Select two photos to compare them.")
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                    ForEach(presenter.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(Spacing.l)
            }
        }
        .navigationTitle("Progress Photos")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if presenter.isUploading {
                ProgressView("Uploading…")
                    .padding()
                    .cardSurface(.tile)
            }
        }
        .toolbar { toolbarContent }
        .task { await presenter.onViewAppear() }
        .photosPicker(isPresented: $presenter.isLibraryPresented, selection: $presenter.libraryItem, matching: .images)
        .onChange(of: presenter.libraryItem) {
            Task { await presenter.onLibraryItemChanged() }
        }
        .fullScreenCover(isPresented: $presenter.isCameraPresented, onDismiss: presenter.onCameraDismissed) {
            ProgressPhotoCameraPicker { presenter.onCameraImagePicked($0) }
                .ignoresSafeArea()
        }
        .confirmationDialog("Which pose is this?", isPresented: $presenter.isPoseDialogPresented, titleVisibility: .visible) {
            ForEach(ProgressPhotoModel.Pose.allCases, id: \.self) { pose in
                Button(pose.title) {
                    Task { await presenter.onPoseSelected(pose) }
                }
            }
            Button("Cancel", role: .cancel) { presenter.onPoseCancelled() }
        }
        .confirmationDialog(
            "Delete this photo?",
            isPresented: Binding(
                get: { presenter.photoPendingDelete != nil },
                set: { if !$0 { presenter.photoPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await presenter.onDeleteConfirmed() }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close) {
                presenter.onDismissPressed()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Compare") {
                presenter.onComparePressed()
            }
            .disabled(!presenter.canCompare)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo", systemImage: Symbol.camera) { presenter.onCameraPressed() }
                }
                Button("Choose from Library", systemImage: "photo.on.rectangle") { presenter.onLibraryPressed() }
            } label: {
                Image(systemName: Symbol.add)
            }
            .accessibilityLabel("Add Photo")
            .disabled(presenter.isUploading)
        }
    }

    private func sectionView(_ section: ProgressPhotoSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(section.date.formatted(date: .complete, time: .omitted))
                .font(.sectionTitle)
            LazyVGrid(columns: columns, spacing: Spacing.s) {
                ForEach(section.photos) { photo in
                    cell(photo)
                }
            }
        }
    }

    private func cell(_ photo: ProgressPhotoModel) -> some View {
        let isSelected = presenter.isSelected(photo)
        return Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                ImageLoaderView(urlString: photo.imageUrl ?? "", resizingMode: .fill)
            }
            .overlay(alignment: .bottomLeading) {
                Text(photo.pose.title)
                    .font(.label)
                    .fontWeight(.semibold)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xxs)
                    // Material, not a surface: it sits on the photo and has to read over any image.
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding(Spacing.s)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .iconSize(.medium)
                        .foregroundStyle(.onAccent, .tint)
                        .padding(Spacing.s)
                }
            }
            .clipShape(.rect(cornerRadius: Radius.m, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .strokeBorder(.tint, lineWidth: 3)
                }
            }
            .contentShape(.rect)
            .anyButton(.press) { presenter.onPhotoPressed(photo) }
            .contextMenu {
                Button("Delete", systemImage: Symbol.delete, role: .destructive) {
                    presenter.onDeletePressed(photo)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(photo.pose.title) photo, \(presenter.caption(for: photo))")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(named: "Delete") { presenter.onDeletePressed(photo) }
    }
}

extension CoreBuilder {

    func progressPhotosView(router: AnyRouter) -> some View {
        ProgressPhotosView(
            presenter: ProgressPhotosPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

extension CoreRouter {

    func showProgressPhotosView() {
        router.showScreen(.push) { router in
            builder.progressPhotosView(router: router)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.progressPhotosView(router: router)
    }
}
