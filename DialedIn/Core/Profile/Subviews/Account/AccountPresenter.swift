import SwiftUI
import PhotosUI

@Observable
@MainActor
class AccountPresenter {
    
    private let interactor: AccountInteractor
    private let router: AccountRouter

    private(set) var isSaving: Bool = false

    var firstName: String = ""
    var lastName: String = ""
    var dateOfBirth: Date = Date()
    var selectedGender: Gender?

    /// Edited in place in the Profile section, alongside date of birth and gender, and saved by the
    /// same `saveProfile()`. These had "Edit" buttons wired to empty functions and no editor
    /// anywhere else in the app outside onboarding.
    var heightText: String = ""
    var selectedCardioFitnessLevel: CardioFitnessLevel?
    var selectedExerciseFrequency: ExerciseFrequency?

    /// Centimetres, as `UserModel` stores height. Nil for an empty or unparseable field, which
    /// leaves the stored value alone rather than clearing it.
    var heightCentimeters: Double? {
        let trimmed = heightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
    var selectedPhotoItem: PhotosPickerItem?
    var selectedImageData: Data?
    var isImagePickerPresented: Bool = false

    var currentUser: UserModel? {
        interactor.currentUser
    }

    /// Written the moment it flips, not on Save: it is a switch, and a switch that waits for a
    /// button reads as broken.
    var isPrivate: Bool {
        get { currentUser?.isPrivate ?? false }
        set { onPrivacyChanged(isPrivate: newValue) }
    }

    private func onPrivacyChanged(isPrivate: Bool) {
        interactor.trackEvent(eventName: "AccountView_Privacy_Toggle", parameters: ["is_private": isPrivate], type: .analytic)
        Task {
            do {
                try await interactor.updatePrivacy(isPrivate: isPrivate)
            } catch {
                router.showAlert(error: error)
            }
        }
    }

    var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(interactor: AccountInteractor, router: AccountRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: AccountDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: AccountDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func presentImagePicker() {
        isImagePickerPresented = true
    }

    func trackPhotoSelected() {
        interactor.trackEvent(eventName: "profile_photo_selected", parameters: [:], type: .analytic)
    }

    func trackPhotoLoadFailed(error: Error) {
        interactor.trackEvent(eventName: "profile_photo_load_failed", parameters: ["error": String(describing: error)], type: .analytic)
    }

    func prefillFromCurrentUser() {
        guard let user = currentUser else { return }
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        if let dob = user.submittedDateOfBirth {
            dateOfBirth = dob
        }
        selectedGender = user.submittedGender
        if let height = user.submittedHeightCentimeters {
            heightText = height.formatted(.number.precision(.fractionLength(0...1)))
        }
        selectedCardioFitnessLevel = user.submittedCardioFitnessLevel
        selectedExerciseFrequency = user.submittedExerciseFrequency
    }

    func saveProfile() async {
        guard canSave else { return }
        // A new photo is an upload, which needs the server; the rest of the profile does not.
        if selectedImageData != nil {
            guard interactor.ensureOnline(or: router) else { return }
        }
        isSaving = true

        do {

            let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

            var data: [String: any DMCodableSendable] = [
                UserModel.CodingKeys.submittedFirstName.rawValue: trimmedFirst,
                UserModel.CodingKeys.submittedLastName.rawValue: trimmedLast,
                UserModel.CodingKeys.submittedDateOfBirth.rawValue: dateOfBirth
            ]
            // Was writing into `submittedFirstName`, so saving a profile with a gender set
            // overwrote the first name with "male" or "female".
            if let gender = selectedGender {
                data[UserModel.CodingKeys.submittedGender.rawValue] = gender.rawValue
            }
            if let heightCentimeters {
                data[UserModel.CodingKeys.submittedHeightCentimeters.rawValue] = heightCentimeters
            }
            if let cardioFitnessLevel = selectedCardioFitnessLevel {
                data[UserModel.CodingKeys.submittedCardioFitnessLevel.rawValue] = cardioFitnessLevel.rawValue
            }
            if let exerciseFrequency = selectedExerciseFrequency {
                data[UserModel.CodingKeys.submittedExerciseFrequency.rawValue] = exerciseFrequency.rawValue
            }
            #if canImport(UIKit)
            if let uiImage = selectedImageData.flatMap({ UIImage(data: $0) }) {
                try await interactor.updateProfileImageUrl(image: uiImage)
            }
            try await updateUser(data: data)
            #elseif canImport(AppKit)
            if let nsImage = selectedImageData.flatMap({ NSImage(data: $0) }) {
                try await interactor.updateProfileImageUrl(image: nsImage)
            }
            try await updateUser(data: data)
            #endif

            interactor.trackEvent(eventName: "profile_edit_save_success", parameters: [:], type: .analytic)
            router.dismissScreen()
        } catch {
            interactor.trackEvent(eventName: "profile_edit_save_failed", parameters: ["error": String(describing: error)], type: .analytic)
            router.showSimpleAlert(
                title: String(localized: "Unable to save"),
                subtitle: "Please check your internet connection and try again."
            )
        }
        isSaving = false
    }
    
    /// Offline, Firestore queues the update and the user listener shows it at once, but awaiting it
    /// waits for the server, so Save would spin until the signal came back. The queued write is
    /// left to finish on its own and the screen closes as it would online.
    private func updateUser(data: [String: any DMCodableSendable]) async throws {
        guard interactor.isOffline else {
            return try await interactor.updateUser(data: data)
        }
        Task { [interactor] in try? await interactor.updateUser(data: data) }
    }

    /// Name, height, cardio fitness and lifting experience are all edited in place in the Profile
    /// section now, so the six `onEdit…Pressed` functions that used to live here — every one of them
    /// empty, behind a live "Edit" button — are gone with the buttons.
    ///
    /// Email and password are not editable at all, and no longer pretend to be: sign-in is Apple,
    /// Google or anonymous (`SignInOption` has no email case), so the address belongs to the identity
    /// provider and there is no password in the first place.

    /// An anonymous account has no credential behind it, so signing out of one destroys everything
    /// logged against it with no way back in. Those users are offered the upgrade instead.
    var isAnonymousUser: Bool {
        interactor.auth?.isAnonymous == true
    }

    /// An anonymous account's only route to keeping its data.
    ///
    /// Routes to the existing `AuthView` rather than reimplementing sign-in: `FirebaseAuthService`
    /// already links an Apple or Google credential to the signed-in anonymous user, and
    /// `CoreInteractor.logIn` already handles the migration and cleanup around it, so the upgrade
    /// keeps the account rather than replacing it.
    func onUsernamePressed() {
        interactor.trackEvent(eventName: "AccountView_Username_Press", parameters: [:], type: .analytic)
        router.showEditUsernameView()
    }

    func onSaveAccountPressed() {
        interactor.trackEvent(event: Event.saveAccountPressed)
        router.showAuthView()
    }

    func onSignOutPressed() {
        interactor.trackEvent(event: Event.signOutStart)

        Task {
            do {
                try await interactor.signOut()
                interactor.trackEvent(event: Event.signOutSuccess)
                dismissEnvironment()
                try await Task.sleep(for: .seconds(1))
                router.switchToOnboardingModule()
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.signOutFail(error: error))
            }
        }
    }

    private func dismissEnvironment() {
        router.dismissEnvironment()
    }

    func onDeleteAccountPressed() {
        interactor.trackEvent(event: Event.deleteAccountStart)

        router.showAlert(
            title: String(localized: "Delete Account?"),
            subtitle: String(localized: "This action is permanent and cannot be undone. Your data will be deleted from our server forever."),
            buttons: {
                AnyView(
                    Button("Delete", role: .destructive, action: {
                        self.onDeleteAccountConfirmed()
                    })
                )
            }
        )
    }

    /// Only ever called from the Delete button inside the confirmation above. Not private so that
    /// the half of account deletion that runs after the user says yes can be tested: the alert
    /// itself goes out through a `GlobalRouter` extension, which dispatches statically and so
    /// cannot be intercepted.
    func onDeleteAccountConfirmed() {
        interactor.trackEvent(event: Event.deleteAccountStartConfirm)

        Task {
            do {
                try await interactor.deleteAccount()
                interactor.trackEvent(event: Event.deleteAccountSuccess)
                dismissEnvironment()
                try await Task.sleep(for: .seconds(1))
                router.switchToOnboardingModule()

            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.deleteAccountFail(error: error))
            }
        }
    }

}

