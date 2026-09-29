//
//  DeleteAccountRouter.swift
//  DialedIn
//

@MainActor
protocol DeleteAccountRouter: GlobalRouter {
    func switchToOnboardingModule()
}

extension CoreRouter: DeleteAccountRouter { }
