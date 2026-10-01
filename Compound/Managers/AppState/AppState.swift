//
//  AppState.swift
//  Compound
//
//  Created by Andrew Coyle on 13/08/2025.
//

import Foundation

@Observable
@MainActor
class AppState {
    let startingModuleId: String
    
    init(startingModuleId: String = UserDefaults.lastModuleId) {
        self.startingModuleId = startingModuleId
    }
}

extension CoreInteractor {
    var startingModuleId: String {
        appState.startingModuleId
    }
}
