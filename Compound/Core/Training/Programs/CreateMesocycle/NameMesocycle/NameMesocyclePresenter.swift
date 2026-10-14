import SwiftUI

@Observable
@MainActor
class NameMesocyclePresenter {
    
    private let interactor: NameMesocycleInteractor
    private let router: NameMesocycleRouter
    
    var mesocycleName: String
    
    private var trimmedName: String { mesocycleName.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSave: Bool { !trimmedName.isEmpty }
    
    init(interactor: NameMesocycleInteractor, router: NameMesocycleRouter) {
        self.interactor = interactor
        self.router = router
        
        self.mesocycleName = Date.now.formattedDate
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onDismissPressed() {
        router.dismissEnvironment()
    }

    func onNextPressed(delegate: NameMesocycleDelegate) {
        guard canSave else { return }
        router.showMesocycleIconView(delegate: MesocycleIconDelegate(onComplete: delegate.onComplete, name: trimmedName))
    }
    
}

extension NameMesocyclePresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        
        var eventName: String {
            switch self {
            case .onAppear: return "NameProgramView_Appear"
            case .onDisappear: return "NameProgramView_Disappear"
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
