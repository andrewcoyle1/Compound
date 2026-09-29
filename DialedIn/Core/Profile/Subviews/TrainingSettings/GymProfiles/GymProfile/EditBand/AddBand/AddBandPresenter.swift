import SwiftUI

@Observable
@MainActor
class AddBandPresenter {
    
    private let interactor: AddBandInteractor
    private let router: AddBandRouter
    
    var band: Binding<Bands>
    
    var bandAvailable: BandsAvailable
    let unit: ExerciseWeightUnit
    static let defaultColours: [Color] = [
        .primary,
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple
    ]
    
    var colours: [Color] {
        Self.defaultColours
    }
    
    private(set) var selectedColour: Color?
    var selectedColourHex: String? {
        selectedColour?.asHex()
    }
    
    init(interactor: AddBandInteractor, router: AddBandRouter, delegate: AddBandDelegate) {
        self.interactor = interactor
        self.router = router
        self.band = delegate.band
        self.selectedColour = Self.defaultColours.first ?? .accentColor

        self.bandAvailable = BandsAvailable(
            id: UUID().uuidString,
            name: "",
            bandColour: Self.defaultColours.first?.asHex() ?? Color.accentColor.asHex(),
            availableResistance: 0,
            unit: delegate.unit,
            isActive: true
        )
        self.unit = delegate.unit
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onColourPressed(colour: Color) {
        selectedColour = colour
        bandAvailable.bandColour = selectedColourHex ?? Color.accentColor.asHex()
    }
    
    func onDismissPressed() {
        router.dismissScreen()
    }
    
    func onSavePressed() {
        guard band.wrappedValue.range.contains(where: {
            $0.availableResistance == bandAvailable.availableResistance && $0.unit == bandAvailable.unit
        }) == false else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "This weight is already added."))
            return 
        }
        guard bandAvailable.name.isEmpty == false else {
            router.showSimpleAlert(title: String(localized: "Unable to add"), subtitle: String(localized: "Please enter a name for this weight."))
            return
        }
        self.band.wrappedValue.range.append(self.bandAvailable)
        router.dismissScreen()
    }
}

extension AddBandPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "AddBandView_Appear"
            case .onDisappear: return "AddBandView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
