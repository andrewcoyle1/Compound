//
//  GenderPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class GenderPresenter {
    private let interactor: GenderInteractor
    private let router: GenderRouter

    var selectedGender: Gender?
    var healthFill: AppleHealthFillState = .idle

    /// Male, Female, then "Prefer not to say" (decision 8a).
    let options: [Gender] = Gender.allCases

    var canSubmit: Bool {
        selectedGender != nil
    }

    /// Only "Prefer not to say" carries a note: it uses the midpoint coefficient.
    func detail(for gender: Gender) -> String? {
        gender == .preferNotToSay ? String(localized: "Your calorie estimate will be less accurate.") : nil
    }

    func onFillFromAppleHealthPressed() {
        healthFill = .loading
        Task {
            let sex = await interactor.readSexFromAppleHealth()
            if let sex {
                selectedGender = sex
            }
            healthFill = sex == nil ? .notFound : .filled
            interactor.trackEvent(event: Event.fillFromHealth(found: sex != nil))
        }
    }

    /// Picking an option row: record it and give the selection tick.
    func onGenderSelected(_ value: Gender) {
        selectedGender = value
        interactor.playHaptic(option: .selection)
    }

    init(
        interactor: GenderInteractor,
        router: GenderRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onContinuePressed() {
        if let gender = selectedGender {
            let delegate = DateOfBirthDelegate(gender: gender)
            interactor.trackEvent(event: Event.navigate)
            router.showDateOfBirthView(delegate: delegate)
        }
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case navigate
        case fillFromHealth(found: Bool)

        var eventName: String {
            switch self {
            case .onAppear:             return "GenderView_Appear"
            case .onDisappear:          return "GenderView_Disappear"
            case .navigate: return "GenderView_Navigate"
            case .fillFromHealth: return "GenderView_FillFromHealth"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .fillFromHealth(let found):
                return ["found": found]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .navigate:
                return .info
            default:
                return .analytic
            }
        }
    }
}
