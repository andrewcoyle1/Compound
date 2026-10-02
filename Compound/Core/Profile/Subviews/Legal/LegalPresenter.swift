import SwiftUI

@Observable
@MainActor
class LegalPresenter {
    
    private let interactor: LegalInteractor
    private let router: LegalRouter
    
    init(interactor: LegalInteractor, router: LegalRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onDocumentPressed(_ document: LegalDocument) {
        interactor.trackEvent(event: Event.onDocumentPressed(document))
    }

}

extension LegalPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case onDocumentPressed(LegalDocument)

        var eventName: String {
            switch self {
            case .onAppear:          return "LegalView_Appear"
            case .onDisappear:       return "LegalView_Disappear"
            case .onDocumentPressed: return "LegalView_Document_Press"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onDocumentPressed(let document):
                return ["document": document.rawValue]
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
