//
//  DeleteAccountRouter.swift
//  Compound
//

@MainActor
protocol DeleteAccountRouter: GlobalRouter {
    func switchToOnboardingModule()
}

extension CoreRouter: DeleteAccountRouter { }
