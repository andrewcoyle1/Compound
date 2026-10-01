//
//  CoreBuilder.swift
//  Compound
//
//  Created by Andrew Coyle on 10/11/2025.
//

import SwiftUI

@MainActor
struct CoreBuilder: Builder {
    
    let interactor: CoreInteractor
    
    func build() -> AnyView {
        appView().any()
    }
}
