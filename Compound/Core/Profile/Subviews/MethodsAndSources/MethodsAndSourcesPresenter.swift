import SwiftUI

@Observable
@MainActor
class MethodsAndSourcesPresenter {

    private let interactor: MethodsAndSourcesInteractor
    private let router: MethodsAndSourcesRouter

    /// Every calculation the app explains with an ⓘ, in the order the areas are listed in
    /// `MethodInfo.all`.
    let methods: [MethodInfo] = MethodInfo.all

    init(interactor: MethodsAndSourcesInteractor, router: MethodsAndSourcesRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onMethodPressed(_ method: MethodInfo) {
        interactor.trackEvent(event: Event.onMethodPressed(method))
    }
}

extension MethodsAndSourcesPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onMethodPressed(MethodInfo)

        var eventName: String {
            switch self {
            case .onAppear:        return "MethodsAndSourcesView_Appear"
            case .onMethodPressed: return "MethodsAndSourcesView_Method_Press"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onMethodPressed(let method):
                return ["method": method.id]
            default:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
