//
//  HeightPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 28/10/2025.
//

import SwiftUI

@Observable
@MainActor
class HeightPresenter {
    private let interactor: HeightInteractor
    private let router: HeightRouter

    var unit: UnitOfLength = Locale.current.measurementSystem == .metric ? .centimeters : .inches
    var selectedCentimeters: Int = 175
    var selectedFeet: Int = 5
    var selectedInches: Int = 9
    var healthFill: AppleHealthFillState = .idle

    /// The metric wheel's range; a stored height outside it counts as nothing found.
    static let centimetersRange = 100...250

    func onFillFromAppleHealthPressed() {
        healthFill = .loading
        Task {
            let centimeters = await interactor.readHeightCentimetersFromAppleHealth()
                .map { Int($0.rounded()) }
                .flatMap { Self.centimetersRange.contains($0) ? $0 : nil }
            if let centimeters {
                selectedCentimeters = centimeters
                updateImperialFromCentimeters()
            }
            healthFill = centimeters == nil ? .notFound : .filled
            interactor.trackEvent(event: Event.fillFromHealth(found: centimeters != nil))
        }
    }

    // Computed properties to keep measurements synchronized
    private var heightInCentimeters: Double {
        Double(selectedCentimeters)
    }
    
    /// Feet and inches are derived from one rounded total so they cannot disagree with each other.
    /// Rounding the total and then splitting it also keeps `height` consistent with what
    /// `updateImperialFromCentimeters` puts in the pickers.
    private var totalHeightInches: Int {
        Int((Double(heightInCentimeters) / 2.54).rounded())
    }

    private var heightInFeet: Int {
        totalHeightInches / 12
    }
    
    private var heightInInches: Int {
        totalHeightInches % 12 // Remaining inches after feet
    }
    
    var height: Double {
        switch unit {
        case .centimeters:
            return Double(heightInCentimeters)
        case .inches:
            return Double(heightInFeet) + Double(heightInInches) / 12.0
        }
    }
    
    var preference: LengthUnitPreference {
        switch unit {
        case .centimeters:
            return .centimeters
        case .inches:
            return .inches
        }
    }
    
    init(
        interactor: HeightInteractor,
        router: HeightRouter
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
    
    func onContinuePressed(delegate: HeightDelegate) {
        let delegate = WeightDelegate(delegate: delegate, heightInCentimeters: heightInCentimeters, lengthUnitPreference: preference)
        interactor.trackEvent(event: Event.navigate)
        router.showWeightView(delegate: delegate)
    }
    
    // Both conversions round rather than truncate. Truncating dropped up to a whole inch on the
    // way back to imperial — 175 cm is 5 ft 8.9 in and was shown as 5 ft 8 in — and a whole
    // centimetre on the way out, so 6 ft was stored as 182 cm instead of 183.
    func updateImperialFromCentimeters() {
        let totalInches = Int((Double(selectedCentimeters) / 2.54).rounded())
        selectedFeet = totalInches / 12
        selectedInches = totalInches % 12
    }
    
    func updateCentimetersFromImperial() {
        let totalInches = (selectedFeet * 12) + selectedInches
        selectedCentimeters = Int((Double(totalInches) * 2.54).rounded())
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case navigate
        case fillFromHealth(found: Bool)

        var eventName: String {
            switch self {
            case .onAppear: return "HeightView_Appear"
            case .onDisappear: return "HeightView_Disappear"
            case .navigate: return "HeightView_Navigate"
            case .fillFromHealth: return "HeightView_FillFromHealth"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear, .onDisappear:
                return nil
            case .navigate:
                return nil
            case .fillFromHealth(let found):
                return ["found": found]
            }
        }

        var type: LogType {
            switch self {
            case .onAppear, .onDisappear:
                return .analytic
            case .navigate:
                return .info
            case .fillFromHealth:
                return .analytic
            }
        }
    }
}

enum UnitOfLength {
    case centimeters
    case inches
}
