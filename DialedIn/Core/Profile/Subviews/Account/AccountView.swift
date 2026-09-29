import SwiftUI
import PhotosUI

struct AccountDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct AccountView: View {
    
    @State var presenter: AccountPresenter
    let delegate: AccountDelegate
    
    var body: some View {
        List {
            imageSection
            profileSection
            privacySection
            securitySection
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Account")
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
                    ImageLoaderView(urlString: profileImageUrl)
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

            DatePicker("Date of birth", selection: $presenter.dateOfBirth, displayedComponents: .date)
            Picker(selection: $presenter.selectedGender) {
                Text("Not specified").tag(nil as Gender?)
                Text("Male").tag(Gender.male as Gender?)
                Text("Female").tag(Gender.female as Gender?)
            } label: {
                Text("Gender")
            }

            // Centimetres, matching `UserModel.submittedHeightCentimeters`. The Units screen governs
            // how height is *displayed* elsewhere; converting here as well would need that
            // preference threading through, and would make the stored unit ambiguous on save.
            HStack {
                Text("Height")
                Spacer()
                TextField("0", text: $presenter.heightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                Text("cm")
                    .foregroundStyle(.secondary)
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
                Text("Lifting Experience")
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

    private var securitySection: some View {
        Section {
            // Read-only, not an editor. Sign-in is Apple, Google or anonymous, so the address is the
            // identity provider's and cannot be changed from here. A "Password ********" row used to
            // sit below this one — removed, because there is no password to change: `SignInOption`
            // has no email case anywhere in the app.
            ListRow(title: String(localized: "Email"), accessory: .value(presenter.currentUser?.email ?? String(localized: "Not provided")))

            // Signing an anonymous account out locks it away for good, so that account is offered
            // the upgrade in place of Log Out rather than alongside it.
            if presenter.isAnonymousUser {
                ListRowButton(title: String(localized: "Save & back-up account"), accessory: .none) {
                    presenter.onSaveAccountPressed()
                }
            } else {
                ListRowButton(title: String(localized: "Log Out"), accessory: .none) {
                    presenter.onSignOutPressed()
                }
            }
            Button(role: .destructive) {
                presenter.onDeleteAccountPressed()
            } label: {
                Text("Delete Account")
            }
        } header: {
            Text("Security")
        }
    }

    // A "Data Management" section sat here with two rows. Data Export was an empty closure and stays
    // unbuilt: it needs an export format and a Cloud Function, and `functions/` has no export
    // callable. Data Visibility routed to a screen that is still a template stub, and wants a privacy
    // model plus matching Firestore rules — a visibility toggle that does not restrict reads is worse
    // than no toggle. Both are recorded in the plan's deferred table.

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
    let delegate = AccountDelegate()
    
    return RouterView { router in
        builder.accountView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func accountView(router: AnyRouter, delegate: AccountDelegate) -> some View {
        AccountView(
            presenter: AccountPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showAccountView(delegate: AccountDelegate) {
        router.showScreen(.push) { router in
            builder.accountView(router: router, delegate: delegate)
        }
    }
    
}
