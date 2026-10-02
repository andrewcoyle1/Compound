//
//  CompleteAccountSetupRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CompleteAccountSetupRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showNamePhotoView()
}

extension CoreRouter: CompleteAccountSetupRouter { }
