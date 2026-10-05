import SwiftUI
import PhotosUI

@Observable
@MainActor
class EditProfilePresenter {
    
    private let interactor: EditProfileInteractor
    private let router: EditProfileRouter

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
    /// Onboarding's "How Active Are You?" answer, so it can be changed afterwards.
    var selectedActivityLevel: ActivityLevel?

    /// The height field is typed in the unit chosen on the Units screen; `UserModel` stores cm.
    var heightUnit: LengthUnitPreference {
        currentUser?.submittedLengthUnitPreference ?? .centimeters
    }

    /// What the height field held when it was filled from the profile. Converting to inches and
    /// back rounds, so an untouched field is not written back.
    private var prefilledHeightText: String = ""

    /// Centimetres, as `UserModel` stores height. Nil for an empty or unparseable field, which
    /// leaves the stored value alone rather than clearing it.
    var heightCentimeters: Double? {
        guard let value = Double.typed(heightText), value > 0 else { return nil }
        return UnitConversion.convertLengthToCm(value, from: heightUnit)
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
        interactor.trackEvent(event: Event.updatePrivacyStart(isPrivate: isPrivate))
        Task {
            do {
                try await interactor.updatePrivacy(isPrivate: isPrivate)
                interactor.trackEvent(event: Event.updatePrivacySuccess(isPrivate: isPrivate))
            } catch {
                interactor.trackEvent(event: Event.updatePrivacyFail(error: error))
                router.showAlert(title: String(localized: "Unable to Change Privacy"), error: error)
            }
        }
    }

    var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(interactor: EditProfileInteractor, router: EditProfileRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: EditProfileDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: EditProfileDelegate) {
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
            heightText = UnitConversion.convertLength(height, to: heightUnit)
                .formatted(.number.precision(.fractionLength(0...1)))
            prefilledHeightText = heightText
        }
        selectedCardioFitnessLevel = user.submittedCardioFitnessLevel
        selectedExerciseFrequency = user.submittedExerciseFrequency
        selectedActivityLevel = user.submittedDailyActivityLevel
    }

    func saveProfile() async {
        guard canSave else { return }
        // A new photo is an upload, which needs the server; the rest of the profile does not.
        if selectedImageData != nil {
            guard interactor.ensureOnline(or: router) else { return }
        }
        isSaving = true
        interactor.trackEvent(event: Event.saveProfileStart)

        do {

            let data = profileData()
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
            interactor.trackEvent(event: Event.saveProfileSuccess)
            interactor.playHaptic(option: .success)
            router.dismissScreen()
        } catch {
            interactor.trackEvent(eventName: "profile_edit_save_failed", parameters: ["error": String(describing: error)], type: .analytic)
            interactor.trackEvent(event: Event.saveProfileFail(error: error))
            interactor.playHaptic(option: .error)
            router.showSimpleAlert(
                title: String(localized: "Unable to Save Profile"),
                subtitle: String(localized: "Please check your internet connection and try again.")
            )
        }
        isSaving = false
    }
    
    /// Every edited field under its own key. Unset pickers and an untouched height are left out, so
    /// they do not write over what is stored.
    private func profileData() -> [String: any DMCodableSendable] {
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
        if let heightCentimeters, heightText != prefilledHeightText {
            data[UserModel.CodingKeys.submittedHeightCentimeters.rawValue] = heightCentimeters
        }
        if let cardioFitnessLevel = selectedCardioFitnessLevel {
            data[UserModel.CodingKeys.submittedCardioFitnessLevel.rawValue] = cardioFitnessLevel.rawValue
        }
        if let exerciseFrequency = selectedExerciseFrequency {
            data[UserModel.CodingKeys.submittedExerciseFrequency.rawValue] = exerciseFrequency.rawValue
        }
        if let activityLevel = selectedActivityLevel {
            data[UserModel.CodingKeys.submittedDailyActivityLevel.rawValue] = activityLevel.rawValue
        }
        return data
    }

    /// Offline, Firestore queues the update and the user listener shows it at once, but awaiting it
    /// waits for the server, so Save would spin until the signal came back. The queued write is
    /// left to finish on its own and the screen closes as it would online.
    private func updateUser(data: [String: any DMCodableSendable]) async throws {
        guard interactor.isOffline else {
            return try await interactor.updateUser(data: data)
        }
        Task { [interactor] in
            do {
                try await interactor.updateUser(data: data)
            } catch {
                interactor.trackEvent(event: Event.queuedUpdateUserFail(error: error))
            }
        }
    }

    /// Name, height, cardio fitness and lifting experience are all edited in place in the Profile
    /// section now, so the six `onEdit…Pressed` functions that used to live here — every one of them
    /// empty, behind a live "Edit" button — are gone with the buttons.
    ///
    /// Email and password are not editable at all, and no longer pretend to be: sign-in is Apple,
    /// Google or anonymous (`SignInOption` has no email case), so the address belongs to the identity
    /// provider and there is no password in the first place.

    func onUsernamePressed() {
        interactor.trackEvent(eventName: "AccountView_Username_Press", parameters: [:], type: .analytic)
        router.showEditUsernameView()
    }

}

extension EditProfilePresenter {

    func onCancelPressed() {
        interactor.trackEvent(event: Event.cancelPressed)
        router.dismissScreen()
    }
}

extension EditProfilePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: EditProfileDelegate)
        case onDisappear(delegate: EditProfileDelegate)
        case updatePrivacyStart(isPrivate: Bool)
        case updatePrivacySuccess(isPrivate: Bool)
        case updatePrivacyFail(error: Error)
        case saveProfileStart
        case saveProfileSuccess
        case saveProfileFail(error: Error)
        case queuedUpdateUserFail(error: Error)
        case cancelPressed

        var eventName: String {
            switch self {
            case .onAppear:                 return "AccountView_Appear"
            case .onDisappear:              return "AccountView_Disappear"
            case .updatePrivacyStart:       return "AccountView_UpdatePrivacy_Start"
            case .updatePrivacySuccess:     return "AccountView_UpdatePrivacy_Success"
            case .updatePrivacyFail:        return "AccountView_UpdatePrivacy_Fail"
            case .saveProfileStart:         return "AccountView_SaveProfile_Start"
            case .saveProfileSuccess:       return "AccountView_SaveProfile_Success"
            case .saveProfileFail:          return "AccountView_SaveProfile_Fail"
            case .queuedUpdateUserFail:     return "AccountView_QueuedUpdateUser_Fail"
            case .cancelPressed:            return "AccountView_Cancel_Pressed"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .updatePrivacyFail(error: let error),
                 .saveProfileFail(error: let error), .queuedUpdateUserFail(error: let error):
                return error.eventParameters
            case .updatePrivacyStart(isPrivate: let isPrivate), .updatePrivacySuccess(isPrivate: let isPrivate):
                return ["is_private": isPrivate]
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .updatePrivacyFail, .saveProfileFail:
                return .severe
            case .queuedUpdateUserFail:
                return .warning
            default:
                return .analytic
            }
        }
    }

}
