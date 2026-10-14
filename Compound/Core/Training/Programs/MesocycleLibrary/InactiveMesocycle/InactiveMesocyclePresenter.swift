import SwiftUI

@Observable
@MainActor
class InactiveMesocyclePresenter {
    
    private let interactor: InactiveMesocycleInteractor
    private let router: InactiveMesocycleRouter
    
    init(interactor: InactiveMesocycleInteractor, router: InactiveMesocycleRouter) {
        self.interactor = interactor
        self.router = router
    }
    
}
