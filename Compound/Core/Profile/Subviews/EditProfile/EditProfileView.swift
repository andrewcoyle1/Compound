import SwiftUI
import PhotosUI

struct EditProfileDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct EditProfileView: View {
    
    @State var presenter: EditProfilePresenter
    let delegate: EditProfileDelegate
    
    var body: some View {
        List {
            imageSection
            profileSection
            privacySection
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $presenter.isImagePickerPresented, selection: $presenter.selectedPhotoItem, matching: .images)
        .onAppear(perform: presenter.prefillFromCurrentUser)
        .onChange(of: presenter.selectedPhotoItem) {
            guard let newItem = presenter.selectedPhotoItem else { return }

            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            presenter.selectedImageData = data
                            presenter.trackPhotoSelected()
                        }
                    }
                } catch {
                    await MainActor.run {
                        presenter.trackPhotoLoadFailed(error: error)
                    }
                }
            }
        }
        .toolbar {
            toolbarContent
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var imageSection: some View {
        Section {
            Group {
                if let data = presenter.selectedImageData {
#if canImport(UIKit)
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .accessibilityLabel(Text("Profile photo"))
                    }
#elseif canImport(AppKit)
                    if let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    }
#endif
                } else if let profileImageUrl = presenter.currentUser?.submittedProfileImage {
                    // Use cached image
                    ImageLoaderView(urlString: profileImageUrl, imageDescription: String(localized: "Profile photo"))
                } else {
                    ImageLoaderView()
                }
            }
            .frame(height: 200)
            .removeListRowFormatting()
        }
        .listSectionMargins(.top, 0)
        .listSectionMargins(.horizontal, 0)
    }

    private var profileSection: some View {
        Section("Profile") {
            usernameRow
            TextField("First name", text: $presenter.firstName)
                .textContentType(.givenName)
            TextField("Last name", text: $presenter.lastName)
                .textContentType(.familyName)

            DatePicker("Date of birth", selection: $presenter.dateOfBirth, in: ...Date(), displayedComponents: .date)
            // Sex, as onboarding asks it: only the calorie estimate uses it.
            Picker(selection: $presenter.selectedGender) {
                Text("Not specified").tag(nil as Gender?)
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.description).tag(gender as Gender?)
                }
            } label: {
                Text("Sex")
            }

            // Typed in the Units screen's length unit; the presenter converts to centimetres on save.
            LabeledContent("Height") {
                HStack(spacing: Spacing.s) {
                    TextField("Height", text: $presenter.heightText, prompt: Text("0"))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(presenter.heightUnit.measurementAbbreviation)
                        .foregroundStyle(.secondary)
                }
            }

            Picker(selection: $presenter.selectedCardioFitnessLevel) {
                Text("Not specified").tag(nil as CardioFitnessLevel?)
                ForEach(CardioFitnessLevel.allCases, id: \.self) { level in
                    Text(level.description).tag(level as CardioFitnessLevel?)
                }
            } label: {
                Text("Cardio Experience")
            }

            Picker(selection: $presenter.selectedExerciseFrequency) {
                Text("Not specified").tag(nil as ExerciseFrequency?)
                ForEach(ExerciseFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.description).tag(frequency as ExerciseFrequency?)
                }
            } label: {
                // Onboarding's "Do You Work Out?" step: one name for one setting.
                Text("Exercise Frequency")
            }

            Picker(selection: $presenter.selectedActivityLevel) {
                Text("Not specified").tag(nil as ActivityLevel?)
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(level.description).tag(level as ActivityLevel?)
                }
            } label: {
                Text("Daily Activity")
            }
        }
    }

    private var usernameRow: some View {
        ListRowButton(title: String(localized: "Username"), accessory: .custom(AnyView(
            HStack(spacing: Spacing.s) {
                Text(presenter.currentUser?.username.map { "@\($0)" } ?? String(localized: "Not set"))
                    .font(.rowTitle)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.forward")
                    .font(.rowDetail.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        ))) {
            presenter.onUsernamePressed()
        }
    }

    private var privacySection: some View {
        Section {
            Toggle("Private profile", isOn: $presenter.isPrivate)
        } header: {
            Text("Privacy")
        } footer: {
            Text("People must ask to follow a private profile. Until you accept, they see only your name and counts. Private profiles are left out of suggestions.")
        }
    }

    // A "Data Management" section sat here with two rows. Data Export was an empty closure and stays
    // unbuilt: it needs an export format and a Cloud Function, and `functions/` has no export
    // callable. Data Visibility routed to a screen that is still a template stub, and wants a privacy
    // model plus matching Firestore rules — a visibility toggle that does not restrict reads is worse
    // than no toggle. Both are recorded in the plan's deferred table.

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) {
                presenter.onCancelPressed()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presenter.presentImagePicker()
            } label: {
                Image(systemName: presenter.currentUser?.submittedProfileImage == nil ? "photo.badge.plus" : "photo.badge.checkmark")
            }
            .accessibilityLabel(presenter.currentUser?.submittedProfileImage == nil ? String(localized: "Add profile photo") : String(localized: "Change profile photo"))
        }
        // The fields above are editors, and without this nothing on the screen could be saved.
        ToolbarItem(placement: .confirmationAction) {
            if presenter.isSaving {
                ProgressView()
            } else {
                Button(role: .confirm) {
                    Task { await presenter.saveProfile() }
                }
                .disabled(!presenter.canSave)
            }
        }
    }

}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = EditProfileDelegate()
    
    return RouterView { router in
        builder.editProfileView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func editProfileView(router: AnyRouter, delegate: EditProfileDelegate) -> some View {
        EditProfileView(
            presenter: EditProfilePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showEditProfileView(delegate: EditProfileDelegate) {
        router.showScreen(.sheet) { router in
            builder.editProfileView(router: router, delegate: delegate)
        }
    }
    
}
