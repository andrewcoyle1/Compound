import SwiftUI

@Observable
@MainActor
class ProgramIconPresenter {
    
    private let interactor: ProgramIconInteractor
    private let router: ProgramIconRouter
    
    static let defaultColours: [Color] = [
        .primary,
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple
    ]
    
    static let defaultIcons: [String] = [
        "flag.pattern.checkered",
        "arcade.stick",
        "gamecontroller",
        "figure.walk",
        "airplane.up.right",
        "sailboat.fill",
        "gauge.with.dots.needle.bottom.100percent"
    ]
    
    var colours: [Color] {
        Self.defaultColours
    }
    
    var icons: [String] {
        Self.defaultIcons
    }
    
    private(set) var selectedColour: Color
    private(set) var selectedIcon: String

    init(interactor: ProgramIconInteractor, router: ProgramIconRouter) {
        self.interactor = interactor
        self.router = router
        self.selectedColour = Self.defaultColours.first ?? .accentColor
        self.selectedIcon = Self.defaultIcons.first ?? "flag.pattern.checkered"
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onColourPressed(colour: Color) {
        selectedColour = colour
    }
    
    func onIconPressed(icon: String) {
        selectedIcon = icon
    }
    
    func onNextPressed(delegate: ProgramIconDelegate) {
        // Reachable: the user document arrives on the sync engine's own task. Silently doing
        // nothing left the button looking broken.
        guard let userId = interactor.userId else {
            router.showSimpleAlert(title: String(localized: "Unable to Create Program"), subtitle: String(localized: "Please try again."))
            return
        }
        router.showProgramDesignView(
            delegate: ProgramDesignDelegate(
                onComplete: delegate.onComplete,
                id: UUID().uuidString,
                authorId: userId,
                name: delegate.name,
                colour: selectedColour,
                icon: selectedIcon
            )
        )
    }
    
}

extension ProgramIconPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "ProgramIconView_Appear"
            case .onDisappear: return "ProgramIconView_Disappear"
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