extension AccountPresenter {
    
    enum Event: LoggableEvent {
        case signOutStart
        case signOutSuccess
        case signOutFail(error: Error)
        case deleteAccountStart
        case deleteAccountStartConfirm
        case deleteAccountSuccess
        case deleteAccountFail(error: Error)
        case saveAccountPressed
        case onAppear(delegate: AccountDelegate)
        case onDisappear(delegate: AccountDelegate)

        var eventName: String {
            switch self {
            case .signOutStart:                 return "Settings_SignOut_Start"
            case .signOutSuccess:               return "Settings_SignOut_Success"
            case .signOutFail:                  return "Settings_SignOut_Fail"
            case .deleteAccountStart:           return "Settings_DeleteAccount_Start"
            case .deleteAccountStartConfirm:    return "Settings_DeleteAccount_StartConfirm"
            case .deleteAccountSuccess:         return "Settings_DeleteAccount_Success"
            case .deleteAccountFail:            return "Settings_DeleteAccount_Fail"
            case .saveAccountPressed:           return "Settings_SaveAccount_Press"
            case .onAppear:                 return "AccountView_Appear"
            case .onDisappear:              return "AccountView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .signOutFail(error: let error), .deleteAccountFail(error: let error):
                return error.eventParameters
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .signOutFail, .deleteAccountFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
