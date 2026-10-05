import SwiftUI

@Observable
@MainActor
class MesocycleDisclosureGroupPresenter {
    
    private let interactor: MesocycleDisclosureGroupInteractor
    private let router: MesocycleDisclosureGroupRouter
    
    init(interactor: MesocycleDisclosureGroupInteractor, router: MesocycleDisclosureGroupRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onSavedMesocyclePressed(_ mesocycle: Mesocycle) {
        router.showEditMesocycleView(delegate: EditMesocycleDelegate(mesocycle: mesocycle))
    }

    func onSharePressed(_ mesocycle: Mesocycle) {
        router.showShareToFollowerView(delegate: ShareToFollowerDelegate(payload: .mesocycle(mesocycle)))
    }

}
